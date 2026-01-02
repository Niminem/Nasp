## Logout command for nasp
## Handles profile credential deletion

import std/[strtabs, strutils]
import ../auth/profiles

# =============================================================================
# Logout Command Handler
# =============================================================================

proc handleLogout*(params: StringTableRef) =
    ## Handle the logout command
    ## Optional: --profile (defaults to default profile), --all (logout all profiles)
    
    # Check for --all flag
    if params.hasKey("all"):
        echo "Logging out all profiles..."
        let count = deleteAllProfiles()
        if count > 0:
            echo "Successfully logged out " & $count & " profile(s)."
        else:
            echo "No profiles found to logout."
        return
    
    # Determine which profile to logout
    let profile = if params.hasKey("profile"): 
                      params["profile"] 
                  else: 
                      getDefaultProfile()
    
    # Check if profile exists
    if not profileExists(profile):
        quit("Profile '" & profile & "' does not exist.", 1)
    
    echo "Logging out profile: " & profile
    
    # Delete the profile
    if deleteProfile(profile):
        echo "Successfully logged out profile: " & profile
        
        # Show remaining profiles
        let remaining = listProfiles()
        if remaining.len > 0:
            echo "Remaining profiles: " & remaining.join(", ")
            echo "Default profile is now: " & getDefaultProfile()
        else:
            echo "No profiles remaining. Run 'nasp login' to authenticate."
    else:
        echo "Failed to logout profile: " & profile

