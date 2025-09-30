import std/[
  asyncdispatch,
  json,
  sequtils,
]

export asyncdispatch, json



type
  LlmTool* = ref object of RootObj

method toJson*(self: LlmTool): JsonNode {.base.} =
  raise newException(CatchableError, "not implemented")

type
  LlmFuncParam* = ref object
    name*: string
    kind*: string
    desc*: string
    required*: bool

proc newLlmFuncParam*(name, kind, desc: string, required = true): LlmFuncParam =
  result.new
  result.name = name
  result.kind = kind
  result.desc = desc
  result.required = required

proc llmFuncParamFromJson*(jso: JsonNode): LlmFuncParam =
  result.new
  result.name = jso["name"].getStr
  result.kind = jso["type"].getStr
  result.desc = jso{"description"}.getStr
  result.required = jso{"required"}.getBool(true)

type
  LlmFunc* = ref object of LlmTool
    name*: string
    desc*: string
    params*: seq[LlmFuncParam]

proc newLlmFunc*(name, desc: string, params: seq[LlmFuncParam] = @[]): LlmFunc =
  result.new
  result.name = name
  result.desc = desc
  result.params = params

proc llmFuncFromJson*(jso: JsonNode): LlmFunc =
  result.new
  result.name = jso["name"].getStr
  result.desc = jso{"description"}.getStr
  result.params = jso["params"].mapIt(it.llmFuncParamFromJson)

type
  LlmToolCall* = ref object of RootObj
    name*: string

method toJson*(self: LlmToolCall): JsonNode {.base.} =
  raise newException(CatchableError, "not implemented")

type
  LlmFuncCall* = ref object of LlmToolCall
    args*: JsonNode

proc newLLmFuncCall*(name: string, args: JsonNode): LlmFuncCall =
  result.new
  result.name = name
  result.args = args

method toJson*(self: LlmFuncCall): JsonNode =
  %*{
    "name": self.name,
    "args": self.args,
  }
