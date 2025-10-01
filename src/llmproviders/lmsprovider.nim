import std/[
  logging,
  sequtils,
]

import ../llmtypes/llmprovider
import ../utils
import lms/client



proc toJson(params: seq[LlmFuncParam]): JsonNode =
  let props = %*{}
  for param in params:
    props[param.name] = %*{
      "type": param.kind,
      "description": param.desc
    }
  let required = params.filterIt(it.required).mapIt(it.name)
  %*{
    "type": "object",
    "properties": props,
    "required": %*required,
  }

method toJson(self: LlmFunc): JsonNode =
  %*{
    "type": "function",
    "function": %*{
      "name": self.name,
      "description": self.desc,
      "parameters": self.params.toJson,
    }
  }

type
  LmsProvider* = ref object of LlmProvider
    client: LmsClient

proc newLmsProvider*(host: string): LmsProvider =
  result.new
  result.name = "LM Studio"
  result.client = newLmsClient(host)

method addSystemMessage*(self: LmsProvider, msgs: LlmMessages, content: string) =
  msgs.messages.add %*{
    "role": "system",
    "content": content,
  }

method addUserMessage*(self: LmsProvider, msgs: LlmMessages, content: string) =
  msgs.messages.add %*{
    "role": "user",
    "content": content,
  }

method addToolCalls*(self: LmsProvider, msgs: LlmMessages, toolCalls: seq[JsonNode]) =
  msgs.messages.add %*{
    "role": "assistant",
    "tool_calls": toolCalls,
  }

method addToolCallRes*(self: LmsProvider, msgs: LlmMessages, toolCallId, content: string) =
  msgs.messages.add %*{
    "role": "tool",
    "tool_call_id": toolCallId,
    "content": content
  }

proc toJson(host: LlmToolHost): Future[seq[JsonNode]] {.async.} =
  if host == nil: @[] else: (await host.getTools()).mapIt(it.toJson)

method chatCompletion*(self: LmsProvider,
  model: string,
  messages: LlmMessages,
  toolHost: LlmToolHost = nil,
): Future[seq[string]] {.async.} =
  var messages = messages
  var res = await self.client.chat(model, messages = messages.messages,
    tools = await toolHost.toJson,
  )
  result.add $res

  if res.toolCalls.len == 0: return

  if toolHost == nil:
    logging.warn "No tool implementation provided"
    return

  while res.toolCalls.len > 0:
    for toolCall in res.toolCalls:
      logging.debug "calling: ", toolCall.function.name
      self.addToolCalls messages, @[toolCall.raw]

      let funcCall = newLlmFuncCall(toolCall.function.name, toolCall.function.arguments)
      let content = await toolHost.callTool(funcCall)
      self.addToolCallRes messages, toolCall.id, content

    res = await self.client.chat(model, messages = messages.messages,
      tools = await toolHost.toJson,
    )
    result.add $res

method chatCompletionStream*(self: LmsProvider,
  model: string,
  messages: LlmMessages,
  contentCb: ChatContentCb,
  toolHost: LlmToolHost = nil,
) {.async.} =
  var messages = messages
  var toolCalls = newJArray()

  proc chatCb(chunk: LmChatCompletionChunk) =
    contentCb(chunk.content)
    if chunk.toolCalls != nil:
      logging.debug chunk.toolCalls
      toolCalls.mergeToolCallJson(chunk.toolCalls)

  await self.client.chatStream(model,
    messages = messages.messages,
    tools = await toolHost.toJson,
    cb = chatCb,
  )

  if toolCalls.len == 0: return
  if toolHost == nil:
    logging.warn "No tool implementation provided"
    return

  while toolCalls.len > 0:
    logging.debug toolCalls
    for toolCall in toolCalls:
      let tc = toolCall.newLmToolCall
      logging.debug "calling: ", tc.function.name
      self.addToolCalls messages, @[tc.raw]

      let funcCall = newLlmFuncCall(tc.function.name, tc.function.arguments)
      let content = await toolHost.callTool(funcCall)
      self.addToolCallRes messages, tc.id, content

    toolCalls = newJArray()
    await self.client.chatStream(model,
      messages = messages.messages,
      tools = await toolHost.toJson,
      cb = chatCb,
    )



when isMainModule:
  let provider = newLmsProvider("http://localhost:1234/api/v0")
  let messages = newLlmMessages()
  provider.addUserMessage(messages, "What time is it?")
  let model = "qwen/qwen3-8b"
  let toolHost = newLlmToolHost()
  toolHost.addServer("http://localhost:2234")

  when false:
    block:
      for reply in waitFor provider.chatCompletion(model, messages):
        echo reply

  when true:
    block:
      proc cb(text: string) =
        stdout.write text
        stdout.flushFile
      waitFor provider.chatCompletionStream(model, messages, cb, toolHost)
