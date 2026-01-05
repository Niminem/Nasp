## Push command for nasp
## Pushes local project files to the remote Apps Script project

import std/[strtabs, json, httpclient, os, strutils, osproc]
import ../auth/profiles
import ../google_apis/apps_script

# =============================================================================
# Helper: Check if Nim file should be compiled
# =============================================================================

proc shouldBeCompiled(file: string): bool =
    ## Checks if a Nim file should be compiled.
    ## Returns false if the first line contains "exclude", otherwise true.
    var f = open(file, fmRead)
    defer: f.close()
    if endOfFile(f): return true
    let firstLine = readLine(f)
    result = "exclude" notin firstLine

# =============================================================================
# Helper: Build JS/HTML from Nim files
# =============================================================================

proc buildFromNimFiles(projectDir: string) =
    ## Compiles Nim files to JavaScript (or HTML for *_html.nim files).
    ## Uses Nim's JS backend with optimized flags for Apps Script compatibility.
    ## 
    ## Behavior:
    ##   - Skips files with "exclude" in the first line
    ##   - *.nim -> *.js (SERVER_JS for Apps Script)
    ##   - *_html.nim -> *.html (wrapped in <script> tags for HtmlService)
    
    for relFilePath in walkDirRec(projectDir, relative = true):
        let fullPath = projectDir / relFilePath
        
        # Skip non-nim files
        if ".nim" notin relFilePath: continue
        
        # Skip files marked with "exclude" in first line
        if not shouldBeCompiled(fullPath): continue
        
        echo "  Compiling: " & relFilePath
        
        if "_html.nim" notin fullPath:
            # Build .js file from .nim file
            let
                outputPath = fullPath.replace(".nim", ".js")
                command = "nim js -d:release -d:danger --jsbigint64:off -d:nimStringHash2 --out:" &
                          outputPath & " " & fullPath
                commandOutput = execCmdEx(command)
            if commandOutput.exitCode != 0:
                quit("Failed to compile: " & fullPath & "\n" &
                     "Output:\n" & commandOutput.output, QuitFailure)
        else:
            # Build .html file from *_html.nim file (for HtmlService templates)
            let
                htmlPath = fullPath.replace("_html.nim", ".html")
                command = "nim js -d:release -d:danger --jsbigint64:off -d:nimStringHash2 --out:" &
                          htmlPath & " " & fullPath
                commandOutput = execCmdEx(command)
            if commandOutput.exitCode != 0:
                quit("Failed to compile: " & fullPath & "\n" &
                     "Output:\n" & commandOutput.output, QuitFailure)
            # Wrap the output in <script> tags for HtmlService
            let content = readFile(htmlPath)
            writeFile(htmlPath, "<script>\n" & content & "\n</script>")

# =============================================================================
# Helper: Convert file extension to Apps Script type
# =============================================================================

proc extToFileType(ext: string): string =
    ## Converts file extension to Apps Script file type
    case ext
    of ".js": "SERVER_JS"
    of ".html": "HTML"
    of ".json": "JSON"
    else: ""

# =============================================================================
# Push Command Handler
# =============================================================================

proc handlePush*(params: StringTableRef) =
    ## Push local project files to the remote Apps Script project.
    ## 
    ## Flags:
    ##   --profile: string (optional) - Authentication profile (default: current default)
    ##   --skipBuild: flag (optional) - Skip Nim compilation step
    ## 
    ## Behavior:
    ##   - Requires nasp.json in current directory
    ##   - Compiles Nim files to JS/HTML (unless --skipBuild)
    ##   - Uploads .js, .html, and appsscript.json files to remote project
    ##   - Preserves folder structure (e.g., utils/helpers.js)
    ##   - Completely replaces remote content (files only on remote will be removed)
    ## 
    ## Nim compilation:
    ##   - *.nim files are compiled to *.js
    ##   - *_html.nim files are compiled to *.html (wrapped in <script> tags)
    ##   - Add "exclude" to first line of a .nim file to skip compilation
    ##   - Uses flags: -d:release -d:danger --jsbigint64:off -d:nimStringHash2
    ## 
    ## Supported file types:
    ##   - .js -> SERVER_JS
    ##   - .html -> HTML
    ##   - appsscript.json -> JSON (manifest file, required)
    
    # Check for nasp.json
    let configPath = getCurrentDir() / "nasp.json"
    if not fileExists(configPath):
        quit("nasp.json not found in current directory. Run 'nasp create' or 'nasp clone' first.", QuitFailure)
    
    let projectInfo = parseFile(configPath)
    
    # Get required fields
    if not projectInfo.hasKey("scriptId"):
        quit("No scriptId found in nasp.json", QuitFailure)
    
    let scriptId = projectInfo["scriptId"].getStr()
    
    # Determine root directory
    let rootDir = if projectInfo.hasKey("rootDir"):
        projectInfo["rootDir"].getStr()
    else:
        getCurrentDir()
    
    # Get profile
    let profile = if params.hasKey("profile"): params["profile"] else: getDefaultProfile()
    echo "Using profile: " & profile
    
    # Get valid access token
    let accessToken = getValidAccessToken(profile)
    
    echo "Pushing project..."
    echo "Script ID: " & scriptId
    echo "This may take a little while..."
    
    # Build from Nim files (unless skipped)
    if not params.hasKey("skipBuild"):
        echo "\nCompiling Nim files..."
        buildFromNimFiles(rootDir)
    else:
        echo "\nSkipping Nim compilation (--skipBuild)"
    
    # Prepare request body by collecting all project files
    echo "\nCollecting project files..."
    var requestBody = %*{"files": newJArray()}
    var fileCount = 0
    
    for relFilePath in walkDirRec(rootDir, relative = true):
        let
            fileParts = splitFile(relFilePath)
            fileName = fileParts.name
            fileExt = fileParts.ext
            fullPath = rootDir / relFilePath
            fileSource = readFile(fullPath)
        
        # Determine file type
        let fileType = extToFileType(fileExt)
        
        # Skip unsupported file types
        if fileType == "": continue
        
        # For JSON, only include appsscript.json (the manifest)
        if fileExt == ".json" and fileName != "appsscript": continue
        
        # Build the file name with folder path (use forward slashes for Apps Script)
        let scriptFileName = if fileParts.dir != "":
            (fileParts.dir / fileName).replace("\\", "/")
        else:
            fileName
        
        requestBody["files"].add(%*{
            "name": scriptFileName,
            "type": fileType,
            "source": fileSource
        })
        
        echo "  " & scriptFileName & fileExt
        inc fileCount
    
    if fileCount == 0:
        quit("No files to push. Add .js, .html, or appsscript.json files to the project.", QuitFailure)
    
    # Check for appsscript.json (required manifest)
    var hasManifest = false
    for file in requestBody["files"]:
        if file["name"].getStr() == "appsscript" and file["type"].getStr() == "JSON":
            hasManifest = true
            break
    
    if not hasManifest:
        quit("Missing appsscript.json manifest file. This file is required.", QuitFailure)
    
    # Push to Apps Script API
    echo "\nUploading to Apps Script..."
    let response = updateProjectContent(scriptId, accessToken, $requestBody)
    
    if response.code != Http200:
        quit("Failed to push project.\nCode: " & 
             $response.code & "\nResponse: " & response.body, QuitFailure)
    
    echo ""
    echo "Project pushed successfully!"
    echo "Files: " & $fileCount

