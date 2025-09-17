import std/[
  asyncdispatch,
  json,
  strtabs,
]

export asyncdispatch, json



type
  LlmTool* = ref object of RootObj

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

type
  LlmToolCall* = ref object of RootObj

type
  LlmFuncCall* = ref object of LlmToolCall
    name*: string
    args*: StringTableRef

proc newLLmFuncCall*(name: string, args: StringTableRef): LlmFuncCall =
  result.new
  result.name = name
  result.args = args

type
  LlmToolServer* = ref object of RootObj
    tools*: seq[LlmTool]

method callTool*(self: LlmToolServer, tc: LlmToolCall): Future[string] {.base, async.} =
  raise newException(CatchableError, "not implemented")