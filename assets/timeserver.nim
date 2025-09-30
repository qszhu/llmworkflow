import std/[
  asyncdispatch,
  asynchttpserver,
  json,
  logging,
  times,
]

import ws

import utils



tools:
  proc getTimeNow(): string =
    result = $(now())
    echo "getTimeNow(): ", result

proc processToolCall(jso: JsonNode): Future[string] {.async.} =
  logging.debug jso
  let funcName = jso["name"].getStr
  case funcName
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
  const port = 2234
  logging.debug "Listening on port: ", port
  waitFor server.serve(Port(port), cb)
