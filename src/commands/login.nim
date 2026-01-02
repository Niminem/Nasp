## Login command for nasp
## Handles OAuth2 authentication and credential storage

import std/[strtabs, json, httpclient, os, times, strutils]
import oauth2
import ../auth/profiles
import ../google_apis/req_scopes

# =============================================================================
# Credential Parsing (from client_secret.json)
# =============================================================================

type
    GcpCredentials = object
        clientId: string
        clientSecret: string
        authUri: string
        tokenUri: string
        projectId: string

proc parseGcpCredentials(filepath: string): GcpCredentials =
    ## Parse Google Cloud Platform credentials from client_secret.json
    if not fileExists(filepath):
        quit("Credentials file not found: " & filepath, 1)
    
    let data = parseFile(filepath)
    let installed = data["installed"]
    
    result.clientId = installed["client_id"].getStr()
    result.clientSecret = installed["client_secret"].getStr()
    result.authUri = installed["auth_uri"].getStr()
    result.tokenUri = installed["token_uri"].getStr()
    result.projectId = installed["project_id"].getStr()

# =============================================================================
# Login Command Handler
# =============================================================================

proc handleLogin*(params: StringTableRef) =
    ## Handle the login command
    ## Required: --creds (path to client_secret.json)
    ## Optional: --profile (defaults to "default"), --scope (repeatable)
    
    # Validate required parameters
    if not params.hasKey("creds"):
        quit("Missing required --creds flag. Usage: nasp login --creds:\"path/to/client_secret.json\"", QuitFailure)
    
    let credsPath = params["creds"]
    let profile = if params.hasKey("profile"): params["profile"] else: DefaultProfileName
    
    # Parse scopes - start with required scopes
    var scopes: seq[string] = @[]
    for scope in RequiredScopes:
        scopes.add(scope)
    
    # Add custom scopes (--scope can be repeated, values are comma-joined)
    if params.hasKey("scope"):
        for scopeVal in params["scope"].split(','):
            let s = scopeVal.strip()
            if s.len > 0 and s notin scopes:
                scopes.add(s)
    
    echo "Logging in to profile: " & profile
    echo "Using credentials from: " & credsPath
    
    # Parse GCP credentials
    let gcpCreds = parseGcpCredentials(credsPath)
    
    # Check if profile already exists
    if profileExists(profile):
        echo "Profile '" & profile & "' already exists. Re-authenticating..."
    
    # Perform OAuth2 authorization code grant
    echo "Opening browser for Google authorization..."
    echo "(If browser doesn't open, check your terminal for the URL)"
    
    let client = newHttpClient()
    defer: client.close()
    
    let response = client.authorizationCodeGrant(
        gcpCreds.authUri,
        gcpCreds.tokenUri,
        gcpCreds.clientId,
        gcpCreds.clientSecret,
        scope = scopes,
        port = 8080
    )
    
    if response.code != Http200:
        quit("Authentication failed. Got:\nCode: " & $response.code & 
             "\nResponse: " & response.body, 1)
    
    # Parse token response
    let tokenData = parseJson(response.body)
    
    # Create profile credentials
    let profileCreds = ProfileCredentials(
        clientId: gcpCreds.clientId,
        clientSecret: gcpCreds.clientSecret,
        projectId: gcpCreds.projectId,
        accessToken: tokenData["access_token"].getStr(),
        refreshToken: tokenData["refresh_token"].getStr(),
        expiresIn: tokenData["expires_in"].getInt(),
        timestamp: $getTime(),
        scopes: scopes
    )
    
    # Save credentials
    saveProfileCredentials(profile, profileCreds)
    echo "Credentials saved to profile: " & profile
    
    # Set as default if it's the first profile or explicitly "default"
    if not hasAnyProfiles() or profile == DefaultProfileName or 
       getDefaultProfile() == DefaultProfileName:
        setDefaultProfile(profile)
        if profile != DefaultProfileName:
            echo "Set '" & profile & "' as default profile."
    
    echo ""
    echo "Login successful!"
    echo "You can now use nasp commands with this profile."
    if profile != DefaultProfileName:
        echo "Use --profile:" & profile & " to use this profile with other commands."

