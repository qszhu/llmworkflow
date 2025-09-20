import std/[
  asyncdispatch,
  asynchttpserver,
  json,
  times,
]

import ws



proc getTimeNow(): string =
  result = $(now())
  echo "getTimeNow(): ", result

proc processToolCall(jso: JsonNode): Future[string] {.async.} =
  echo jso
  let funcName = jso["name"].getStr
  case funcName
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
        "name": "get_time_now",
        "description": "get the current time in ISO format",
        "params": @[],
        "returns": %*{
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
  waitFor server.serve(Port(2234), cb)
