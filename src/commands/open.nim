## Open command for nasp
## Opens various Apps Script and GCP URLs in the browser

import std/[strtabs, json, os, browsers]

# =============================================================================
# Helper: Get container URL from type
# =============================================================================

proc getContainerUrl(parentId, containerType: string): string =
    ## Returns the appropriate Google Docs/Sheets/etc URL for the container
    case containerType
    of "docs": "https://docs.google.com/document/d/" & parentId & "/edit"
    of "sheets": "https://docs.google.com/spreadsheets/d/" & parentId & "/edit"
    of "slides": "https://docs.google.com/presentation/d/" & parentId & "/edit"
    of "forms": "https://docs.google.com/forms/d/" & parentId & "/edit"
    else: ""

# =============================================================================
# Open Command Handler
# =============================================================================

proc handleOpen*(params: StringTableRef) =
    ## Handle the open command
    ## No args: opens the Apps Script editor
    ## --editor: opens the Apps Script editor
    ## --logs: opens script executions/logs
    ## --apis: opens GCP APIs dashboard
    ## --creds: opens GCP credentials page
    ## --container: opens the container document (sheets, docs, etc.)
    
    # Check for nasp.json
    if not fileExists("nasp.json"):
        quit("nasp.json not found in current directory. Run 'nasp create' or 'nasp clone' first.", QuitFailure)
    
    let projectInfo = parseFile("nasp.json")
    
    # Get scriptId and projectId (required)
    if not projectInfo.hasKey("scriptId"):
        quit("No scriptId found in nasp.json", QuitFailure)
    if not projectInfo.hasKey("projectId"):
        quit("No projectId found in nasp.json", QuitFailure)
    
    let scriptId = projectInfo["scriptId"].getStr()
    let projectId = projectInfo["projectId"].getStr()
    
    # Get optional container info
    let parentId = if projectInfo.hasKey("parentId"): projectInfo["parentId"].getStr() else: ""
    let containerType = if projectInfo.hasKey("type"): projectInfo["type"].getStr() else: ""
    
    # Build URLs
    let editorUrl = "https://script.google.com/home/projects/" & scriptId & "/edit"
    let logsUrl = "https://script.google.com/home/projects/" & scriptId & "/executions"
    let apisUrl = "https://console.developers.google.com/apis/dashboard?project=" & projectId
    let credsUrl = "https://console.developers.google.com/apis/credentials?project=" & projectId
    
    # Check which URLs to open
    var opened = false
    
    if params.hasKey("editor"):
        openDefaultBrowser(editorUrl)
        echo "Opened: Apps Script Editor"
        opened = true
    
    if params.hasKey("logs"):
        openDefaultBrowser(logsUrl)
        echo "Opened: Script Executions"
        opened = true
    
    if params.hasKey("apis"):
        openDefaultBrowser(apisUrl)
        echo "Opened: GCP APIs Dashboard"
        opened = true
    
    if params.hasKey("creds"):
        openDefaultBrowser(credsUrl)
        echo "Opened: GCP Credentials"
        opened = true
    
    if params.hasKey("container"):
        if parentId == "":
            quit("This is a standalone project (no container document).", QuitFailure)
        let containerUrl = getContainerUrl(parentId, containerType)
        if containerUrl == "":
            quit("Unknown container type: " & containerType, QuitFailure)
        openDefaultBrowser(containerUrl)
        echo "Opened: Container (" & containerType & ")"
        opened = true
    
    # Default: open editor if no specific flag provided
    if not opened:
        openDefaultBrowser(editorUrl)
        echo "Opened: Apps Script Editor"

