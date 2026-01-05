import std/[strtabs, parseopt, os, strutils]

# =============================================================================
# Command Line Parsing
# =============================================================================
 
proc paramsToTable*(commandLineParams: seq[string]): StringTableRef =
    ## Parse command line parameters into a StringTable.
    ## Repeated keys are appended with comma delimiter.
    result = newStringTable(modeCaseSensitive)
    for kind, key, val in getopt(commandLineParams):
        case kind
        of cmdArgument: result["command"] = key
        of cmdShortOption, cmdLongOption:
            if result.hasKey(key):
                result[key] = result[key] & "," & val  # append repeated keys
            else:
                result[key] = val
        of cmdEnd: break

# =============================================================================
# File Type Helpers
# =============================================================================

proc fileTypeToExt*(fileType: string): string =
    ## Converts Apps Script file types to file extensions
    case fileType
    of "SERVER_JS": ".js"
    of "HTML": ".html"
    else: ".json"

proc createDirsFromFilePath*(file: string) =
    ## Creates directories from a file path if they don't exist
    let pathHead = file.splitPath().head
    if pathHead != "":
        var
            dirNames = pathHead.split("/")
            dir: string
        for i in 0 .. dirNames.high:
            dir = dir / dirNames[i]
            if not dirExists(dir): createDir(dir)