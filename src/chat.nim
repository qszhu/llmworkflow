when isMainModule:
  import std/[
    asyncdispatch,
    logging,
    os,
    rdstdin,
    xmlparser,
  ]

  import xmltypes

  when not defined(release):
    addHandler(newConsoleLogger(levelThreshold = lvlWarn))

  if paramCount() < 1:
    echo "Usage: chatWithXml <xml>"
    quit(-1)

  let xml = loadXml(paramStr(1))
  let blk = newLlmBlock(xml)

  proc chatCb(text: string) =
    stdout.write text
    stdout.flushFile

  var line: string
  while true:
    let ok = readLineFromStdin("\r\nchat: ", line)
    if not ok: break
    if line.len == 0: continue
    waitFor blk.run(line, chatCb)

  echo "bye."

