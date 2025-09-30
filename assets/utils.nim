import std/[
  json,
  macros,
]



macro tools*(arg: untyped) =
  #echo arg.treeRepr
  arg.expectKind nnkStmtList
  var funcs = newSeq[JsonNode]()
  for procDef in arg.children:
    if procDef.kind != nnkProcDef: continue
    var jso = %*{}
    var params = newSeq[JsonNode]()
    var returns = %*{}
    for child in procDef.children:
      case child.kind
      of nnkIdent:
        jso["name"] = %(child.strVal)
      of nnkFormalParams:
        for child in child.children:
          case child.kind
          of nnkIdent:
            returns["type"] = %(child.strVal)
          of nnkIdentDefs:
            params.add %*{
              "name": %(child[0].strVal),
              "type": %(child[1].strVal),
            }
          else: discard
      else: discard
    jso["params"] = %*params
    jso["returns"] = returns
    funcs.add jso
  let jso = %*{ "functions": funcs }
  result = newStmtList()
  result.add newLetStmt(ident"toolFuncs", newCall(
    ident"parseJson", newLit($jso)
  ))
  result.add arg
