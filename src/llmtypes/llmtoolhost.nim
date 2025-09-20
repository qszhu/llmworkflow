import std/[
  asyncdispatch,
  httpclient,
  logging,
  options,
  strformat,
  strutils,
  tables,
  uri,
]

import ws

import llmtool



proc getFuncsFromServer(server: string): Future[JsonNode] {.async.} =
  var client: AsyncHttpClient
  try:
    client = newAsyncHttpClient()
    let resp = await client.getContent(server)
    logging.debug resp
    return resp.parseJson
  finally:
    client.close

proc getWsHostFromServer(server: string): string =
  result = server
  let p = server.find("://")
  if p >= 0: result = server[p + 3 .. ^1]
  result = $((&"ws://{result}").parseUri / "ws")

type
  LlmToolHost* = ref object
    servers: seq[string]
    clients: Table[string, WebSocket]

proc newLlmToolHost*(): LlmToolHost =
  result.new

proc addServer*(self: LlmToolHost, server: string) =
  self.servers.add server

proc getServerByToolName(self: LlmToolHost, toolName: string): Future[Option[string]] {.async.} =
  result = none(string)
  for server in self.servers:
    let jso = await getFuncsFromServer(server)
    for f in jso["functions"]:
      if f["name"].getStr == toolName:
        return some(server)

proc getWs(self: LlmToolHost, toolName: string): Future[Option[WebSocket]] {.async.} =
  let serverOpt = await self.getServerByToolName(toolName)
  if serverOpt.isNone:
    return none(WebSocket)

  let host = getWsHostFromServer(serverOpt.get)
  if host notin self.clients or self.clients[host].readyState != Open:
    let ws = await newWebSocket(host)
    self.clients[host] = ws

  return some(self.clients[host])

proc callTool*(self: LlmToolHost, tc: LlmToolCall): Future[string] {.async.} =
  let wsOpt = await self.getWs(tc.name)
  if wsOpt.isNone:
    return "Tool not available"

  let ws = wsOpt.get
  await ws.send($(tc.toJson))
  return await ws.receiveStrPacket()

proc getTools*(self: LlmToolHost): Future[seq[LlmTool]] {.async.} =
  for server in self.servers:
    let jso = await getFuncsFromServer(server)
    for f in jso["functions"]:
      result.add f.llmFuncFromJson.LlmTool
