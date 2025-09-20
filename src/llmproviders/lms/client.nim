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

proc prepareChatReqData(
  model: string,
  userPrompt: string,
  systemPrompt = "",
  jsonSchema: JsonNode = nil,
  replyStartWithJson = false,
  tools: JsonNode = nil,
): JsonNode =
  writeFile("req.txt", systemPrompt & "\n\n" & userPrompt)
  result = %*{ "model": model }
  if jsonSchema != nil:
    result["response_format"] = %*{
      "type": "json_schema",
      "json_schema": {
        "strict": "true",
        "schema": jsonSchema
      }
    }
  var messages = newSeq[JsonNode]()
  if systemPrompt.len > 0:
    messages.add %*{ "role": "system", "content": systemPrompt }
  messages.add %*{ "role": "user", "content": userPrompt }
  if replyStartWithJson:
    messages.add %*{ "role": "assistant", "content": "{" }
  result["messages"] = %*messages
  if tools != nil:
    result["tools"] = tools

proc chat*(self: LmsClient,
  model: string,
  messages: seq[JsonNode],
  responseFormat: JsonNode = nil,
  tools: seq[JsonNode] = @[],
  host = "",
): Future[LmChatCompletion] {.async.} =
  let url = (if host.len > 0: host.parseUri else: self.host) / "chat" / "completions"
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

proc chat*(self: LmsClient,
  model: string,
  userPrompt: string,
  systemPrompt = "",
  jsonSchema: JsonNode = nil,
  replyStartWithJson = false,
  host = "",
  tools: JsonNode = nil
): Future[LmChatCompletion] {.async.} =
  let url = (if host.len > 0: host.parseUri else: self.host) / "chat" / "completions"
  let data = prepareChatReqData(model, userPrompt, systemPrompt, jsonSchema, replyStartWithJson, tools)
  let res = await request(url, data = data, httpMethod = HttpPost)
  res.newLmChatCompletion

type
  ChatStreamCb* = proc (chunk: LmChatCompletionChunk)

proc chatStream*(self: LmsClient,
  model: string,
  userPrompt: string,
  cb: ChatStreamCb,
  systemPrompt = "",
  jsonSchema: JsonNode = nil,
  replyStartWithJson = false,
  host = "",
  tools: JsonNode = nil,
) {.async.} =
  let url = (if host.len > 0: host.parseUri else: self.host) / "chat" / "completions"
  var data = prepareChatReqData(model, userPrompt, systemPrompt, jsonSchema, replyStartWithJson, tools)
  data["stream"] = %true
  let body = $data
  let headers = newHttpHeaders({ "Content-Type": "application/json; charset=utf-8" })
  let client = newAsyncHttpClient()
  try:
    let res = await client.request(url, headers = headers, body = body, httpMethod = HttpPost)
    var (ok, buf) = await res.bodyStream.read
    while ok:
      if buf.startsWith("data: "):
        let data = buf[6 .. ^1]
        if data.startsWith("[DONE]"): break
        cb(newLmChatCompletionChunk(data.parseJson))
      else:
        raise newException(ValueError, "Unknown event: " & buf)
      (ok, buf) = await res.bodyStream.read
  finally:
    client.close
