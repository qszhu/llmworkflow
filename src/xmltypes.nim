import std/[
  os,
  strformat,
  strutils,
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

proc processImageAttachment(xml: XmlNode): (string, int, int) =
  let fn = xml.child("path")[0].text
  let (_, _, ext) = fn.splitFile
  let mimeType =
    case ext
    of ".jpg", ".jpeg":
      "image/jpeg"
    else:
      raise newException(ValueError, "unsupported image extension: " & ext)
  let (data, width, height) = convertImage(fn)
  return (&"data:{mimeType};base64,{data}", width, height)

proc processAttachments(xml: XmlNode): LlmMessageContent =
  result = newLlmMessageContent()
  if xml == nil: return
  for child in xml.items:
    case child.tag
    of "image":
      let (data, w, h) = processImageAttachment(child)
      result.addImageData(data, w, h)
    else:
      raise newException(ValueError, "unknown attachment type: " & child.tag)

proc newLlmMessages(provider: LlmProvider, xml: XmlNode): LlmMessages =
  result = newLlmMessages()
  for msg in xml:
    doAssert msg.tag == "message"
    let role = msg.child("role").innerText
    var content = ""
    if msg.child("content") != nil:
      content = msg.child("content")[0].text
    case role
    of "system":
      if content.len > 0:
        provider.addSystemMessage(result, content)
    of "user":
      let attachments = msg.child("attachments")
      let attachmentContent = processAttachments(attachments)
      if not attachmentContent.isEmpty:
        if content.len > 0:
          attachmentContent.addText(content)
        provider.addUserMessage(result, attachmentContent)
      else:
        if content.len > 0:
          provider.addUserMessage(result, content)
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
  let stream = xml.child("stream").innerText.toLowerAscii == "true"
  newLlmBlock(provider, model, messages, toolHost = toolHost, stream = stream)
