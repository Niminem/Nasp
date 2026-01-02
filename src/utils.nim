import std/[strtabs, parseopt]
 
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