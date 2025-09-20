# LLM Workflow
Proof of concept for LLM tool use with MCP like architecture using websocket as transport

* xml description of an LLM block
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

* tool implementation exposed by websocket (in another language)
```python
from datetime import datetime
import json

from sanic import Sanic, response



async def getTimeNow():
  res = datetime.now().astimezone().isoformat()
  print(f"getTimeNow(): {res}")
  return res

async def processToolCall(jso):
  print(jso)
  funcName = jso["name"]
  if funcName == "get_time_now":
    return await getTimeNow()
  else:
    return "unknown function: " & funcName

app = Sanic("timeServerApp")

@app.websocket("/ws")
async def ws(request, ws):
  async for msg in ws:
    jso = json.loads(msg)
    await ws.send(await processToolCall(jso))

@app.get("/")
async def functions(request):
  return response.json({"functions": [
    {
      "name": "get_time_now",
      "description": "get the current time in ISO format",
      "params": [],
      "returns": {
        "type": "string",
        "description": "current time in ISO format",
      }
    }
  ]})

if __name__ == "__main__":
  app.run(host="0.0.0.0", port=2234)
```

* run LLM block with tool calls
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