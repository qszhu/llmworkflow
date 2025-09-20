import std/[
  strtabs,
]

import llmprovider



type
  LlmBlock* = ref object
    provider*: LlmProvider
    model*: string
    messages*: LlmMessages
    context*: StringTableRef
    toolHost*: LlmToolHost
    outputs*: seq[string]

proc newLlmBlock*(provider: LlmProvider, model: string,
  messages: LlmMessages = newLlmMessages(),
  context = newStringTable(),
  toolHost: LlmToolHost = nil,
): LlmBlock =
  result.new
  result.provider = provider
  result.model = model
  result.messages = messages
  result.context = context
  result.toolHost = toolHost

proc run*(self: LlmBlock) {.async.} =
  var messages = self.messages # TODO: use context
  self.outputs = await self.provider.chatCompletion(
    self.model, messages, self.toolHost
  )