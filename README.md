# LLM Workflow
Proof of concept for LLM tool use with MCP like architecture using websocket as transport

```xml
<block>
  <provider>
    <type>lms</type>
    <host>http://localhost:1234/api/v0</host>
  </provider>
  <model>qwen/qwen3-8b</model>
  <messages>
    <message>
      <role>user</role>
      <content><![CDATA[
What time is it?
]]>
      </content>
    </message>
  </messages>
  <toolHost>
    <server>http://localhost:2234</server>
  </toolHost>
</block>
```

```nim
import std/[
  asyncdispatch,
  asynchttpserver,
  json,
  times,
]

import ws



proc getTimeNow(): string =
  result = $(now())
  echo "getTimeNow(): ", result

proc processToolCall(jso: JsonNode): Future[string] {.async.} =
  echo jso
  let funcName = jso["name"].getStr
  case funcName
  of "get_time_now":
    return getTimeNow()
  else:
    return "unknown function: " & funcName

proc cb(req: Request) {.async, gcsafe.} =
  if req.url.path == "/ws":
    try:
      var ws = await newWebSocket(req)
      while ws.readyState == Open:
        let jso = (await ws.receiveStrPacket()).parseJson
        let res = await processToolCall(jso)
        await ws.send($res)
    except:
      echo getCurrentExceptionMsg()
  elif req.url.path == "/":
    let headers = {
      "Content-type": "application/json; charset=utf-8"
    }.newHttpHeaders()
    let resp = %*{
      "functions": @[%*{
        "name": "get_time_now",
        "description": "get the current time in ISO format",
        "params": @[],
        "returns": %*{
          "type": "string",
          "description": "current time in ISO format",
        }
      }]
    }
    await req.respond(Http200, $resp, headers)
  else:
    await req.respond(Http404, "Not found")

when isMainModule:
  var server = newAsyncHttpServer()
  waitFor server.serve(Port(2234), cb)
```

```bash
$ nim c -rf src/main.nim assets/time.xml
<think>
Okay, the user is asking "What time is it?" So I need to figure out the current time. The tools provided include a function called get_time_now, which returns the current time in ISO format. Since the user just wants to know the time, I should call that function. There are no parameters needed for it, so I'll generate the tool call accordingly.
</think>


<think>
Okay, the user asked, "What time is it?" I need to provide the current time. The tool called get_time_now was used, and it returned "2025-09-20T16:24:16+08:00". Let me check if that's the correct format. The ISO format includes the date and time with timezone offset, which is accurate. The user probably wants to know the current time in a specific location, but since they didn't specify, the ISO format should be sufficient. I'll present the time as received from the tool, making sure to mention it's in ISO format. That should answer their query clearly.
</think>

The current time is **2025-09-20T16:24:16+08:00** (ISO format). Let me know if you need it converted to a different time zone or format!
```