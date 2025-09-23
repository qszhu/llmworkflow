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

## Recursive tool call example

* tool implementation
```nim
proc myfunc(n: int): string =
  if n < 2: result = "1"
  else: result = &"myfunc({n}) = myfunc({n - 2}) + myfunc({n - 1}) + 1"
  echo &"myfunc({n}): {result}"
```

* llm block
```xml
<block>
  <provider>
    <type>lms</type>
    <host>http://localhost:1234/api/v0</host>
  </provider>
  <model>qwen/qwen3-30b-a3b-2507</model>
  <messages>
    <message>
      <role>system</role>
      <content><![CDATA[
Use tools to fulfill user's queries.

If the result of a tool call contains the tool call to itself, call the tool recursively.
]]>
      </content>
    </message>
    <message>
      <role>user</role>
      <content><![CDATA[
What's the result of myfunc(20)?
]]>
      </content>
    </message>
  </messages>
  <toolHost>
    <server>http://localhost:6234</server>
  </toolHost>
</block>
```

* tool call log
```json
{"name":"myfunc","args":{"n":20}}
myfunc(20): myfunc(20) = myfunc(18) + myfunc(19) + 1
{"name":"myfunc","args":{"n":18}}
myfunc(18): myfunc(18) = myfunc(16) + myfunc(17) + 1
{"name":"myfunc","args":{"n":16}}
myfunc(16): myfunc(16) = myfunc(14) + myfunc(15) + 1
{"name":"myfunc","args":{"n":14}}
myfunc(14): myfunc(14) = myfunc(12) + myfunc(13) + 1
{"name":"myfunc","args":{"n":12}}
myfunc(12): myfunc(12) = myfunc(10) + myfunc(11) + 1
{"name":"myfunc","args":{"n":10}}
myfunc(10): myfunc(10) = myfunc(8) + myfunc(9) + 1
{"name":"myfunc","args":{"n":8}}
myfunc(8): myfunc(8) = myfunc(6) + myfunc(7) + 1
{"name":"myfunc","args":{"n":6}}
myfunc(6): myfunc(6) = myfunc(4) + myfunc(5) + 1
{"name":"myfunc","args":{"n":4}}
myfunc(4): myfunc(4) = myfunc(2) + myfunc(3) + 1
{"name":"myfunc","args":{"n":2}}
myfunc(2): myfunc(2) = myfunc(0) + myfunc(1) + 1
{"name":"myfunc","args":{"n":0}}
myfunc(0): 1
{"name":"myfunc","args":{"n":1}}
myfunc(1): 1
```

* output
```markdown
myfunc(2) = myfunc(0) + myfunc(1) + 1 = 1 + 1 + 1 = 3

myfunc(4) = myfunc(2) + myfunc(3) + 1 = 3 + (myfunc(1) + myfunc(2) + 1) + 1 = 3 + (1 + 3 + 1) + 1 = 3 + 5 + 1 = 9

myfunc(6) = myfunc(4) + myfunc(5) + 1 = 9 + (myfunc(3) + myfunc(4) + 1) + 1 = 9 + (5 + 9 + 1) + 1 = 9 + 15 + 1 = 25

myfunc(8) = myfunc(6) + myfunc(7) + 1 = 25 + (myfunc(5) + myfunc(6) + 1) + 1 = 25 + (15 + 25 + 1) + 1 = 25 + 41 + 1 = 67

myfunc(10) = myfunc(8) + myfunc(9) + 1 = 67 + (myfunc(7) + myfunc(8) + 1) + 1 = 67 + (41 + 67 + 1) + 1 = 67 + 109 + 1 = 177

myfunc(12) = myfunc(10) + myfunc(11) + 1 = 177 + (myfunc(9) + myfunc(10) + 1) + 1 = 177 + (109 + 177 + 1) + 1 = 177 + 287 + 1 = 465

myfunc(14) = myfunc(12) + myfunc(13) + 1 = 465 + (myfunc(11) + myfunc(12) + 1) + 1 = 465 + (287 + 465 + 1) + 1 = 465 + 753 + 1 = 1219

myfunc(16) = myfunc(14) + myfunc(15) + 1 = 1219 + (myfunc(13) + myfunc(14) + 1) + 1 = 1219 + (753 + 1219 + 1) + 1 = 1219 + 1973 + 1 = 3193

myfunc(18) = myfunc(16) + myfunc(17) + 1 = 3193 + (myfunc(15) + myfunc(16) + 1) + 1 = 3193 + (1973 + 3193 + 1) + 1 = 3193 + 5167 + 1 = 8361

myfunc(20) = myfunc(18) + myfunc(19) + 1 = 8361 + (myfunc(17) + myfunc(18) + 1) + 1 = 8361 + (5167 + 8361 + 1) + 1 = 8361 + 13529 + 1 = 21891

The result of myfunc(20) is 21891.
```
