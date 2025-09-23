import std/[
  asyncdispatch,
  asynchttpserver,
  json,
  strformat,
  times,
]

import ws



proc myfunc(n: int): string =
  if n < 2: result = "1"
  else: result = &"myfunc({n}) = myfunc({n - 2}) + myfunc({n - 1}) + 1"
  echo &"myfunc({n}): {result}"

proc getTimeNow(): string =
  result = $(now())
  echo "getTimeNow(): ", result

proc processToolCall(jso: JsonNode): Future[string] {.async.} =
  echo jso
  let funcName = jso["name"].getStr
  let args = jso["args"]
  case funcName
  of "myfunc":
    let n = args["n"].getInt
    return myfunc(n)
  of "get_time_now":
    return getTimeNow()
  else:
    return "unknown function: " & funcName

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
    let resp = %*{
      "functions": @[%*{
        "name": "myfunc",
        "description": "get the result or calculation process of my function regarding argument n",
        "params": @[%*{
          "name": "n",
          "type": "integer",
          "description": "the number to call my function with"
        }],
        "returns": %*{
          "type": "string",
          "description": "the result of my function at n",
        },
      }, %*{
        "name": "get_time_now",
        "description": "get the current time in ISO format",
        "params": [],
        "returns": {
          "type": "string",
          "description": "current time in ISO format",
        }
      }]
    }
    await req.respond(Http200, $resp, headers)
  else:
    await req.respond(Http404, "Not found")

when isMainModule:
  var server = newAsyncHttpServer()
  waitFor server.serve(Port(6234), cb)
