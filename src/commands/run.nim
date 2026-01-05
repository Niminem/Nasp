## Run command for nasp
## Executes an Apps Script function remotely

import std/[strtabs, json, httpclient, os, strutils]
import ../auth/profiles
import ../google_apis/apps_script

# =============================================================================
# Run Command Handler
# =============================================================================

proc handleRun*(params: StringTableRef) =
    ## Execute an Apps Script function remotely via the Apps Script API.
    ## 
    ## Flags:
    ##   --func: string (required) - Name of the function to execute
    ##   --args: string (optional) - JSON array of arguments (e.g., "['arg1', 123, true]")
    ##                               Single quotes are converted to double quotes for shell compatibility
    ##   --deployed: flag (optional) - Run the deployed version instead of dev version
    ##   --profile: string (optional) - Authentication profile (default: current default)
    ## 
    ## Behavior:
    ##   - Requires nasp.json in current directory
    ##   - For dev mode (default): runs the latest saved code (HEAD)
    ##   - For deployed mode (--deployed): runs the most recent versioned API Executable deployment
    ##   - Function must be accessible (not private, properly scoped)
    ## 
    ## Prerequisites (in Apps Script project):
    ##   - appsscript.json must include: "executionApi": { "access": "ANYONE" }
    ##   - For --deployed: must have an API Executable deployment (Deploy > New deployment > API Executable)
    ##   - Required scopes must be listed in appsscript.json
    ## 
    ## Response handling:
    ##   - On success: displays the returned result (if any)
    ##   - On error: displays error details from the API response
    
    # Check for nasp.json
    let configPath = getCurrentDir() / "nasp.json"
    if not fileExists(configPath):
        quit("nasp.json not found in current directory. Run 'nasp create' or 'nasp clone' first.", QuitFailure)
    
    let projectInfo = parseFile(configPath)
    
    # Get required fields
    if not projectInfo.hasKey("scriptId"):
        quit("No scriptId found in nasp.json", QuitFailure)
    
    let scriptId = projectInfo["scriptId"].getStr()
    
    # Validate required --func parameter
    if not params.hasKey("func"):
        quit("Missing required --func flag. Usage: nasp run --func:myFunction", QuitFailure)
    
    let funcName = params["func"]
    
    # Get profile and authenticate
    let profile = if params.hasKey("profile"): params["profile"] else: getDefaultProfile()
    echo "Using profile: " & profile
    
    let accessToken = getValidAccessToken(profile)
    
    # Parse optional arguments
    # Convert single quotes to double quotes for easier command-line usage
    # JSON requires double quotes, but those are hard to escape in shells
    var argsStr = if params.hasKey("args"): params["args"] else: ""
    argsStr = argsStr.replace("'", "\"")
    
    # devMode: true = run most recent saved version (default)
    # devMode: false = run the deployed version
    let devMode = not params.hasKey("deployed")
    
    # For the run API path, we need a deploymentId
    # - Dev mode: scriptId works (uses HEAD deployment implicitly)
    # - Deployed mode: need to fetch the actual API Executable deployment ID
    var deploymentId = scriptId
    
    if not devMode:
        # Fetch deployments to find an API Executable deployment
        echo ""
        echo "Fetching deployments..."
        let deploymentsResponse = listDeployments(scriptId, accessToken)
        
        if deploymentsResponse.code != Http200:
            quit("Failed to fetch deployments.\nCode: " & 
                 $deploymentsResponse.code & "\nResponse: " & deploymentsResponse.body, QuitFailure)
        
        let deploymentsJson = parseJson(deploymentsResponse.body)
        
        if not deploymentsJson.hasKey("deployments") or deploymentsJson["deployments"].len == 0:
            quit("No deployments found for this project.\n" &
                 "Create an API Executable deployment: Deploy > New deployment > API Executable", QuitFailure)
        
        # Find the highest-versioned API Executable deployment (skip HEAD)
        deploymentId = ""
        var highestVersion = -1
        for deployment in deploymentsJson["deployments"]:
            let config = deployment["deploymentConfig"]
            # Skip HEAD deployment (no versionNumber)
            if not config.hasKey("versionNumber") or config["versionNumber"].kind == JNull:
                continue
            
            if deployment.hasKey("entryPoints"):
                for entryPoint in deployment["entryPoints"]:
                    if entryPoint.hasKey("entryPointType") and 
                       entryPoint["entryPointType"].getStr() == "EXECUTION_API":
                        let ver = config["versionNumber"].getInt()
                        if ver > highestVersion:
                            highestVersion = ver
                            deploymentId = deployment["deploymentId"].getStr()
                        break
        
        if deploymentId == "":
            quit("No API Executable deployment found.\n" &
                 "Create one: Deploy > New deployment > API Executable", QuitFailure)
    
    # Build the request body
    var functionData = %*{
        "function": funcName,
        "devMode": devMode
    }
    
    # Parse and add parameters if provided
    if argsStr != "":
        var argsJson: JsonNode
        try:
            argsJson = parseJson(argsStr)
        except JsonParsingError:
            quit("Invalid --args value. Must be a valid JSON array.\n" &
                 "Example: --args:\"['string', 123, true]\"", QuitFailure)
        
        if argsJson.kind != JArray:
            quit("--args must be a JSON array, not " & $argsJson.kind & ".\n" &
                 "Example: --args:\"['string', 123, true]\"", QuitFailure)
        
        functionData["parameters"] = argsJson
    
    # Display what we're running
    echo ""
    echo "Script ID: " & scriptId
    if not devMode:
        echo "Deployment ID: " & deploymentId
    echo "Function: " & funcName
    if argsStr != "":
        echo "Arguments: " & argsStr
    echo "Mode: " & (if devMode: "Development (latest saved)" else: "Deployed")
    echo ""
    echo "Executing function..."
    echo "This may take a little while..."
    
    # Make the API call using deploymentId
    let response = runProjectFunction(deploymentId, accessToken, $functionData)
    
    if response.code != Http200:
        quit("Failed to execute function.\nCode: " & 
             $response.code & "\nResponse: " & response.body, QuitFailure)
    
    # Parse the response
    let responseJson = parseJson(response.body)
    
    # Check for execution errors
    if responseJson.hasKey("error"):
        echo ""
        echo "Function execution failed!"
        if responseJson["error"].hasKey("details"):
            echo "Error details:"
            echo responseJson["error"]["details"].pretty(2)
        else:
            echo "Error:"
            echo responseJson["error"].pretty(2)
        quit(QuitFailure)
    
    # Handle successful execution
    echo ""
    echo "Function executed successfully!"
    
    if responseJson.hasKey("response"):
        let responseInfo = responseJson["response"]
        if responseInfo.hasKey("result"):
            echo ""
            echo "Result:"
            echo responseInfo["result"].pretty(2)
        else:
            echo "(No return value)"
    else:
        echo "(No response data)"

