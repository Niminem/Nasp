## Config command for nasp
## Handles profile configuration and listing

import std/[strtabs, times]
import pkg/oauth2
import ../auth/profiles

# =============================================================================
# Config Command Handler
# =============================================================================

proc formatDuration(seconds: int): string =
    ## Format seconds into a human-readable duration
    if seconds < 60:
        return $seconds & " seconds"
    elif seconds < 3600:
        let mins = seconds div 60
        return $mins & " minute" & (if mins > 1: "s" else: "")
    else:
        let hours = seconds div 3600
        let mins = (seconds mod 3600) div 60
        if mins > 0:
            return $hours & " hour" & (if hours > 1: "s" else: "") & " " & $mins & " min"
        else:
            return $hours & " hour" & (if hours > 1: "s" else: "")

proc showProfileInfo(profile: string) =
    ## Display detailed information about a profile
    if not profileExists(profile):
        quit("Profile '" & profile & "' does not exist.", QuitFailure)
    
    let creds = loadProfileCredentials(profile)
    let tokenInfo = loadTokens(getProfileCredentialsPath(profile))
    let isDefault = getDefaultProfile() == profile
    
    echo "Profile: " & profile & (if isDefault: " (default)" else: "")
    echo "Project ID: " & creds.projectId
    echo "Client ID: " & creds.clientId[0..15] & "..."
    echo ""
    echo "Scopes:"
    for scope in creds.scopes:
        echo "  - " & scope
    echo ""
    
    # Token status
    let expired = isTokenExpired(tokenInfo)
    if expired:
        echo "Token status: Expired (will refresh on next use)"
    else:
        let elapsed = (getTime() - tokenInfo.timestamp).inSeconds.int
        let remaining = tokenInfo.expiresIn - elapsed
        echo "Token status: Valid (expires in " & formatDuration(remaining) & ")"

proc showProfilesList() =
    ## List all available profiles
    let allProfiles = profiles.listProfiles()
    let defaultProfile = getDefaultProfile()
    
    if allProfiles.len == 0:
        echo "No profiles found. Run 'nasp login' to create one."
        return
    
    echo "Profiles:"
    for profile in allProfiles:
        if profile == defaultProfile:
            echo "  * " & profile & " (default)"
        else:
            echo "    " & profile

proc showConfig() =
    ## Show current configuration
    let defaultProfile = getDefaultProfile()
    let configPath = getConfigPath()
    let naspDir = getNaspDir()
    
    echo "Default profile: " & defaultProfile
    echo "Config directory: " & naspDir
    echo "Config file: " & configPath
    
    let allProfiles = profiles.listProfiles()
    echo "Total profiles: " & $allProfiles.len

proc handleConfig*(params: StringTableRef) =
    ## View and manage nasp configuration.
    ## 
    ## Flags:
    ##   (no flags) - Show current config (default profile, config paths, profile count)
    ##   --list: flag - List all profiles with the default marked
    ##   --info: string (optional) - Show detailed profile info (default: current default profile)
    ##   --default: string - Set the default profile
    ## 
    ## Profile info (--info) displays:
    ##   - Profile name and whether it's the default
    ##   - GCP Project ID and Client ID
    ##   - OAuth scopes granted
    ##   - Token status (valid with time remaining, or expired)
    
    # Set default profile
    if params.hasKey("default"):
        let profile = params["default"]
        if not profileExists(profile):
            quit("Profile '" & profile & "' does not exist.", QuitFailure)
        setDefaultProfile(profile)
        echo "Default profile set to: " & profile
        return
    
    # List profiles
    if params.hasKey("list"):
        showProfilesList()
        return
    
    # Show profile info
    if params.hasKey("info"):
        let profile = if params["info"].len > 0: 
            params["info"] 
        else: 
            getDefaultProfile()
        showProfileInfo(profile)
        return
    
    # Default: show current config
    showConfig()

