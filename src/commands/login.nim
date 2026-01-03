## Login command for nasp
## Handles OAuth2 authentication and credential storage

import std/[strtabs, json, httpclient, os, times, strutils, net]
import pkg/oauth2
import ../auth/profiles
import ../google_apis/req_scopes

# =============================================================================
# Constants
# =============================================================================

const
    DefaultPort = 38462  # Less commonly used port
    GoogleAuthUri = "https://accounts.google.com/o/oauth2/v2/auth"
    GoogleTokenUri = "https://oauth2.googleapis.com/token"
    SuccessHtml = """
<!DOCTYPE html>
<html>
<head>
    <title>Authorization Successful</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: #eee;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: rgba(255, 255, 255, 0.05);
            border-radius: 12px;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        h1 { color: #4ade80; margin: 0 0 16px 0; font-size: 2em; }
        p { margin: 0; opacity: 0.8; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Success!</h1>
        <p>You may now close this window.</p>
    </div>
</body>
</html>
"""

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
    let expandedPath = $expandTilde(filepath)
    if not fileExists(expandedPath):
        quit("Credentials file not found: " & expandedPath, 1)
    
    let data = parseFile(expandedPath)
    let installed = data["installed"]
    
    result.clientId = installed["client_id"].to(string)
    result.clientSecret = installed["client_secret"].to(string)
    result.authUri = installed["auth_uri"].to(string)
    result.tokenUri = installed["token_uri"].to(string)
    result.projectId = installed["project_id"].to(string)

# =============================================================================
# Login Command Handler
# =============================================================================

proc handleLogin*(params: StringTableRef) =
    ## Handle the login command
    ## Required: --creds (path to client_secret.json) for NEW profiles only
    ## Optional: --profile (defaults to "default"), --scope (repeatable), --port (defaults to 38462)
    
    let profile = if params.hasKey("profile"): params["profile"] else: DefaultProfileName
    let isNewProfile = not profileExists(profile)
    
    # For new profiles, creds are required
    if isNewProfile and not params.hasKey("creds"):
        quit("Missing required --creds flag for new profile. Usage: nasp login --creds:\"path/to/client_secret.json\"", QuitFailure)
    
    # Parse port
    let port = if params.hasKey("port"):
        try: parseInt(params["port"])
        except ValueError: quit("Invalid port number: " & params["port"], QuitFailure)
    else: DefaultPort
    
    # Get credentials - either from file or existing profile
    var gcpCreds: GcpCredentials
    if params.hasKey("creds"):
        gcpCreds = parseGcpCredentials(params["creds"])
        echo "Using credentials from: " & params["creds"]
    else:
        # Re-authenticating existing profile - use stored credentials
        let existingCreds = loadProfileCredentials(profile)
        gcpCreds = GcpCredentials(
            clientId: existingCreds.clientId,
            clientSecret: existingCreds.clientSecret,
            projectId: existingCreds.projectId,
            authUri: GoogleAuthUri,
            tokenUri: GoogleTokenUri
        )
        echo "Using credentials from existing profile"
    
    echo "Logging in to profile: " & profile
    
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
    
    if not isNewProfile:
        echo "Profile '" & profile & "' already exists. Re-authenticating..."
    
    # Check if port is available before starting OAuth flow
    try:
        let testSocket = newSocket()
        testSocket.bindAddr(Port(port))
        testSocket.close()
    except OSError:
        quit("Port " & $port & " is already in use. Wait a few seconds or use --port:XXXXX with a different port.", QuitFailure)
    
    # Perform OAuth2 authorization code grant
    echo "Opening browser for Google authorization..."
    
    let client = newHttpClient()
    defer: client.close()
    
    let response = client.authorizationCodeGrant(
        gcpCreds.authUri,
        gcpCreds.tokenUri,
        gcpCreds.clientId,
        gcpCreds.clientSecret,
        html = SuccessHtml,
        scope = scopes,
        port = port
    )
    
    if response.code != Http200:
        quit("Authentication failed. Got:\nCode: " & $response.code & 
             "\nResponse: " & response.body, QuitFailure)
    
    # Parse token response
    let tokenData = parseJson(response.body)
    
    # Create profile credentials
    let profileCreds = ProfileCredentials(
        clientId: gcpCreds.clientId,
        clientSecret: gcpCreds.clientSecret,
        projectId: gcpCreds.projectId,
        accessToken: tokenData["access_token"].to(string),
        refreshToken: tokenData["refresh_token"].to(string),
        expiresIn: tokenData["expires_in"].to(int),
        timestamp: $getTime(),
        scopes: scopes
    )
    
    # Save credentials
    let isFirstProfile = not hasAnyProfiles()  # Check BEFORE saving
    saveProfileCredentials(profile, profileCreds)
    echo "Credentials saved to profile: " & profile
    
    # Set as default if it's the first profile or explicitly "default"
    if isFirstProfile or profile == DefaultProfileName:
        setDefaultProfile(profile)
        if profile != DefaultProfileName:
            echo "Set '" & profile & "' as default profile."
    
    echo ""
    echo "Login successful!"
    echo "You can now use nasp commands with this profile."
    if profile != DefaultProfileName:
        echo "Use --profile:" & profile & " to use this profile with other commands."
