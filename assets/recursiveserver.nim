import std/[
  asyncdispatch,
  asynchttpserver,
  json,
  logging,
  strformat,
  times,
]

import ws

import utils



tools:
  proc myfunc(n: int): string =
    if n < 2: result = "1"
    else: result = &"myfunc({n}) = myfunc({n - 2}) + myfunc({n - 1}) + 1"
    echo &"myfunc({n}): {result}"

  proc getTimeNow(): string =
    result = $(now())
    echo "getTimeNow(): ", result

proc processToolCall(jso: JsonNode): Future[string] {.async.} =
  logging.debug jso
  let funcName = jso["name"].getStr
  let args = jso["args"]
  case funcName
  of "myfunc":
    let n = args["n"].getInt
    return myfunc(n)
  of "getTimeNow":
    return getTimeNow()
  else:
    return "unknown function: " & funcName

var toolDefs {.threadvar.}: JsonNode

proc cb(req: Request) {.async, gcsafe.} =
  if req.url.path == "/ws":
    try:
      var ws = await newWebSocket(req)
      while ws.readyState == Open:
        let jso = (await ws.receiveStrPacket()).parseJson
        let res = await processToolCall(jso)
        await ws.send($res)
    except:
      echo getCurrentExceptionMsg()
  elif req.url.path == "/":
    let headers = {
      "Content-type": "application/json; charset=utf-8"
    }.newHttpHeaders()
    await req.respond(Http200, $toolDefs, headers)
  else:
    await req.respond(Http404, "Not found")

when isMainModule:
  when not defined(release):
    addHandler(newConsoleLogger(levelThreshold = lvlDebug))

  toolDefs = toolFuncs
  var server = newAsyncHttpServer()
  const port = 6234
  logging.debug "Listening on port: ", port
  waitFor server.serve(Port(port), cb)
