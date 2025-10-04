import std/[
  os,
  strformat,
  xmltree,
]

import llmtypes
import llmproviders/lmsprovider
import utils

export xmltree, llmtypes


proc newLlmProvider(xml: XmlNode): LlmProvider =
  let kind = xml.child("type").innerText
  case kind
  of "lms":
    let host = xml.child("host").innerText
    newLmsProvider(host)
  else:
    raise newException(ValueError, "unknown llm provider type: " & kind)

proc processImageAttachment(xml: XmlNode): string =
  let fn = xml.child("path")[0].text
  let (_, _, ext) = fn.splitFile
  let mimeType =
    case ext
    of ".jpg", ".jpeg":
      "image/jpeg"
    else:
      raise newException(ValueError, "unsupported image extension: " & ext)
  let data = convertImage(fn)
  return &"data:{mimeType};base64,{data}"

proc processAttachments(xml: XmlNode): LlmMessageContent =
  result = newLlmMessageContent()
  if xml == nil: return
  for child in xml.items:
    case child.tag
    of "image":
      result.addImageData processImageAttachment(child)
    else:
      raise newException(ValueError, "unknown attachment type: " & child.tag)

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
      let attachments = msg.child("attachments")
      let attachmentContent = processAttachments(attachments)
      provider.addUserMessage(result, attachmentContent)
    else:
      raise newException(ValueError, "unknown message role: " & role)

proc newLlmToolHost(xml: XmlNode): LlmToolHost =
  result = newLlmToolHost()
  if xml == nil: return
  for server in xml:
    result.addServer server.innerText

proc newLlmBlock*(xml: XmlNode): LlmBlock =
  doAssert xml.tag == "block"
  let provider = newLlmProvider(xml.child("provider"))
  let model = xml.child("model").innerText
  let messages = provider.newLlmMessages(xml.child("messages"))
  let toolHost = newLlmToolHost(xml.child("toolHost"))
  newLlmBlock(provider, model, messages, toolHost = toolHost)
