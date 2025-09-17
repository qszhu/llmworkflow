import std/[
  json,
]



type
  LlmMessages* = ref object
    messages*: seq[JsonNode]

proc newLlmMessages*(): LlmMessages =
  result.new
  result.messages = newSeq[JsonNode]()
