import std/[
  json,
]



proc merge*(a, b: JsonNode): JsonNode =
  if a.kind == JNull and b.kind == JNull: return newJNull()
  if a.kind == JNull: return b
  if b.kind == JNull: return a
  if a.kind == JArray:
    doAssert b.kind == JArray
    result = newJArray()
    for i in 0 ..< max(len(a), len(b)):
      let ai = if i < len(a): a[i] else: newJNull()
      let bi = if i < len(b): b[i] else: newJNull()
      result.add merge(ai, bi)
    return
  if a.kind == JObject:
    doAssert b.kind == JObject
    result = newJObject()
    for k in a.keys:
      let av = a[k]
      let bv = if k in b: b[k] else: newJNull()
      result[k] = merge(av, bv)
    for k in b.keys:
      if k in result: continue
      result[k] = b[k]
    return
  return b
