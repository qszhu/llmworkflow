import std/[
  json,
  sequtils,
  strformat,
  strtabs,
  strutils,
]



type
  FromJson[T] = proc (jso: JsonNode): T

type
  LmModel* = ref object
    raw*: JsonNode
    id*: string

proc newLmModel*(jso: JsonNode): LmModel =
  doAssert jso["object"].getStr == "model"
  result.new
  result.raw = jso
  result.id = jso["id"].getStr

proc `$`*(self: LmModel): string {.inline.} =
  &"Model: {self.id}"



type
  LmList*[T] = ref object
    raw*: JsonNode
    data*: seq[T]

proc newLmList*[T](jso: JsonNode, fromJson: FromJson[T]): LmList[T] =
  doAssert jso["object"].getStr == "list"
  result.new
  result.raw = jso
  result.data = jso["data"].mapIt(it.fromJson)

proc `$`*[T](self: LmList[T]): string {.inline.} =
  $self.data



type
  TokenUsage* = ref object
    raw*: JsonNode
    completionTokens*: int

proc newTokenUsage(jso: JsonNode): TokenUsage =
  result.new
  result.raw = jso
  result.completionTokens = jso["completion_tokens"].getInt



type
  RespStats* = ref object
    raw*: JsonNode
    tokensPerSecond*: float
    timeToFirstToken*: float
    generationTime*: float

proc newRespStats(jso: JsonNode): RespStats =
  result.new
  result.raw = jso
  result.tokensPerSecond = jso{"tokens_per_second"}.getFloat
  result.timeToFirstToken = jso{"time_to_first_token"}.getFloat
  result.generationTime = jso{"generation_time"}.getFloat



type
  LmToolCallFunction* = ref object
    raw*: JsonNode
    name*: string
    arguments*: JsonNode

proc newLmToolCallFunction(jso: JsonNode): LmToolCallFunction =
  result.new
  result.raw = jso
  result.name = jso["name"].getStr
  result.arguments = jso["arguments"].getStr.parseJson

type
  LmToolCall* = ref object
    raw*: JsonNode
    id*: string
    kind*: string
    function*: LmToolCallFunction

proc newLmToolCall*(jso: JsonNode): LmToolCall =
  result.new
  result.raw = jso
  result.id = jso["id"].getStr
  result.kind = jso["type"].getStr
  result.function = jso["function"].newLmToolCallFunction

type
  LmChatCompletion* = ref object
    raw*: JsonNode
    contents*: seq[string]
    usage*: TokenUsage
    stats*: RespStats
    toolCalls*: seq[LmToolCall]

proc newLmChatCompletion*(jso: JsonNode): LmChatCompletion =
  doAssert jso["object"].getStr == "chat.completion"
  result.new
  result.raw = jso
  result.contents = jso["choices"].mapIt(it["message"]{"content"}.getStr)
  result.usage = jso["usage"].newTokenUsage
  result.stats = jso["stats"].newRespStats
  result.toolCalls = jso["choices"].mapIt(
    it["message"]{"tool_calls"}.mapIt(it.newLmToolCall))
    .foldl(a & b)

proc `$`*(self: LmChatCompletion): string {.inline.} =
  self.contents.join("\n")



type
  LmChatCompletionChunk* = ref object
    raw*: JsonNode
    role*: string
    content*: string
    toolCalls*: JsonNode

proc newLmChatCompletionChunk*(jso: JsonNode): LmChatCompletionChunk =
  doAssert jso["object"].getStr == "chat.completion.chunk"
  result.new
  result.raw = jso
  let delta = jso["choices"][0]["delta"]
  result.role = delta{"role"}.getStr
  result.content = delta{"content"}.getStr
  result.toolCalls = delta{"tool_calls"}

proc `$`*(self: LmChatCompletionChunk): string {.inline.} =
  self.content