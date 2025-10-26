import std/[
  base64,
  json,
  logging,
  os,
  osproc,
  tempfiles,
  strformat,
  strutils,
]



proc mergeToolCallJson*(a, b: JsonNode) =
  doAssert b.kind == JArray
  for jso in b:
    while len(a) <= jso["index"].getInt:
      a.add %*{
        "id": "",
        "type": "function",
        "function": %*{
          "name": "",
          "arguments": ""
        }
      }
  for jso in b:
    let i = jso["index"].getInt
    if "id" in jso:
      a[i]["id"] = jso["id"]
    if "function" in jso:
      if "name" in jso["function"]:
        a[i]["function"]["name"] = jso["function"]["name"]
      if "arguments" in jso["function"]:
        a[i]["function"]["arguments"] = %(a[i]["function"]["arguments"].getStr & jso["function"]["arguments"].getStr)

proc getImageDim*(fn: string): (int, int) =
  let cmd = &"identify -format \"%wx%h\" {fn}"
  let output = execProcess(cmd)
  let parts = output.strip.split("x")
  (parts[0].parseInt, parts[1].parseInt)

proc convertImage*(fn: string, size = "1960x1960"): (string, int, int) =
  let (cfile, path) = createTempFile("llmblock_", ".jpg")
  cfile.close
  let cmd = &"magick {fn} -resize {size} {path}"
  doAssert execShellCmd(cmd) == 0
  let (width, height) = getImageDim(path)
  logging.debug (width, height, path)
  result = (readFile(path).encode, width, height)
  removeFile(path)
