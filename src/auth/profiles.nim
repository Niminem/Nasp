## Profile management and secure credential storage for nasp
## Handles ~/.nasp/ directory structure and file permissions

import std/[os, json, times, httpclient]
import pkg/oauth2

type
    ProfileCredentials* = object
        clientId*: string
        clientSecret*: string
        projectId*: string
        accessToken*: string
        refreshToken*: string
        expiresIn*: int
        timestamp*: string
        scopes*: seq[string]

const
    NaspDirName = ".nasp"
    ProfilesDirName = "profiles"
    ConfigFileName = "config.json"
    CredentialsFileName = "rc.json"
    DefaultProfileName* = "default"
    GoogleTokenUri* = "https://oauth2.googleapis.com/token"

# =============================================================================
# Directory and Path Helpers
# =============================================================================

proc getNaspDir*(): string =
    ## Returns the path to ~/.nasp/ directory (cross-platform)
    result = getHomeDir() / NaspDirName

proc getProfilesDir*(): string =
    ## Returns the path to ~/.nasp/profiles/ directory
    result = getNaspDir() / ProfilesDirName

proc getProfileDir*(profile: string): string =
    ## Returns the path to ~/.nasp/profiles/{profile}/ directory
    result = getProfilesDir() / profile

proc getProfileCredentialsPath*(profile: string): string =
    ## Returns the path to ~/.nasp/profiles/{profile}/rc.json
    result = getProfileDir(profile) / CredentialsFileName

proc getConfigPath*(): string =
    ## Returns the path to ~/.nasp/config.json
    result = getNaspDir() / ConfigFileName

# =============================================================================
# Secure File Permissions
# =============================================================================

proc setSecurePermissions*(path: string) =
    ## Sets secure file permissions (600 on Unix, default on Windows)
    ## Windows home directories are already user-protected
    when defined(windows):
        discard  # Windows home directory is user-protected by default
    else:
        # Unix: set to owner read/write only (600)
        setFilePermissions(path, {fpUserRead, fpUserWrite})

# =============================================================================
# Profile Existence and Listing
# =============================================================================

proc profileExists*(profile: string): bool =
    ## Check if a profile exists
    let credPath = getProfileCredentialsPath(profile)
    result = fileExists(credPath)

proc listProfiles*(): seq[string] =
    ## List all available profiles
    result = @[]
    let profilesDir = getProfilesDir()
    if dirExists(profilesDir):
        for kind, path in walkDir(profilesDir):
            if kind == pcDir:
                let profileName = path.splitPath().tail
                if fileExists(path / CredentialsFileName):
                    result.add(profileName)

proc hasAnyProfiles*(): bool =
    ## Check if any profiles exist
    result = listProfiles().len > 0

# =============================================================================
# Default Profile Management
# =============================================================================

proc getDefaultProfile*(): string =
    ## Read default profile name from config.json
    ## Returns "default" if config doesn't exist or has no default set
    let configPath = getConfigPath()
    if fileExists(configPath):
        try:
            let config = parseFile(configPath)
            if config.hasKey("defaultProfile"):
                return config["defaultProfile"].getStr()
        except:
            discard
    return DefaultProfileName

proc setDefaultProfile*(profile: string) =
    ## Set the default profile in config.json
    let configPath = getConfigPath()
    var config: JsonNode
    
    # Load existing config or create new
    if fileExists(configPath):
        try:
            config = parseFile(configPath)
        except:
            config = newJObject()
    else:
        config = newJObject()
        # Ensure directory exists
        createDir(getNaspDir())
    
    config["defaultProfile"] = newJString(profile)
    writeFile(configPath, config.pretty(2))

# =============================================================================
# Credential Storage
# =============================================================================

proc saveProfileCredentials*(profile: string, creds: ProfileCredentials) =
    ## Save credentials to ~/.nasp/profiles/{profile}/rc.json with secure permissions
    let profileDir = getProfileDir(profile)
    let credPath = getProfileCredentialsPath(profile)
    
    # Ensure directory structure exists
    createDir(profileDir)
    
    # Use snake_case keys to be compatible with OAuth2 library's token utils
    let data = %*{
        "client_id": creds.clientId,
        "client_secret": creds.clientSecret,
        "project_id": creds.projectId,
        "access_token": creds.accessToken,
        "refresh_token": creds.refreshToken,
        "expires_in": creds.expiresIn,
        "timestamp": creds.timestamp,
        "scopes": creds.scopes
    }
    
    writeFile(credPath, data.pretty(2))
    setSecurePermissions(credPath)

proc loadProfileCredentials*(profile: string): ProfileCredentials =
    ## Load credentials from ~/.nasp/profiles/{profile}/rc.json
    let credPath = getProfileCredentialsPath(profile)
    
    if not fileExists(credPath):
        raise newException(IOError, "Profile '" & profile & "' does not exist. Run 'nasp login' first.")
    
    let data = parseFile(credPath)
    
    result.clientId = data["client_id"].to(string)
    result.clientSecret = data["client_secret"].to(string)
    result.projectId = data["project_id"].to(string)
    result.accessToken = data["access_token"].to(string)
    result.refreshToken = data["refresh_token"].to(string)
    result.expiresIn = data["expires_in"].to(int)
    result.timestamp = data["timestamp"].to(string)
    result.scopes = data["scopes"].to(seq[string])

proc updateProfileTokens*(profile: string, accessToken: string, expiresIn: int, 
                          refreshToken: string = "") =
    ## Update access token (and optionally refresh token) for a profile
    var creds = loadProfileCredentials(profile)
    creds.accessToken = accessToken
    creds.expiresIn = expiresIn
    creds.timestamp = $getTime()
    if refreshToken != "":
        creds.refreshToken = refreshToken
    saveProfileCredentials(profile, creds)

# =============================================================================
# Token Management (uses OAuth2 library utilities)
# =============================================================================

proc getValidAccessToken*(profile: string): string =
    ## Gets a valid access token for the profile, refreshing if needed.
    ## Uses OAuth2 library's loadTokens, isTokenExpired, and refreshToken.
    ## Raises an error if refresh fails (user should re-login).
    let credPath = getProfileCredentialsPath(profile)
    
    if not fileExists(credPath):
        raise newException(IOError, "Profile '" & profile & "' does not exist. Run 'nasp login' first.")
    
    # Use OAuth2's loadTokens to get token info
    let tokenInfo = loadTokens(credPath)
    
    # Use OAuth2's isTokenExpired to check if refresh is needed
    if isTokenExpired(tokenInfo):
        echo "Access token expired. Refreshing..."
        
        # Load full credentials for clientId/clientSecret
        let creds = loadProfileCredentials(profile)
        
        let client = newHttpClient()
        defer: client.close()
        
        # Use OAuth2's refreshToken to get new tokens (include scopes for consistency)
        let response = client.refreshToken(
            GoogleTokenUri,
            creds.clientId,
            creds.clientSecret,
            creds.refreshToken,
            creds.scopes
        )
        
        if response.code == Http200:
            let tokenData = parseJson(response.body)
            let newAccessToken = tokenData["access_token"].to(string)
            let newExpiresIn = tokenData["expires_in"].to(int)
            let newRefreshToken = if tokenData.hasKey("refresh_token"): 
                tokenData["refresh_token"].to(string) 
                else: ""
            
            # Use OAuth2's updateTokens to save new tokens
            updateTokens(credPath, newAccessToken, newExpiresIn, newRefreshToken)
            echo "Access token refreshed."
            return newAccessToken
        else:
            raise newException(IOError, 
                "Token refresh failed. Please run 'nasp login" & 
                (if profile != DefaultProfileName: " --profile:" & profile else: "") & 
                "' to re-authenticate.")
    else:
        return tokenInfo.accessToken

# =============================================================================
# Profile Deletion
# =============================================================================

proc deleteProfile*(profile: string): bool =
    ## Delete a profile directory. Returns true if deleted, false if didn't exist.
    let profileDir = getProfileDir(profile)
    
    if dirExists(profileDir):
        removeDir(profileDir)
        
        # If this was the default profile, clear the default
        if getDefaultProfile() == profile:
            let remaining = listProfiles()
            if remaining.len > 0:
                setDefaultProfile(remaining[0])
            else:
                # No profiles left, remove config file
                let configPath = getConfigPath()
                if fileExists(configPath):
                    removeFile(configPath)
        return true
    return false

proc deleteAllProfiles*(): int =
    ## Delete all profiles. Returns count of deleted profiles.
    var count = 0
    for profile in listProfiles():
        if deleteProfile(profile):
            inc count
    
    # Clean up config
    let configPath = getConfigPath()
    if fileExists(configPath):
        removeFile(configPath)
    
    result = count

