import std/[httpclient]
import pkg/oauth2 # https://github.com/Niminem/OAuth2

## API: Apps Script API

const BaseUrl = "https://script.googleapis.com"

proc createProject*(accessToken, body: string): Response =
    ## REST Resource: v1.projects
    ## https://developers.google.com/apps-script/api/reference/rest/v1/projects
    ## Method: create
    ## POST /v1/projects
    ## URL: https://developers.google.com/apps-script/api/reference/rest/v1/projects/create
    ## Creates a new, empty script project with no script files and a base manifest file.
    let
        client = newHttpClient()
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
    let client = newHttpClient()
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
        client = newHttpClient()
        url = BaseUrl & "/v1/projects/" & scriptId & "/content"
    result = client.bearerRequest(url, accessToken, HttpPut,
                    extraHeaders= newHttpHeaders({"content-type": "application/json"}),
                    body=content)
    client.close()

proc runProjectFunction*(scriptId, accessToken, functionData: string): Response =
    ## REST Resource: v1.scripts
    ## https://developers.google.com/apps-script/api/reference/rest/v1/scripts
    ## Method: run
    ## POST /v1/scripts/{scriptId}:run
    ## URL: https://developers.google.com/apps-script/api/reference/rest/v1/scripts/run
    ## Runs a function in an Apps Script project.
    let
        client = newHttpClient()
        url = BaseUrl & "/v1/scripts/" & scriptId & ":run"
    result = client.bearerRequest(url, accessToken, HttpPost,
             extraHeaders = newHttpHeaders({"content-type": "application/json"}),
             body=functionData)
    client.close()