import std/[
  sequtils,
]

import llmtypes
import llmproviders/lmsprovider


import times

proc getTimeNow(): string =
  $(now())



type
  TestToolServer* = ref object of LlmToolServer

proc newTestToolServer*(): TestToolServer =
  result.new
  result.tools = @[
    newLlmFunc("get_time_now", "get current time in iso format")
  ].mapIt(it.LlmTool)

method callTool*(self: TestToolServer, tc: LlmToolCall): Future[string] {.async.} =
  let fc = tc.LlmFuncCall
  case fc.name
  of "get_time_now":
    return getTimeNow()
  else:
    return "unknown function: " & fc.name



when isMainModule:
  import std/logging

  when not defined(release):
    addHandler(newConsoleLogger(levelThreshold = lvlWarn))

  let provider = newLmsProvider("http://localhost:1234/api/v0")
  let model = "qwen/qwen3-8b"
  let messages = newLlmMessages()
  provider.addUserMessage(messages, "What time is it?")
  let blk = newLlmBlock(provider, model, messages, tools = newTestToolServer())
  waitFor blk.run
  for output in blk.outputs:
    echo output
