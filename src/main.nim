when isMainModule:
  import std/[
    asyncdispatch,
    logging,
    os,
    xmlparser,
  ]

  import xmltypes

  when not defined(release):
    addHandler(newConsoleLogger(levelThreshold = lvlWarn))

  if paramCount() < 1:
    echo "Usage: runXml <xml>"
    quit(-1)

  let xml = loadXml(paramStr(1))
  let blk = newLlmBlock(xml)

  proc chatCb(text: string) =
    stdout.write text
    stdout.flushFile

  waitFor blk.run(cb = chatCb)
