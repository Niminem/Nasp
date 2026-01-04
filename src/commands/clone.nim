## Clone and Pull commands for nasp
## Clone: fetches a remote Apps Script project by scriptId
## Pull: fetches updates for an existing local project

import std/[strtabs, json, httpclient, os, strutils]
import ../auth/profiles
import ../google_apis/apps_script

# =============================================================================
# Helper: Convert file type to extension
# =============================================================================

proc fileTypeToExt(fileType: string): string =
    ## Converts Apps Script file types to file extensions
    case fileType
    of "SERVER_JS": ".js"
    of "HTML": ".html"
    else: ".json"

# =============================================================================
# Helper: Create directories from file path
# =============================================================================

proc createDirsFromFilePath(file: string) =
    ## Creates directories from a file path if they don't exist
    let pathHead = file.splitPath().head
    if pathHead != "":
        var
            dirNames = pathHead.split("/")
            dir: string
        for i in 0 .. dirNames.high:
            dir = dir / dirNames[i]
            if not dirExists(dir): createDir(dir)

# =============================================================================
# Shared Clone/Pull Logic
# =============================================================================

type CloneOrPull* = enum
    Clone, Pull

proc handleCloneOrPull*(params: StringTableRef, cmd: CloneOrPull) =
    ## Shared handler for clone and pull commands
    ## Clone flags:
    ##   --scriptId: string (required)
    ##   --versionNumber: int (optional)
    ##   --rootDir: string (optional, defaults to current directory)
    ##   --profile: string (optional)
    ## Pull flags:
    ##   --versionNumber: int (optional)
    ##   --profile: string (optional)
    
    let configPath = getCurrentDir() / "nasp.json"
    
    # Validate parameters
    if cmd == Clone:
        if not params.hasKey("scriptId"):
            quit("No --scriptId flag provided. Usage: nasp clone --scriptId:<script-id>", QuitFailure)
    else:
        # Pull requires nasp.json to exist
        if not fileExists(configPath):
            quit("nasp.json not found in current directory. Run 'nasp clone' first.", QuitFailure)
    
    # Get profile
    let profile = if params.hasKey("profile"): params["profile"] else: getDefaultProfile()
    
    # Load profile credentials (for projectId) and get valid access token
    let profileCreds = loadProfileCredentials(profile)
    let accessToken = getValidAccessToken(profile)
    
    # Determine scriptId
    var projectInfo: JsonNode
    let scriptId = if cmd == Clone:
        params["scriptId"]
    else:
        projectInfo = parseFile(configPath)
        if not projectInfo.hasKey("scriptId"):
            quit("No scriptId found in nasp.json", QuitFailure)
        projectInfo["scriptId"].getStr()
    
    # Determine root directory for project files
    let rootDir = if cmd == Clone:
        if params.hasKey("rootDir"): 
            params["rootDir"].absolutePath() 
        else: 
            getCurrentDir()
    else:
        if projectInfo.hasKey("rootDir"):
            projectInfo["rootDir"].getStr()
        else:
            getCurrentDir()
    
    echo (if cmd == Clone: "Cloning" else: "Pulling") & " project..."
    
    # Fetch project metadata first (to get title)
    let projectMetaResponse = getProject(scriptId, accessToken)
    if projectMetaResponse.code != Http200:
        quit("Failed to fetch project metadata.\nCode: " & 
             $projectMetaResponse.code & "\nResponse: " & projectMetaResponse.body, QuitFailure)
    
    let projectMeta = parseJson(projectMetaResponse.body)
    let title = projectMeta["title"].getStr()
    
    echo "Project: " & title
    echo "Script ID: " & scriptId
    
    # Fetch project content
    echo "Fetching project content..."
    let version = if params.hasKey("versionNumber"): 
        params["versionNumber"].parseInt() 
    else: 
        -1
    
    let projectContent = getProjectContent(scriptId, accessToken, version)
    if projectContent.code != Http200:
        quit("Failed to fetch project content.\nCode: " & 
             $projectContent.code & "\nResponse: " & projectContent.body, QuitFailure)
    
    # Create/update nasp.json for clone
    if cmd == Clone:
        var newProjectInfo = %*{
            "scriptId": scriptId,
            "title": title,
            "projectId": profileCreds.projectId,
            "rootDir": rootDir
        }
        
        # Include parentId if it exists (container-bound script)
        if projectMeta.hasKey("parentId"):
            newProjectInfo["parentId"] = projectMeta["parentId"]
        
        writeFile(configPath, newProjectInfo.pretty(2))
        echo "Created nasp.json"
    
    # Create project files and directories
    echo "Creating project files and directories..."
    let projectContentJson = parseJson(projectContent.body)
    var fileCount = 0
    
    for file in projectContentJson["files"].getElems():
        let
            fileName = file["name"].getStr()
            fileExt = fileTypeToExt(file["type"].getStr())
            fileSource = file["source"].getStr()
            filePath = rootDir / fileName & fileExt
        
        createDirsFromFilePath(filePath)
        writeFile(filePath, fileSource)
        echo "  " & fileName & fileExt
        inc fileCount
    
    echo ""
    echo (if cmd == Clone: "Cloned" else: "Pulled") & " project successfully!"
    echo "Files: " & $fileCount
    echo "Location: " & rootDir

# =============================================================================
# Command Handlers
# =============================================================================

proc handleClone*(params: StringTableRef) =
    ## Handle the clone command
    handleCloneOrPull(params, Clone)

proc handlePull*(params: StringTableRef) =
    ## Handle the pull command
    handleCloneOrPull(params, Pull)

