## this file contains the minimum required scopes for the google apis used by nasp projects
## based on Clasp
## TODO: review this list and add/remove scopes as needed

let RequiredScopes* = [
        "https://www.googleapis.com/auth/script.deployments",
        "https://www.googleapis.com/auth/script.projects",
        "https://www.googleapis.com/auth/script.webapp.deploy",
        "https://www.googleapis.com/auth/drive.metadata.readonly",
        "https://www.googleapis.com/auth/drive.file",
        "https://www.googleapis.com/auth/service.management",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
        "https://www.googleapis.com/auth/cloud-platform"
]