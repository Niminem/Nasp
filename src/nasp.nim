import std/[cmdline, strtabs, strutils]
import google_apis/apis
import commands/commands
import utils # paramsToTable

type Command = enum Login, Logout # TODO: add more commands


when isMainModule:
    var parameters = paramsToTable(commandLineParams()) # gives [key]:value for cmdline args
    if parameters.len < 1: quit("No command provided", QuitFailure)
    let command = parseEnum[Command](parameters["command"])
    case command
    of Login: handleLogin(parameters)
    of Logout: handleLogout(parameters)

# TODO NEXT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Good idea! Here's what we should do:
# 1. First, compile to check for errors
# nimble build
# or
# nim c src/nasp.nim
# This will catch any compile-time issues (missing imports, type mismatches, etc.).
# 2. Test the login flow
# You'll need a client_secret.json file from GCP. Then:
# ./nasp login --creds:"path/to/client_secret.json"
# This should:
# Open your browser for Google OAuth
# After authorization, save credentials to ~/.nasp/profiles/default/rc.json
# Print success message
# 3. Verify the profile was created
# Check that ~/.nasp/profiles/default/rc.json exists and has the expected structure.
# 4. Test logout
# ./nasp logout
# This should delete the profile and print a confirmation.
# Potential issues to watch for:
# OAuth2 library import path issues
# File permission issues on Windows vs Unix
# Any missing exports between modules
# Would you like me to run the compile step first to check for errors? Switch to agent mode and I can do that.


# NOTES:

# Login (creates default profile)
# nasp login --creds:"path/to/client_secret.json"

# # Login with named profile
# nasp login --creds:"path/to/client_secret.json" --profile:work

# # Login with custom scopes (--scope can be repeated)
# # Note: These are added to the default scopes required by nasp
# nasp login --creds:"path/to/client_secret.json" --scope:"https://www.googleapis.com/auth/drive"
# nasp login --creds:"path/to/client_secret.json" --scope:"scope1" --scope:"scope2"

# # Logout default profile
# nasp logout

# # Logout specific profile
# nasp logout --profile:work

# # Logout all profiles
# nasp logout --all