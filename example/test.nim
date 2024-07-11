import std/[jsconsole, jsffi]

template log(body) =
    console.log(body)

proc returnTest: cstring {.exportc.} = # call this func with nasp run --func:"returnTest"
    return cstring"Hello, World!"

proc noReturnTest {.exportc.} = # call this w/ run cmd & then use nasp open --logs to see output
    log "what up"

proc singleParamTest(p: int): int {.exportc.} = # call w/ nasp run --func:"singleParamTest" --args:'[10]'
    return p + p

proc shouldBreak {.exportc.} = # call w/ nasp run --func:"shouldBreak" (obviously this will not throw err)
    var nonExistantObj {.importc,nodecl.}: JsObject
    log nonExistantObj