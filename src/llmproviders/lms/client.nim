import std/[
  strutils,
]

import ../../lib/requests
import types

export asyncdispatch, json, types



type
  LmsClient* = ref object
    host: Uri

proc newLmsClient*(host: string): LmsClient =
  result.new
  result.host = host.parseUri

proc listModels*(self: LmsClient): Future[LmList[LmModel]] {.async.} =
  let url = self.host / "models"
  let res = await request(url, httpMethod = HttpGet)
  res.newLmList(newLmModel)

proc getHost(self: LmsClient, host = ""): Uri =
  if host.len > 0: host.parseUri else: self.host

proc chat*(self: LmsClient,
  model: string,
  messages: seq[JsonNode],
  responseFormat: JsonNode = nil,
  tools: seq[JsonNode] = @[],
  host = "",
): Future[LmChatCompletion] {.async.} =
  let url = self.getHost(host) / "chat" / "completions"
  var data = %*{
    "model": model,
    "messages": messages,
  }
  if responseFormat != nil:
    data["response_format"] = responseFormat
  if tools.len > 0:
    data["tools"] = %*tools
  writeFile("req.json", $data)
  let res = await request(url, data = data, httpMethod = HttpPost)
  writeFile("resp.json", $res)
  res.newLmChatCompletion

type
  ChatStreamCb* = proc (chunk: LmChatCompletionChunk)

const DATA_EV = "data: "
const DATA_DONE = "[DONE]"

proc chatStream*(self: LmsClient,
  model: string,
  messages: seq[JsonNode],
  cb: ChatStreamCb,
  responseFormat: JsonNode = nil,
  tools: seq[JsonNode] = @[],
  host = "",
) {.async.} =
  let url = self.getHost(host) / "chat" / "completions"
  var data = %*{
    "model": model,
    "messages": messages,
    "stream": true,
  }
  if responseFormat != nil:
    data["response_format"] = responseFormat
  if tools.len > 0:
    data["tools"] = %*tools
  writeFile("req.json", $data)
  let body = $data
  let headers = newHttpHeaders({ "Content-Type": "application/json; charset=utf-8" })
  let client = newAsyncHttpClient()
  try:
    let res = await client.request(url, headers = headers, body = body, httpMethod = HttpPost)
    var (ok, buf) = await res.bodyStream.read
    while ok:
      if buf.startsWith(DATA_EV):
        let data = buf[DATA_EV.len .. ^1]
        if data.startsWith(DATA_DONE): break
        cb(newLmChatCompletionChunk(data.parseJson))
      else:
        raise newException(ValueError, "Unknown event: " & buf)
      (ok, buf) = await res.bodyStream.read
  finally:
    client.close
