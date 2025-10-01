import std/[
  asyncdispatch,
  asynchttpserver,
  json,
  logging,
  parseopt,
  strtabs,
  strutils,
  xmlparser,
]

import ws

import xmltypes

var exportFuncName {.threadvar.}: string
var xml {.threadvar.}: XmlNode

proc chat(query: string): Future[string] {.async.} =
  let blk = newLlmBlock(xml)
  {.cast(gcsafe).}:
    await blk.run(query)
  result = $(blk.outputs[^1])

proc processToolCall(jso: JsonNode): Future[string] {.async.} =
  logging.debug jso
  let funcName = jso["name"].getStr
  let args = jso["args"]
  if funcName == exportFuncName:
    let query = args["query"].getStr
    return await chat(query)
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
        "name": exportFuncName,
        "params": @[%*{
          "name": "query",
          "type": "string",
        }],
        "returns": %*{
          "type": "string",
        }
      }]
    }
    await req.respond(Http200, $resp, headers)
  else:
    await req.respond(Http404, "Not found")

when isMainModule:
  when not defined(release):
    addHandler(newConsoleLogger(levelThreshold = lvlWarn))

  var xmlFn: string
  var opts = newStringTable()
  var p = initOptParser()
  for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
      xmlFn = key
    of cmdLongOption, cmdShortOption:
      opts[key] = val
    of cmdEnd: doAssert false
  if xmlFn.len == 0 or "name" notin opts or "port" notin opts:
    echo "Usage: serve <xml> --name=<name> --port=<port>"
    quit(-1)

  xml = loadXml(xmlFn)
  exportFuncName = opts["name"]
  let port = opts["port"].parseInt

  var server = newAsyncHttpServer()
  logging.debug "Listening on port: ", port
  waitFor server.serve(Port(port), cb)
