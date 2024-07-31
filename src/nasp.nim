import std/[cmdline, os, httpclient, json, times, parseopt, tables, strutils, osproc, browsers]
import nasplib/[credentials, oauth2, gcp_apis]


type Command = enum
    init, create, clone, pull, push, open, run, scopes, unknown


proc gcpTokenRequest*(credsFilePath: string; localHostPort: int = 8080;
                      scopes: seq[string] = Scopes): Response =
    if not fileExists(credsFilePath): quit("Credentials file not found: " & credsFilePath, 1)
    let
        creds = parseCredentials(credsFilePath)
        client = newHttpClient()
    result = client.authorizationCodeGrant(creds.authUri, creds.tokenUri,
                        creds.clientId, creds.clientSecret, html="",
                        scope=scopes, port=localHostPort)
    client.close()

proc createAccessFile*(credsFilePath: string; localHostPort: int = 8080;
                       scopes: seq[string] = Scopes) =
    let
        response = gcpTokenRequest(credsFilePath, localHostPort, scopes)
        code = response.code
        body = response.body
    if code == Http200:
        var jsonBody = parseJson(body)
        jsonBody["timestamp"] = newJString $getTime()
        writeFile(".access.json", jsonBody.pretty(2))
    else: quit("Failed to get access token. Got:\nCode: " &  $code & "\nResponse: " & body, 1)

proc authenticate(): string =
    echo "Authenticating..."
    if not fileExists("nasp.json"):
        quit("nasp.json not found in current directory. Did you run 'nasp init'?" &
                    "Are you running nasp from the root directory?", 1)
    if not fileExists(".access.json"): quit(".access.json not found in current directory." &
                "Did you run 'nasp init'? Are you running nasp from the root directory?", 1)
    let client = newHttpClient()
    let
        projectInfo = parseFile("nasp.json")
        creds = parseCredentials(projectInfo["creds"].getStr())
    var
        accessInfo = parseFile(".access.json")
        accessToken = accessInfo["access_token"].getStr()
        refreshToken = accessInfo["refresh_token"].getStr()
        timeStamp = parse(accessInfo["timestamp"].getStr(), "yyyy-MM-dd'T'HH:mm:sszzz").toTime()
        expires = accessInfo["expires_in"].getInt() - 60 # 60 seconds before expiration for buffer
    echo "Checking access token..."
    # check if token is expired. if so, refresh it
    if (getTime() - timeStamp).inSeconds >= expires:
        echo "Access token expired. Refreshing..."
        let
            response = client.refreshToken(creds.tokenUri, creds.clientId, creds.clientSecret,
                                           refreshToken, Scopes)
            code = response.code
            body = response.body
        if code == Http200:
            echo "Access token refreshed. Updating .access.json file..."
            # update access_token, expires_in, timestamp variables & .access.json file
            let bodyJson = parseJson(body)
            accessInfo["access_token"] = bodyJson["access_token"]
            accessInfo["expires_in"] = bodyJson["expires_in"]
            accessInfo["timestamp"] = newJString $getTime()
            writeFile(".access.json", accessInfo.pretty(2))
            accessToken = accessInfo["access_token"].getStr()
        elif code == Http401:
            echo "Access token refresh failed. Getting new access and refresh tokens..."
            # refresh token is invalid. get new access token
            createAccessFile(projectInfo["creds"].getStr())
            accessToken = parseFile(".access.json")["access_token"].getStr()
            echo "New access token obtained and saved to .access.json file."
        else:
            # refresh token request failed
            client.close()
            quit("Failed to refresh access token. Got:\nCode: " &  $code & "\nResponse: " & body, 1)
        client.close()
    else: echo "Access token still valid."
    return accessToken

proc fileTypeToExt*(fileType: string): string =
    if fileType == "SERVER_JS": return ".js"
    elif fileType == "HTML": return ".html"
    else: return ".json"

proc paramsToTable(commandLineParams: seq[string]): Table[string, string] =
    for kind, key, val in getopt(commandLineParams):
        if kind == cmdArgument: result["command"] = key
        elif kind == cmdLongOption: result[key] = val
        else: discard

proc createDirsFromFilePath(file: string) =
    let pathHead = file.splitPath().head
    if pathHead != "":
        var
            dirNames = pathHead.split("/")
            dir: string
        for i in 0 .. dirNames.high:
            dir = dir / dirNames[i]
            if not dirExists(dir): createDir(dir)

proc shouldBeCompiled(file: string): bool =
  var f = open(file, fmRead)
  defer: f.close()
  if endOfFile(f): return true
  var firstLine = readLine(f)
  if "exclude" in firstLine: return false
  else: return true

proc buildFromNimFiles(projectDir: string) =
    for relFilePath in walkDirRec(projectDir, relative=true):
        let fullPath = projectDir / relFilePath
        if ".nim" notin relFilePath: continue # skip non-nim files
        if not shouldBeCompiled(fullPath): continue # if nim file contains "#exclude" in 1st line, skip

        if "_html.nim" notin fullPath: # build js file from nim file
            let
                command = "nim js -d:release -d:danger --jsbigint64:off --out:" &
                        fullPath.replace(".nim", ".js") & " " & fullPath
                commandOutput = execCmdEx(command)
            if commandOutput.exitCode != 0:
                quit("Failed to build js file from nim file: " & fullPath & "\n" &
                    "Output:\n" & commandOutput.output, 1)
        else: # build html file from nim file (for use as template in Apps Script HtmlService)
            let
                htmlPath = fullPath.replace("_html.nim", ".html")
                command = "nim js -d:release -d:danger --jsbigint64:off --out:" &
                        htmlPath & " " & fullPath
                commandOutput = execCmdEx(command)
            if commandOutput.exitCode != 0:
                quit("Failed to build html file from nim file: " & fullPath & "\n" &
                    "Output:\n" & commandOutput.output, 1)
            let f = readFile(htmlPath)
            writeFile(htmlPath, "<script>\n" & f & "\n</script>")

proc createParentFile(accessToken, projectType, projectTitle: string): string =
    let
        mimeType = if projectType == "docs": "application/vnd.google-apps.document"
                    elif projectType == "sheets": "application/vnd.google-apps.spreadsheet"
                    elif projectType == "slides": "application/vnd.google-apps.presentation"
                    else: "application/vnd.google-apps.form"
        body = %*{"name": projectTitle, "mimeType": mimeType}
        response = createDriveFile(accessToken, $body)
    if response.code != Http200:
        quit("Failed to create new " & projectType & " file. Got:\nCode: " &
                $response.code & "\nResponse: " & response.body, 1)
    result = parseJson(response.body)["id"].getStr()

proc handleInitCommand(parameters: var Table[string, string]) =
    # allowed flags:
    # --creds: string (required)
    # --projectDir: string (optional)
    # --scopes: stringArray (optional) ex: --scopes: '["https://www.googleapis.com/auth/drive"]'
    echo "Initializing nasp project..."
    if not parameters.hasKey("creds"): quit("No credentials file path provided", 1)
    # creds stuff -> create .access.json file with access & refresh tokens
    var scopes = Scopes
    if parameters.hasKey("scopes"):
        var paramScopes: JsonNode
        try:
            paramScopes = parameters["scopes"].parseJson()
        except JsonParsingError as e:
            raise newException(JsonParsingError, "Json Parsing error for 'scopes' parameter.\n" & e.msg)
        if paramScopes.kind != JArray: quit("Invalid 'scopes' parameter. Got: " & parameters["scopes"], 1)
        for scope in paramScopes.to(seq[string]):
            if scope notin scopes: scopes.add(scope)

    createAccessFile(parameters["creds"], scopes=scopes)
    # directory stuff -> create nasp.json file with project info
    if not parameters.hasKey("projectDir"):
        parameters["projectDir"] = getCurrentDir().relativePath(getCurrentDir())
    if not dirExists(parameters["projectDir"]): createDir(parameters["projectDir"])
    let projectInfo = %*{
        "projectDir": parameters["projectDir"],
        "creds": parameters["creds"],
        "scriptId": "", # will be filled in later via clone command
        "projectId": parseFile(parameters["creds"])["installed"]["project_id"].getStr(), # gcp proj. id
        "scopes": scopes
        }
    writeFile("nasp.json", projectInfo.pretty(2))
    echo "Nasp project initialized successfully."

proc handleCreateCommand(parameters: var Table[string, string]) =
    # allowed flags:
    # --type: string
             # "standalone" (default if this flag not provided)
             # "docs", "sheets", "slides", "forms"
    # --title: string (optional, defaults to projectDir name)
    # --parentId: string (optional, overrides --type flag if provided)
    let accessToken = authenticate()
    var
        projectInfo = parseFile("nasp.json")
        parentId = if parameters.hasKey("parentId"): parameters["parentId"] else: ""
    let
        projectDir = projectInfo["projectDir"].getStr()
        projectType = if parentId != "": "containerbound"
                      elif parameters.hasKey("type"): parameters["type"]
                      else: "standalone"
        projectTitle = if parameters.hasKey("title"):
                            parameters["title"]
                       elif projectDir == ".":
                            getCurrentDir().splitPath().tail
                       else: projectDir.splitPath().tail
    if projectType notin ["containerbound", "standalone", "docs", "sheets", "slides", "forms"]:
        quit("Invalid project type provided. Got: " & projectType, 1)

    echo "Creating " & projectType & " Apps Script project... (this may take a little while)"

    var body = %*{"title": projectTitle}
    if projectType != "standalone" and projectType != "containerbound":
        parentId = createParentFile(accessToken, projectType, projectTitle)
    if parentId != "": body["parentId"] = newJString(parentId)
    let response = createProject(accessToken, $body)
    if response.code != Http200:
        quit("Failed to create project. Got:\nCode: " &
                $response.code & "\nResponse: " & response.body, 1)
    let responseJson = parseJson(response.body)
    projectInfo["scriptId"] = responseJson["scriptId"]
    writeFile("nasp.json", projectInfo.pretty(2))

    echo projectType.capitalizeAscii() & " project '" & projectTitle & "' created successfully."

proc handlePullOrCloneCommand(parameters: var Table[string, string], cmd: Command) =
    # allowed flags:
    # --scriptId: string (required if cmd == clone, optional otherwise)
    # --versionNumber: int (optional)
    # validate parameters
    if cmd == clone:
        if not parameters.hasKey("scriptId"): quit("No scriptId flag provided", 1)
    # authenticate & get access token
    let accessToken = authenticate()
    # clone project by fetching project content
    echo (if cmd == clone: "Cloning " else: "Pulling ") & " project..."
    var projectInfo = parseFile("nasp.json")
    let scriptId = if cmd == clone: parameters["scriptId"] else: projectInfo["scriptId"].getStr()
    if cmd == clone:
        projectInfo["scriptId"] = newJString scriptId
        writeFile("nasp.json", projectInfo.pretty(2))
    echo "Fetching project content..."
    let
        version = if parameters.hasKey("versionNumber"): parameters["versionNumber"].parseInt() else: -1
        projectContent = getProjectContent(scriptId, accessToken, version)
    if projectContent.code != Http200:
        quit("Failed to fetch project content. Got:\nCode: " & 
             $projectContent.code & "\nResponse: " & projectContent.body, 1)
    # create project files & directories
    echo "Creating project files and directories..."
    let
        projectDir = projectInfo["projectDir"].getStr()
        projectContentJson = parseJson(projectContent.body)
    for file in projectContentJson["files"].getElems():
        let
            fileName = file["name"].to(string)
            fileExt = fileTypeToExt(file["type"].to(string))
            fileSource = file["source"].to(string)
        createDirsFromFilePath(projectDir / fileName) # create directories if needed
        writeFile(projectDir / fileName & fileExt, fileSource)
    echo (if cmd == clone: "Cloned " else: "Pulled ") & "project successfully."

proc handlePushCommand() =
    let
        accessToken = authenticate()
        projectInfo = parseFile("nasp.json")
        projectDir = projectInfo["projectDir"].getStr()
        scriptId = projectInfo["scriptId"].getStr()
    echo "Pushing project..."

    # build js from nim files
    echo "Building js files from nim files..."
    buildFromNimFiles(projectDir)

    # preparing request body
    echo "Preparing request body..."
    var requestBody = %*{"files": @[]}
    for file in walkDirRec(projectDir, relative=true):
        let
            fileParts = splitFile(file)
            fileName = fileParts.name
            fileExt = fileParts.ext
            fileSource = readFile(projectDir / file)
        if fileExt == ".js":
            requestBody["files"].add(%*{
                "name": replace(fileParts.dir / fileName, "\\","/"),
                "type": "SERVER_JS",
                "source": fileSource
            })
        elif fileExt == ".html":
            requestBody["files"].add(%*{
                "name": replace(fileParts.dir / fileName, "\\","/"),
                "type": "HTML",
                "source": fileSource
            })
        elif fileExt == ".json":
            if fileName != "appsscript": continue
            requestBody["files"].add(%*{
                "name": replace(fileName, "\\","/"),
                "type": "JSON",
                "source": fileSource
            })
        else: continue

    echo "Updating project content..."
     # push project by updating project content via Apps Script API
    let response = updateProjectContent(scriptId, accessToken, $requestBody)
    if response.code != Http200:
        quit("Failed to update project content. Got:\nCode: " & 
             $response.code & "\nResponse: " & response.body, 1)
    echo "Project pushed successfully."

proc handleOpenCommand(parameters: var Table[string, string]) =
    # allowed flags:
    # --editor (default if no flag provided)
    # --userSettings
    # --gcpApis
    # --gcpCreds
    # --logs

    if not fileExists("nasp.json"):
        quit("nasp.json not found in current directory. Did you run 'nasp init'?" &
                    "Are you running nasp from the root directory?", 1)
    let
        projectInfo = parseFile("nasp.json")
        scriptId = projectInfo["scriptId"].getStr() 
        projectId = projectInfo["projectId"].getStr()
        editorPath = "https://script.google.com/home/projects/" & scriptId & "/edit"
    if projectId == "": quit("No project id found for nasp. Run 'nasp clone --scriptId:<id>' first", 1)

    if parameters.len == 1:
        openDefaultBrowser(editorPath)
        return
    if parameters.hasKey("userSettings"):
        openDefaultBrowser("https://script.google.com/home/usersettings")
    if parameters.hasKey("editor"):
        openDefaultBrowser(editorPath)
    if parameters.hasKey("logs"):
        openDefaultBrowser("https://script.google.com/home/projects/" & scriptId & "/executions")
    if parameters.hasKey("gcpApis"):
        openDefaultBrowser("https://console.developers.google.com/apis/dashboard?project=" & projectId)
    if parameters.hasKey("gcpCreds"):
        openDefaultBrowser("https://console.developers.google.com/apis/credentials?project=" & projectId)


proc handleRunCommand(parameters: var Table[string, string]) =
    # allowed flags:
        # --func: string (required)
        # --args: string (optional) # must be a stringified json array of arguments

    if not parameters.hasKey("func"): quit("No function name provided", 1)
    let
        accessToken = authenticate()
        projectInfo = parseFile("nasp.json")
        scriptId = projectInfo["scriptId"].getStr()
        funcName = parameters["func"]
        args = if parameters.hasKey("args"): parameters["args"] else: ""
    var functionData = %*{"function": funcName, "devMode": true}
    if args != "":
        var argsJson: JsonNode
        try:
            argsJson = parseJson(args)
        except:
            raise newException(JsonParsingError,
                            "Invalid function arguments provided. Must be a stringified json array")
        if argsJson.kind != JArray: quit("Invalid arguments provided. Must be a stringified json array", 1)
        functionData["parameters"] = argsJson

    echo "Running function: '" & funcName & "' with args: " & (if args != "": args else: "N/A") & " ..."
    let response = runProjectFunction(scriptId, accessToken, $functionData)
    if response.code != Http200:
        quit("Failed to run function. Got:\nCode: " & $response.code & "\nResponse: " & response.body, 1)
    let responseJson = parseJson(response.body)
    if responseJson.hasKey("error"):
        echo "Function execution failed. Error details:\n" & responseJson["error"]["details"].pretty(2)
    else:
        let responseInfo = responseJson["response"]
        if responseInfo.hasKey("result"):
            echo "Function executed successfully. Returned result:\n" & responseInfo["result"].pretty(2)
        else:
            echo "Function executed successfully."

proc handleScopesCommand(parameters: var Table[string, string]) =
    # allowed flags:
    # --addScope: string (optional) ex: --add: "https://www.googleapis.com/auth/drive"
    # --addScopes: stringArray (optional) ex: --add: '["https://www.googleapis.com/auth/drive"]'
    # --removeScope: string (optional) ex: --remove: "https://www.googleapis.com/auth/drive"
    # --removeScopes: stringArray (optional) ex: --remove: '["https://www.googleapis.com/auth/drive"]'
    # if no flags provided, it will create a new access file with the current scopes in nasp.json

    echo "Updating scope(s)..."
    if not fileExists("nasp.json"):
        quit("nasp.json not found in current directory. Did you run 'nasp init'?" &
                    "Are you running nasp from the root directory?", 1)

    # add/remove scopes from parameters to nasp.json
    var
        projectInfo = parseFile("nasp.json")
        scopes = projectInfo["scopes"].to(seq[string])
    # adding scopes
    if parameters.hasKey("addScope"):
        let paramScope = parameters["addScope"]
        if paramScope notin scopes: scopes.add(paramScope)
    if parameters.hasKey("addScopes"):
        var paramScopes: JsonNode
        try:
            paramScopes = parameters["addScopes"].parseJson()
        except JsonParsingError as e:
            raise newException(JsonParsingError, "Json Parsing error for 'addScopes' parameter.\n" & e.msg)
        if paramScopes.kind != JArray: quit("Invalid 'addScopes' parameter. Got: " &
                                            parameters["addScopes"], 1)
        for scope in paramScopes.to(seq[string]):
            if scope notin scopes: scopes.add(scope)
    # removing scopes
    if parameters.hasKey("removeScope"):
        var s: seq[string]
        for scope in scopes:
            if scope != parameters["removeScope"]: s.add(scope)
        scopes = s
    if parameters.hasKey("removeScopes"):
        var paramScopes: JsonNode
        try:
            paramScopes = parameters["removeScopes"].parseJson()
        except JsonParsingError as e:
            raise newException(JsonParsingError,
                              "Json Parsing error for 'removeScopes' parameter.\n" & e.msg)
        if paramScopes.kind != JArray: quit("Invalid 'removeScopes' parameter. Got: " &
                                            parameters["removeScopes"], 1)
        for scope in paramScopes.to(seq[string]):
            var s: seq[string]
            for item in scopes.items():
                if item != scope: s.add(item)
            scopes = s
    # update nasp.json with new scopes
    projectInfo["scopes"] = %*scopes
    writeFile("nasp.json", projectInfo.pretty(2))
    echo "Scopes updated successfully in nasp.json.\nReauthenticating..."
    createAccessFile(projectInfo["creds"].getStr(), scopes=scopes)
    echo "Access info updated in .access.json file."



when isMainModule:
    var parameters = paramsToTable(commandLineParams())
    if parameters.len < 1: quit("No command provided", 1)
    let command = parseEnum[Command](parameters["command"])
    case command
    of init: handleInitCommand(parameters)
    of create: handleCreateCommand(parameters)
    of clone, pull: handlePullOrCloneCommand(parameters, command)
    of push: handlePushCommand()
    of open: handleOpenCommand(parameters)
    of run: handleRunCommand(parameters)
    of scopes: handleScopesCommand(parameters)
    of unknown: quit("Invalid command provided.Got: " & parameters["command"], 1)
