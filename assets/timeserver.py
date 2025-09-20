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
  app.run(host="0.0.0.0", port=4234)