import std/[
  xmltree,
]

import llmtypes
import llmproviders/lmsprovider

export xmltree, llmtypes


proc newLlmProvider(xml: XmlNode): LlmProvider =
  let kind = xml.child("type").innerText
  case kind
  of "lms":
    let host = xml.child("host").innerText
    newLmsProvider(host)
  else:
    raise newException(ValueError, "unknown llm provider type: " & kind)

proc newLlmMessages(provider: LlmProvider, xml: XmlNode): LlmMessages =
  result = newLlmMessages()
  for msg in xml:
    doAssert msg.tag == "message"
    let role = msg.child("role").innerText
    let content = msg.child("content")[0].text
    case role
    of "system":
      provider.addSystemMessage(result, content)
    of "user":
      provider.addUserMessage(result, content)
    else:
      raise newException(ValueError, "unknown message role: " & role)

proc newLlmToolHost(xml: XmlNode): LlmToolHost =
  result = newLlmToolHost()
  for server in xml:
    result.addServer server.innerText

proc newLlmBlock*(xml: XmlNode): LlmBlock =
  doAssert xml.tag == "block"
  let provider = newLlmProvider(xml.child("provider"))
  let model = xml.child("model").innerText
  let messages = provider.newLlmMessages(xml.child("messages"))
  let toolHost = newLlmToolHost(xml.child("toolHost"))
  newLlmBlock(provider, model, messages, toolHost = toolHost)
