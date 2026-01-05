## Clone and Pull commands for nasp
## Clone: fetches a remote Apps Script project by scriptId
## Pull: fetches updates for an existing local project

import std/[strtabs, json, httpclient, os, strutils]
import ../auth/profiles
import ../google_apis/apps_script
import ../utils

# =============================================================================
# Shared Clone/Pull Logic
# =============================================================================

type CloneOrPull = enum
    Clone, Pull

proc handleCloneOrPull(params: StringTableRef, cmd: CloneOrPull) =
    ## Shared handler for clone and pull commands
    ## 
    ## Clone: Fetches an existing Apps Script project by its scriptId and saves
    ## the files locally. Creates a nasp.json config file in the root directory.
    ## 
    ## Pull: Updates local files by fetching the latest (or specified version)
    ## from the remote Apps Script project. Requires nasp.json to exist.
    ## 
    ## Clone flags:
    ##   --scriptId: string (required) - The Apps Script project ID to clone
    ##   --versionNumber: int (optional) - Specific version to clone; if not provided,
    ##                                     the project's HEAD version is returned (per Apps Script API)
    ##   --rootDir: string (optional) - Directory for project files (default: current dir)
    ##   --profile: string (optional) - Authentication profile (default: current default)
    ## 
    ## Pull flags:
    ##   --versionNumber: int (optional) - Specific version to pull; if not provided,
    ##                                     the project's HEAD version is returned (per Apps Script API)
    ##   --profile: string (optional) - Authentication profile (default: current default)
    ## 
    ## Clone behavior:
    ##   - Fails if nasp.json already exists in the target directory
    ##   - Creates nasp.json with project metadata
    ##   - Downloads all project files to the root directory
    ## 
    ## Pull behavior:
    ##   - Requires nasp.json to exist (run clone first)
    ##   - Uses rootDir from nasp.json to determine where to write files
    ##   - Overwrites existing local files with remote content
    ##   - Does NOT update nasp.json (preserves original config)
    ##   - Does NOT delete local files that were removed remotely
    ##   - Does NOT track or merge changes (simply replaces file contents)
    ## 
    ## Output files:
    ##   - nasp.json: Project configuration (scriptId, title, type, projectId, rootDir, parentId)
    ##   - *.js: Server-side JavaScript files (from SERVER_JS type)
    ##   - *.html: HTML files (from HTML type)
    ##   - *.json: JSON files including appsscript.json manifest
    ## 
    ## Note on file structure:
    ##   Files are saved with their full name as stored in Apps Script. If your project
    ##   uses folder-like naming on script.google.com (e.g., "utils/helpers"), nasp will
    ##   create matching local directories (e.g., utils/helpers.js).
    
    # Determine root directory first (needed for configPath)
    let rootDir = if cmd == Clone:
        if params.hasKey("rootDir"):
            params["rootDir"].absolutePath() 
        else: 
            getCurrentDir()
    else:
        getCurrentDir()  # For Pull, we read from current dir initially
    
    let configPath = rootDir / "nasp.json"
    
    # Validate parameters
    if cmd == Clone:
        if not params.hasKey("scriptId"):
            quit("No --scriptId flag provided. Usage: nasp clone --scriptId:<script-id>", QuitFailure)
        # Check if nasp.json already exists
        if fileExists(configPath):
            quit("nasp.json already exists in " & rootDir & ". Remove it first or use a different directory.", QuitFailure)
    else:
        # Pull requires nasp.json to exist
        if not fileExists(configPath):
            quit("nasp.json not found in current directory. Run 'nasp clone' first.", QuitFailure)
    
    # Get profile
    let profile = if params.hasKey("profile"): params["profile"] else: getDefaultProfile()
    echo "Using profile: " & profile
    
    # Load profile credentials (for projectId) and get valid access token
    let profileCreds = loadProfileCredentials(profile)
    let accessToken = getValidAccessToken(profile)
    
    # Determine scriptId and load project info for Pull
    var projectInfo: JsonNode
    var finalRootDir = rootDir
    
    let scriptId = if cmd == Clone:
            params["scriptId"]
        else:
            projectInfo = parseFile(configPath)
            if not projectInfo.hasKey("scriptId"):
                quit("No scriptId found in nasp.json", QuitFailure)
            # For Pull, use rootDir from nasp.json if available
            if projectInfo.hasKey("rootDir"):
                finalRootDir = projectInfo["rootDir"].getStr()
            projectInfo["scriptId"].getStr()
    
    echo (if cmd == Clone: "Cloning" else: "Pulling") & " project..."
    echo "This may take a little while..."
    
    # Fetch project metadata (for title, parentId, etc.)
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
        # Determine type based on whether it has a parent (container-bound or standalone)
        let projectType = if projectMeta.hasKey("parentId"): "containerbound" else: "standalone"
        
        var newProjectInfo = %*{
            "scriptId": scriptId,
            "title": title,
            "type": projectType,
            "projectId": profileCreds.projectId,
            "rootDir": finalRootDir
        }
        
        # Include parentId if it exists (container-bound script)
        if projectMeta.hasKey("parentId"):
            newProjectInfo["parentId"] = projectMeta["parentId"]
        
        # Create the root directory if it doesn't exist
        createDirsFromFilePath(configPath)
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
            filePath = finalRootDir / fileName & fileExt
        
        createDirsFromFilePath(filePath)
        writeFile(filePath, fileSource)
        echo "  " & fileName & fileExt
        inc fileCount
    
    echo ""
    echo (if cmd == Clone: "Cloned" else: "Pulled") & " project successfully!"
    echo "Files: " & $fileCount
    echo "Location: " & finalRootDir

# =============================================================================
# Command Handlers
# =============================================================================

proc handleClone*(params: StringTableRef) =
    ## Handle the clone command
    handleCloneOrPull(params, Clone)

proc handlePull*(params: StringTableRef) =
    ## Handle the pull command
    handleCloneOrPull(params, Pull)

