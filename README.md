# nasp

CLI tool for Google Apps Script projects.

## Installation

1. Install from nimble: `nimble install nasp` (when published) / `nimble install https://github.com/Niminem/Nasp.git` or clone via git: `git clone https://github.com/Niminem/Nasp`
2. Enable the Google Apps Script API: https://script.google.com/home/usersettings
3. Setup Google Cloud Project (GCP):
   - Create a new Google Cloud Project
   - Enable the Apps Script API and Drive API
   - Create OAuth credentials (Desktop app)
   - Download `client_secret.json`
   - TODO: **FINISH ME**
4. TODO: **FINISH ME**

## Commands

### login

Authenticate with Google OAuth2 and create/update a profile. Must be run before using other commands.

```bash
nasp login --creds:"path/to/client_secret.json"
nasp login --creds:"path/to/client_secret.json" --profile:myprofile
nasp login --profile:existing_profile   # re-authenticate existing profile
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--creds` | Yes (new profiles) | — | Path to `client_secret.json` from GCP |
| `--profile` | No | `default` | Profile name to create or update |
| `--scope` | No | — | Additional OAuth scopes (repeatable, comma-separated) |
| `--port` | No | `38462` | Port for OAuth callback server |

---

### logout

Delete profile credentials.

```bash
nasp logout                      # logout default profile
nasp logout --profile:myprofile  # logout specific profile
nasp logout --all                # logout all profiles
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--profile` | No | default profile | Profile to logout |
| `--all` | No | — | Logout all profiles |

---

### config

View and manage configuration.

Note: setting a default profile lets you use commands without passing `--profile` every time.

```bash
nasp config                      # show current config
nasp config --list               # list all profiles
nasp config --info               # show default profile details
nasp config --info:myprofile     # show specific profile details
nasp config --default:myprofile  # set default profile
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--list` | No | — | List all profiles |
| `--info` | No | default profile | Show profile details |
| `--default` | No | — | Set default profile |

---

### create

Create a new Apps Script project. Creates a `nasp.json` config file in the project directory.

```bash
nasp create                              # standalone project, uses directory name as title
nasp create --title:"My Project"         # standalone with custom title
nasp create --type:sheets                # container-bound to a new Google Sheet
nasp create --parentId:abc123            # bind to existing document
nasp create --rootDir:./myproject        # create in specific directory
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--type` | No | `standalone` | Project type (see below) |
| `--title` | No | directory name | Project title |
| `--rootDir` | No | current directory | Directory to store project files |
| `--parentId` | No | — | Bind to existing document (overrides --type) |
| `--profile` | No | default profile | Profile to use for authentication |

**Container types for `--type`:**

| Type | Description |
|------|-------------|
| `standalone` | Standalone script (not bound to any document) |
| `docs` | Container-bound to a new Google Doc |
| `sheets` | Container-bound to a new Google Sheet |
| `slides` | Container-bound to a new Google Slides presentation |
| `forms` | Container-bound to a new Google Form |

---

### open

Open Apps Script and GCP URLs in the browser. Must be run from a directory with `nasp.json`.

```bash
nasp open              # opens Apps Script editor (default)
nasp open --editor     # opens Apps Script editor
nasp open --logs       # opens script executions/logs
nasp open --apis       # opens GCP APIs dashboard
nasp open --creds      # opens GCP credentials page
nasp open --container  # opens container doc/sheet/etc (if container-bound)
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| *(none)* | — | — | Opens Apps Script editor (same as `--editor`) |
| `--editor` | No | — | Open Apps Script editor |
| `--logs` | No | — | Open script executions/logs |
| `--apis` | No | — | Open GCP APIs dashboard |
| `--creds` | No | — | Open GCP credentials page |
| `--container` | No | — | Open container document (sheets, docs, slides, forms) |

