import std/[httpclient]
import pkg/oauth2 # https://github.com/Niminem/OAuth2

## API: Apps Script API

const 
    BaseUrl = "https://script.googleapis.com"
    Timeout = 60000  # 60 seconds in milliseconds

proc getProject*(scriptId, accessToken: string): Response =
    ## REST Resource: v1.projects
    ## https://developers.google.com/apps-script/api/reference/rest/v1/projects
    ## Method: get
    ## GET /v1/projects/{scriptId}
    ## URL: https://developers.google.com/apps-script/api/reference/rest/v1/projects/get
    ## Gets a script project's metadata (scriptId, title, parentId, etc).
    let client = newHttpClient(timeout = Timeout)
    let url = BaseUrl & "/v1/projects/" & scriptId
    result = client.bearerRequest(url, accessToken, HttpGet)
    client.close()

proc createProject*(accessToken, body: string): Response =
    ## REST Resource: v1.projects
    ## https://developers.google.com/apps-script/api/reference/rest/v1/projects
    ## Method: create
    ## POST /v1/projects
    ## URL: https://developers.google.com/apps-script/api/reference/rest/v1/projects/create
    ## Creates a new, empty script project with no script files and a base manifest file.
    let
        client = newHttpClient(timeout = Timeout)
        url = BaseUrl & "/v1/projects"
    result = client.bearerRequest(url, accessToken, HttpPost,
             extraHeaders= newHttpHeaders({"content-type": "application/json"}),
             body=body)
    client.close()

proc getProjectContent*(scriptId, accessToken: string; versionNumber: int = -1): Response =
    ## REST Resource: v1.projects
    ## https://developers.google.com/apps-script/api/reference/rest/v1/projects
    ## Method: getContent
    ## GET /v1/projects/{scriptId}/content
    ## URL: https://developers.google.com/apps-script/api/reference/rest/v1/projects/getContent
    ## Gets the content of the script project, including the code source and metadata for each script file.
    let client = newHttpClient(timeout = Timeout)
    var url = BaseUrl & "/v1/projects/" & scriptId & "/content"
    if versionNumber != -1: url &= "?versionNumber=" & $versionNumber
    result = client.bearerRequest(url, accessToken, HttpGet)
    client.close()

proc updateProjectContent*(scriptId, accessToken, content: string): Response =
    ## REST Resource: v1.projects
    ## https://developers.google.com/apps-script/api/reference/rest/v1/projects
    ## Method: updateContent
    ## PUT /v1/projects/{scriptId}/content
    ## URL: https://developers.google.com/apps-script/api/reference/rest/v1/projects/updateContent
    ## Updates the content of the specified script project.
    let
        client = newHttpClient(timeout = Timeout)
        url = BaseUrl & "/v1/projects/" & scriptId & "/content"
    result = client.bearerRequest(url, accessToken, HttpPut,
                    extraHeaders= newHttpHeaders({"content-type": "application/json"}),
                    body=content)
    client.close()

proc listDeployments*(scriptId, accessToken: string): Response =
    ## REST Resource: v1.projects.deployments
    ## https://developers.google.com/apps-script/api/reference/rest/v1/projects.deployments
    ## Method: list
    ## GET /v1/projects/{scriptId}/deployments
    ## URL: https://developers.google.com/apps-script/api/reference/rest/v1/projects.deployments/list
    ## Lists the deployments of an Apps Script project.
    ## NOTE: we're skipping the Query parameters for now. we don't need them for Nasp.
    let client = newHttpClient(timeout = Timeout)
    let url = BaseUrl & "/v1/projects/" & scriptId & "/deployments"
    result = client.bearerRequest(url, accessToken, HttpGet)
    client.close()

proc runProjectFunction*(deploymentId, accessToken, functionData: string): Response =
    ## REST Resource: v1.scripts
    ## https://developers.google.com/apps-script/api/reference/rest/v1/scripts
    ## Method: run
    ## POST /v1/scripts/{deploymentId}:run
    ## URL: https://developers.google.com/apps-script/api/reference/rest/v1/scripts/run
    ## Runs a function in an Apps Script project.
    ## NOTE: The path parameter is deploymentId, NOT scriptId
    ## NOTE: we're skipping the Query parameters for now. we don't need them for Nasp.
    let
        client = newHttpClient(timeout = Timeout)
        url = BaseUrl & "/v1/scripts/" & deploymentId & ":run"
    result = client.bearerRequest(url, accessToken, HttpPost,
             extraHeaders = newHttpHeaders({"content-type": "application/json"}),
             body=functionData)
    client.close()