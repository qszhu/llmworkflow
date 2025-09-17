import std/[
  asyncdispatch,
]

import llmmessages, llmtool

export asyncdispatch
export llmmessages, llmtool



type
  LlmProvider* = ref object of RootObj
    name*: string

method addSystemMessage*(self: LlmProvider, msgs: LlmMessages, content: string) {.base.} =
  raise newException(CatchableError, "Not implemented")

method addUserMessage*(self: LlmProvider, msgs: LlmMessages, content: string) {.base.} =
  raise newException(CatchableError, "Not implemented")

method addToolCalls*(self: LlmProvider, msgs: LlmMessages, toolCalls: seq[JsonNode]) {.base.} =
  raise newException(CatchableError, "Not implemented")

method addToolCallRes*(self: LlmProvider, msgs: LlmMessages, toolCallId, content: string) {.base.} =
  raise newException(CatchableError, "Not implemented")

method chatCompletion*(self: LlmProvider,
  model: string,
  messages: LlmMessages,
  tools: LlmToolServer = nil,
): Future[seq[string]] {.base, async.} =
  raise newException(CatchableError, "Not implemented")
