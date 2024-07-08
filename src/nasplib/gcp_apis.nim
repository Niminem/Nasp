import std/[httpclient]
import oauth2

const Scopes* = @[
        "https://www.googleapis.com/auth/script.deployments", # Apps Script deployments
        "https://www.googleapis.com/auth/script.projects", # Apps Script management
        "https://www.googleapis.com/auth/script.webapp.deploy", # Apps Script Web Apps (for script.run)
        "https://www.googleapis.com/auth/drive.metadata.readonly", # Drive metadata
        "https://www.googleapis.com/auth/drive.file", # Create Drive files
        "https://www.googleapis.com/auth/service.management", # Cloud Project Service Management API
        "https://www.googleapis.com/auth/logging.read", # StackDriver logs
        "https://www.googleapis.com/auth/userinfo.email", # User email address
        "https://www.googleapis.com/auth/userinfo.profile",
        # Extra scope since service.management doesn't work alone
        "https://www.googleapis.com/auth/cloud-platform"
        ]
const BaseUrl* = "https://script.googleapis.com"

# ------------------------- API: Apps Script API --------------------------------

# REST Resource: v1.projects  ---------------------------------------------------
# https://developers.google.com/apps-script/api/reference/rest/v1/projects

# Method: create
# POST /v1/projects
# Creates a new, empty script project with no script files and a base manifest file.
proc createProject*(accessToken, body: string): Response =
    let
        client = newHttpClient()
        url = BaseUrl & "/v1/projects"
    result = client.bearerRequest(url, accessToken, HttpPost,
             extraHeaders= newHttpHeaders({"content-type": "application/json"}),
             body=body)
    client.close()

# Method: getContent
# GET /v1/projects/{scriptId}/content
# Gets the content of the script project, including the code source and metadata for each script file.
proc getProjectContent*(scriptId, accessToken: string; versionNumber: int = -1): Response =
    let client = newHttpClient()
    var url = BaseUrl & "/v1/projects/" & scriptId & "/content"
    if versionNumber != -1: url &= "?versionNumber=" & $versionNumber
    result = client.bearerRequest(url, accessToken, HttpGet)
    client.close()

# Method: updateContent
# PUT /v1/projects/{scriptId}/content
# Updates the content of the specified script project.
proc updateProjectContent*(scriptId, accessToken, content: string): Response =
    let
        client = newHttpClient()
        url = BaseUrl & "/v1/projects/" & scriptId & "/content"
    result = client.bearerRequest(url, accessToken, HttpPut,
                    extraHeaders= newHttpHeaders({"content-type": "application/json"}),
                    body=content)
    client.close()

# REST Resource: v1.scripts ---------------------------------------------------
# https://developers.google.com/apps-script/api/reference/rest/v1/scripts

# Method: run
# POST /v1/scripts/{scriptId}:run
# Runs a function in an Apps Script project.
proc runProjectFunction*(scriptId, accessToken, functionData: string): Response =
    let
        client = newHttpClient()
        url = BaseUrl & "/v1/scripts/" & scriptId & ":run"
    result = client.bearerRequest(url, accessToken, HttpPost,
             extraHeaders = newHttpHeaders({"content-type": "application/json"}),
             body=functionData)
    client.close()

# ---------------------------------------------------------------------------------


# ------------------------- API: Drive API ----------------------------------------

# REST Resource: v3.files
# https://developers.google.com/drive/api/reference/rest/v3/files

# Method: files.create
# POST https://www.googleapis.com/drive/v3/files
# Creates a new file.
proc createDriveFile*(accessToken, body: string): Response =
    let
        client = newHttpClient()
        url = "https://www.googleapis.com/drive/v3/files"
    result = client.bearerRequest(url, accessToken, HttpPost,
             extraHeaders= newHttpHeaders({"content-type": "application/json"}),
             body= body)

# ---------------------------------------------------------------------------------