import std/[
  asyncdispatch,
  httpclient,
  json,
  logging,
  sequtils,
  strtabs,
  uri,
]

export asyncdispatch, httpclient, json, uri



proc toStringTable(jso: JsonNode): StringTableRef =
  result = newStringTable()
  for k, v in jso.pairs:
    if v.kind != JString:
      result[k] = $v
    else:
      result[k] = v.getStr

proc toQueries(jso: JsonNode): seq[(string, string)] {.inline.} =
  jso.toStringTable.pairs.toSeq

proc request*(uri: Uri,
  params: JsonNode = %*{}, # query参数
  data: JsonNode = %*{},   # body参数
  httpMethod = HttpPost,
  headers: HttpHeaders = newHttpHeaders(),
): Future[JsonNode] {.async.} =
  let client = newAsyncHttpClient()

  let uri = uri ? (params.toQueries & decodeQuery(uri.query).toSeq)

  let headers = headers
  headers["Content-Type"] = "application/json; charset=utf-8"

  let body = $data
  logging.debug uri
  logging.debug headers
  logging.debug data

  try:
    let resp = await client.request(uri, httpMethod = httpMethod, headers = headers, body = body)
    let respBody = await resp.body
    return respBody.parseJson
  finally:
    client.close
