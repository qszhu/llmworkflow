import std/[
  asyncdispatch,
]

import llmmessages, llmtool, llmtoolhost

export asyncdispatch
export llmmessages, llmtool, llmtoolhost



type
  LlmProvider* = ref object of RootObj
    name*: string

method addSystemMessage*(self: LlmProvider, msgs: LlmMessages, content: string) {.base.} =
  raise newException(CatchableError, "Not implemented")

method addUserMessage*(self: LlmProvider, msgs: LlmMessages, content: string) {.base.} =
  raise newException(CatchableError, "Not implemented")

method addUserMessage*(self: LlmProvider, msgs: LlmMessages, content: LlmMessageContent) {.base.} =
  raise newException(CatchableError, "Not implemented")

method addToolCalls*(self: LlmProvider, msgs: LlmMessages, toolCalls: seq[JsonNode]) {.base.} =
  raise newException(CatchableError, "Not implemented")

method addToolCallRes*(self: LlmProvider, msgs: LlmMessages, toolCallId, content: string) {.base.} =
  raise newException(CatchableError, "Not implemented")

method chatCompletion*(self: LlmProvider,
  model: string,
  messages: LlmMessages,
  toolHost: LlmToolHost = nil,
): Future[seq[string]] {.base, async.} =
  raise newException(CatchableError, "Not implemented")

type
  ChatContentCb* = proc (text: string)

method chatCompletionStream*(self: LlmProvider,
  model: string,
  messages: LlmMessages,
  contentCb: ChatContentCb,
  toolHost: LlmToolHost = nil,
) {.base, async.} =
  raise newException(CatchableError, "Not implemented")
