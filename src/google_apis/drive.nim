import std/[httpclient, strutils]
import pkg/oauth2 # https://github.com/Niminem/OAuth2

## API: Drive API

const 
    BaseUrlMetadata = "https://www.googleapis.com/drive/v3/files"
    BaseUrlUpload = "https://www.googleapis.com/upload/drive/v3/files"
    Timeout = 60000  # 60 seconds in milliseconds

proc getDriveFile*(fileId, accessToken: string;
                   queryParams: seq[(string, string)] = @[]): Response =
    ## REST Resource: v3.files
    ## https://developers.google.com/drive/api/reference/rest/v3/files
    ## Method: files.get
    ## GET https://www.googleapis.com/drive/v3/files/{fileId}
    ## URL: https://developers.google.com/workspace/drive/api/reference/rest/v3/files/get
    ## Gets a file's metadata by ID.
    ## 
    ## Parameters:
    ##   - fileId: The ID of the file to get (required)
    ##   - accessToken: OAuth2 access token for authentication
    ##   - queryParams: Sequence of (key, value) tuples for query parameters
    let client = newHttpClient(timeout = Timeout)
    var url = BaseUrlMetadata & "/" & fileId
    if queryParams.len > 0:
        var queryParts: seq[string] = @[]
        for (key, value) in queryParams:
            queryParts.add(key & "=" & value)
        url &= "?" & queryParts.join("&")
    result = client.bearerRequest(url, accessToken, HttpGet)
    client.close()

proc createDriveFile*(accessToken, body: string;
                      queryParams: seq[(string, string)] = @[];
                      isMediaUpload: bool = false): Response =
    ## REST Resource: v3.files
    ## https://developers.google.com/drive/api/reference/rest/v3/files
    ## Method: files.create
    ## POST https://www.googleapis.com/drive/v3/files
    ## URL: https://developers.google.com/workspace/drive/api/reference/rest/v3/files/create
    ## Creates a new file.
    ## 
    ## Parameters:
    ##   - accessToken: OAuth2 access token for authentication
    ##   - body: JSON string containing the file metadata (and optionally file content)
    ##   - queryParams: Sequence of (key, value) tuples for query parameters
    ##   - isMediaUpload: If true, uses the upload endpoint for media uploads.
    ##                    If false, uses the standard endpoint for metadata-only requests.
    ## 


    let client = newHttpClient(timeout = Timeout)
    # Select base URL based on upload type
    let baseUrl = if isMediaUpload: BaseUrlUpload else: BaseUrlMetadata
    # Build URL with query parameters
    var url = baseUrl
    if queryParams.len > 0:
        var queryParts: seq[string] = @[]
        for (key, value) in queryParams:
            queryParts.add(key & "=" & value)
        url &= "?" & queryParts.join("&")
    result = client.bearerRequest(url, accessToken, HttpPost,
             extraHeaders= newHttpHeaders({"content-type": "application/json"}),
             body= body)
    client.close()

proc deleteDriveFile*(fileId, accessToken: string; supportsAllDrives: bool = true): Response =
    ## REST Resource: v3.files
    ## https://developers.google.com/drive/api/reference/rest/v3/files
    ## Method: files.delete
    ## DELETE https://www.googleapis.com/drive/v3/files/{fileId}
    ## URL: https://developers.google.com/workspace/drive/api/reference/rest/v3/files/delete
    ## Permanently deletes a file owned by the user without moving it to the trash.
    ## 
    ## If the file belongs to a shared drive, the user must be an `organizer` on the parent folder.
    ## If the target is a folder, all descendants owned by the user are also deleted.
    ## 
    ## Parameters:
    ##   - fileId: The ID of the file to delete (required)
    ##   - accessToken: OAuth2 access token for authentication
    ##   - supportsAllDrives: Whether the requesting application supports both My Drives and shared drives.
    ##                        Defaults to true. Set to false only if your app doesn't support shared drives.
    ## 
    ## Request body: Must be empty
    ## Response: Empty JSON object if successful
    let client = newHttpClient(timeout = Timeout)
    
    # Build URL with fileId in path and supportsAllDrives query parameter
    var url = BaseUrlMetadata & "/" & fileId & "?supportsAllDrives=" & $supportsAllDrives
    
    # DELETE request with empty body
    result = client.bearerRequest(url, accessToken, HttpDelete)
    client.close()

