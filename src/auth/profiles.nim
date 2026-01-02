## Profile management and secure credential storage for nasp
## Handles ~/.nasp/ directory structure and file permissions

import std/[os, json, times, strutils]

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
    
    let data = %*{
        "clientId": creds.clientId,
        "clientSecret": creds.clientSecret,
        "projectId": creds.projectId,
        "accessToken": creds.accessToken,
        "refreshToken": creds.refreshToken,
        "expiresIn": creds.expiresIn,
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
    
    result.clientId = data["clientId"].getStr()
    result.clientSecret = data["clientSecret"].getStr()
    result.projectId = data["projectId"].getStr()
    result.accessToken = data["accessToken"].getStr()
    result.refreshToken = data["refreshToken"].getStr()
    result.expiresIn = data["expiresIn"].getInt()
    result.timestamp = data["timestamp"].getStr()
    result.scopes = @[]
    for scope in data["scopes"]:
        result.scopes.add(scope.getStr())

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

