import std/[
  strtabs,
]

import llmprovider



type
  LlmBlock = ref object
    provider*: LlmProvider
    model*: string
    messages*: LlmMessages
    context*: StringTableRef
    tools*: LlmToolServer
    outputs*: seq[string]

proc newLlmBlock*(provider: LlmProvider, model: string,
  messages: LlmMessages = newLlmMessages(),
  context = newStringTable(),
  tools: LlmToolServer = nil,
): LlmBlock =
  result.new
  result.provider = provider
  result.model = model
  result.messages = messages
  result.context = context
  result.tools = tools

proc run*(self: LlmBlock) {.async.} =
  var messages = self.messages # TODO: use context
  self.outputs = await self.provider.chatCompletion(
    self.model, messages, self.tools
  )