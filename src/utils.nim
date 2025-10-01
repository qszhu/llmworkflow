import std/[
  json,
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
