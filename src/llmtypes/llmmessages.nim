import std/[
  json,
]



type
  LlmMessages* = ref object
    messages*: seq[JsonNode]

proc newLlmMessages*(): LlmMessages =
  result.new
  result.messages = newSeq[JsonNode]()

type
  LlmMessageContent* = ref object
    contents: seq[JsonNode]

proc newLlmMessageContent*(): LlmMessageContent =
  result.new
  result.contents = newSeq[JsonNode]()

proc addText*(self: LlmMessageContent, text: string) =
  self.contents.add %*{
    "type": "text",
    "text": text,
  }

proc addImageData*(self: LlmMessageContent, data: string, width, height: int) =
  self.contents.add %*{
    "type": "image_url",
    "image_url": %*{
      "url": data,
    },
  }

proc toJson*(self: LlmMessageContent): JsonNode {.inline.} =
  %*(self.contents)

proc isEmpty*(self: LlmMessageContent): bool {.inline.} =
  self.contents.len == 0
