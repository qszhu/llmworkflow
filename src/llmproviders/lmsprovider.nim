import std/[
  logging,
  sequtils,
]

import ../llmtypes/llmprovider

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

proc toJson(self: LlmFunc): JsonNode =
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

method chatCompletion*(self: LmsProvider,
  model: string,
  messages: LlmMessages,
  tools: LlmToolServer = nil,
): Future[seq[string]] {.async.} =
  var messages = messages
  var res = await self.client.chat(model, messages = messages.messages,
    tools = tools.tools.mapIt(it.LlmFunc.toJson))
  result.add $res
  if res.toolCalls.len == 0: return
  if tools == nil:
    logging.warn "No tool implementation provided"
    return
  while res.toolCalls.len > 0:
    for toolCall in res.toolCalls:
      logging.debug "calling: ", toolCall.function.name
      self.addToolCalls messages, @[toolCall.raw]
      let funcCall = newLLmFuncCall(toolCall.function.name, toolCall.function.arguments)
      let content = await tools.callTool(funcCall.LlmToolCall)
      self.addToolCallRes messages, toolCall.id, content
    res = await self.client.chat(model, messages = messages.messages,
      tools = tools.tools.mapIt(it.LlmFunc.toJson))
    result.add $res