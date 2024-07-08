import std/json

type
    Credentials* = object
        clientId*, clientSecret*: string
        authUri*, tokenUri*: string
        projectId*: string

proc parseCredentials*(filepath: string): Credentials =
    let creds = readFile(filepath).parseJson()
    result.clientId = creds["installed"]["client_id"].to(string) # 'to' raises err instead of default val
    result.clientSecret = creds["installed"]["client_secret"].to(string)
    result.authUri = creds["installed"]["auth_uri"].to(string)
    result.tokenUri = creds["installed"]["token_uri"].to(string)
    result.projectId = creds["installed"]["project_id"].to(string)