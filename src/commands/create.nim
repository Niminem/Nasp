## Create command for nasp
## Creates a new Apps Script project

import std/[strtabs, json, httpclient, os, strutils]
import ../auth/profiles
import ../google_apis/[apps_script, drive]
import ../utils

# =============================================================================
# Types
# =============================================================================

const ValidTypes = ["standalone", "docs", "sheets", "slides", "forms"]

proc getMimeType(projectType: string): string =
    case projectType
    of "docs": "application/vnd.google-apps.document"
    of "sheets": "application/vnd.google-apps.spreadsheet"
    of "slides": "application/vnd.google-apps.presentation"
    of "forms": "application/vnd.google-apps.form"
    else: ""

proc createParentFile(accessToken, projectType, title: string): string =
    ## Creates a Google Drive file (Doc, Sheet, Slide, Form) to bind the script to
    let mimeType = getMimeType(projectType)
    if mimeType == "":
        quit("Invalid project type for container-bound script: " & projectType, QuitFailure)
    
    let body = %*{"name": title, "mimeType": mimeType}
    let response = createDriveFile(accessToken, $body)
    
    if response.code != Http200:
        quit("Failed to create " & projectType & " file.\nCode: " & 
             $response.code & "\nResponse: " & response.body, QuitFailure)
    
    result = parseJson(response.body)["id"].getStr()

# =============================================================================
# Create Command Handler
# =============================================================================

proc handleCreate*(params: StringTableRef) =
    ## Create a new Apps Script project and save config to nasp.json.
    ## 
    ## Flags:
    ##   --type: string (optional) - Project type: standalone, docs, sheets, slides, forms
    ##                               (default: "standalone")
    ##   --title: string (optional) - Project title (default: directory name)
    ##   --rootDir: string (optional) - Directory for project files (default: current dir)
    ##   --parentId: string (optional) - Bind to existing document (overrides --type)
    ##   --profile: string (optional) - Authentication profile (default: current default)
    ## 
    ## Behavior:
    ##   - Creates the rootDir directory if it doesn't exist
    ##   - Fails if nasp.json already exists in rootDir
    ##   - For docs/sheets/slides/forms, creates the container file first via Drive API
    ##   - Using --parentId binds to an existing document (type becomes "containerbound")
    ##   - Automatically pulls project files after creation (to get appsscript.json manifest)
    ## 
    ## Output (nasp.json):
    ##   - scriptId: The Apps Script project ID
    ##   - title: Project title
    ##   - type: Project type (standalone, docs, sheets, slides, forms, or containerbound)
    ##   - projectId: GCP project ID from the profile
    ##   - rootDir: Directory path
    ##   - parentId: Container document ID (only if container-bound)
    
    # Get profile
    let profile = if params.hasKey("profile"): params["profile"] else: getDefaultProfile()
    echo "Using profile: " & profile
    
    # Load profile credentials (for projectId) and get valid access token
    let profileCreds = loadProfileCredentials(profile)
    let accessToken = getValidAccessToken(profile)
    
    # Determine root directory (where nasp.json will be saved)
    let rootDir = if params.hasKey("rootDir"): 
                      params["rootDir"].absolutePath() 
                  else: 
                      getCurrentDir()

    # Create directory if it doesn't exist
    if not dirExists(rootDir):
        createDir(rootDir)
        echo "Created directory: " & rootDir
    
    # Check if nasp.json already exists
    let configPath = rootDir / "nasp.json"
    if fileExists(configPath):
        quit("nasp.json already exists in " & rootDir & ". Remove it first or use a different directory.", QuitFailure)
    
    # Parse type
    var projectType = if params.hasKey("type"): params["type"].toLowerAscii() else: "standalone"
    
    # parentId overrides type to container-bound
    let parentId = if params.hasKey("parentId"): params["parentId"] else: ""
    if parentId != "":
        projectType = "containerbound"
    
    # Validate type
    if projectType notin ValidTypes and projectType != "containerbound":
        quit("Invalid project type: " & projectType & 
             ". Valid types: " & ValidTypes.join(", "), QuitFailure)
    
    # Determine title (use rootDir name if not specified)
    let title = if params.hasKey("title"): 
                    params["title"] 
                else: 
                    rootDir.splitPath().tail
    
    # Create parent file if needed (for container-bound scripts)
    var finalParentId = parentId
    if projectType in ["docs", "sheets", "slides", "forms"]:
        echo "Creating " & projectType & " file..."
        finalParentId = createParentFile(accessToken, projectType, title)
        echo "Created parent file with ID: " & finalParentId
    
    echo "\nCreating " & projectType & " Apps Script project: " & title
    echo "This may take a little while..."
    
    # Create the Apps Script project
    var body = %*{"title": title}
    if finalParentId != "":
        body["parentId"] = newJString(finalParentId)
    
    let response = createProject(accessToken, $body)
    
    if response.code != Http200:
        quit("Failed to create project.\nCode: " & 
             $response.code & "\nResponse: " & response.body, QuitFailure)
    
    let responseJson = parseJson(response.body)
    let scriptId = responseJson["scriptId"].getStr()
    
    # Save to nasp.json in rootDir
    var projectConfig = %*{
        "scriptId": scriptId,
        "title": title,
        "type": projectType,
        "projectId": profileCreds.projectId,
        "rootDir": rootDir
    }
    if finalParentId != "":
        projectConfig["parentId"] = newJString(finalParentId)
    
    writeFile(configPath, projectConfig.pretty(2))
    
    # Pull project files (to get appsscript.json manifest)
    echo "\nPulling project files..."
    let projectContent = getProjectContent(scriptId, accessToken)
    if projectContent.code != Http200:
        echo "Warning: Failed to pull project files. You may need to run 'nasp pull' manually."
        echo "Code: " & $projectContent.code
    else:
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
        echo "Files: " & $fileCount
    
    echo ""
    echo "Project created successfully!"
    echo "Profile: " & profile
    echo "Script ID: " & scriptId
    echo "Title: " & title
    echo "GCP Project ID: " & profileCreds.projectId
    if finalParentId != "":
        echo "Parent ID: " & finalParentId
    echo "Location: " & rootDir