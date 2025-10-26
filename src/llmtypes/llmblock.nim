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
    stream*: bool

proc newLlmBlock*(provider: LlmProvider, model: string,
  messages: LlmMessages = newLlmMessages(),
  context = newStringTable(),
  toolHost: LlmToolHost = nil,
  stream = false,
): LlmBlock =
  result.new
  result.provider = provider
  result.model = model
  result.messages = messages
  result.context = context
  result.toolHost = toolHost
  result.stream = stream

proc run*(self: LlmBlock, query = "", cb: ChatContentCb = nil) {.async.} =
  var messages = self.messages # TODO: use context
  if query.len > 0:
    # discard last user message
    if messages.messages[^1]["role"].getStr == "user":
      discard messages.messages.pop
    self.provider.addUserMessage(messages, query)
  if self.stream and cb != nil:
    await self.provider.chatCompletionStream(
      self.model, messages, cb, self.toolHost
    )
  else:
    self.outputs = await self.provider.chatCompletion(
      self.model, messages, self.toolHost
    )
    for output in self.outputs:
      echo output
