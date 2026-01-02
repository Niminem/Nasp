## this file contains the minimum required scopes for the google apis used by nasp projects

let RequiredScopes* = [ # TODO: review this list and add/remove scopes as needed
        "https://www.googleapis.com/auth/script.projects", # Apps Script management
        "https://www.googleapis.com/auth/script.webapp.deploy", # Apps Script Web Apps (for script.run)
        "https://www.googleapis.com/auth/drive.file", # Create Drive files
]