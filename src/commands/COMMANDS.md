# nasp Commands Reference

Complete reference for all nasp CLI commands.

---

## login

Authenticate with Google OAuth2 and create/update a profile. Must be run before using other commands. Opens a browser for Google authorization.

```bash
nasp login --creds:"path/to/client_secret.json"
nasp login --creds:"path/to/client_secret.json" --profile:myprofile
nasp login --profile:existing_profile   # re-authenticate existing profile
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--creds` | Yes (new profiles) | — | Path to `client_secret.json` from GCP |
| `--profile` | No | `default` | Profile name to create or update |
| `--scope` | No | — | Additional OAuth scopes (comma-separated, can be repeated) |
| `--port` | No | `38462` | Port for OAuth callback server |

**Notes:**
- Required scopes for Apps Script, Drive, and Cloud Platform are automatically included
- The `--scope` flag adds additional scopes on top of the required ones
- The first profile created becomes the default profile
- Existing profiles can re-authenticate without `--creds` (uses stored client credentials)
- If the port is in use, wait a few seconds or specify a different port with `--port`

---

## logout

Delete profile credentials from `~/.nasp/profiles/`.

```bash
nasp logout                      # logout default profile
nasp logout --profile:myprofile  # logout specific profile
nasp logout --all                # logout all profiles
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--profile` | No | current default | Profile to logout |
| `--all` | No | — | Logout all profiles |

**Notes:**
- Deletes the profile directory and all stored credentials
- If the deleted profile was the default, another remaining profile becomes the new default
- After deletion, shows remaining profiles and the current default

---

## config

View and manage configuration.

```bash
nasp config                      # show current config
nasp config --list               # list all profiles
nasp config --info               # show default profile details
nasp config --info:myprofile     # show specific profile details
nasp config --default:myprofile  # set default profile
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| *(none)* | — | — | Show current config (default profile, config paths, profile count) |
| `--list` | No | — | List all profiles (default marked with `*`) |
| `--info` | No | current default | Show detailed profile info |
| `--default` | No | — | Set default profile |

**Profile info (`--info`) displays:**
- Profile name and whether it's the default
- GCP Project ID and Client ID (truncated)
- OAuth scopes granted to the profile
- Token status: valid (with time remaining) or expired (tokens will automatically refresh as needed)

**Note:** Setting a default profile lets you use commands without passing `--profile` every time for a specific profile you want, all commands default to the default profile.

---

## create

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
| `--rootDir` | No | current directory | Directory to store project files (created if doesn't exist) |
| `--parentId` | No | — | Bind to existing document (overrides `--type`) |
| `--profile` | No | current default | Profile to use for authentication |

**Project types for `--type`:**

| Type | Description |
|------|-------------|
| `standalone` | Standalone script (not bound to any document) |
| `docs` | Container-bound to a new Google Doc |
| `sheets` | Container-bound to a new Google Sheet |
| `slides` | Container-bound to a new Google Slides presentation |
| `forms` | Container-bound to a new Google Form |

**Notes:**
- For `docs`, `sheets`, `slides`, `forms`: creates the container document first, then binds the script to it
- Using `--parentId` binds to an existing document instead of creating a new one
- Fails if `nasp.json` already exists in the target directory
- Automatically pulls project files after creation (to get `appsscript.json` manifest)

**nasp.json contents:**

| Field | Description |
|-------|-------------|
| `scriptId` | The Apps Script project ID |
| `title` | Project title |
| `type` | Project type: `standalone`, `docs`, `sheets`, `slides`, `forms`, or `containerbound` |
| `projectId` | GCP project ID from the profile |
| `rootDir` | Directory path for project files |
| `parentId` | Container document ID (only if container-bound) |

---

## clone

Clone an existing Apps Script project by its script ID. Downloads all project files and creates a `nasp.json` config file.

```bash
nasp clone --scriptId:abc123xyz           # clone to current directory
nasp clone --scriptId:abc123xyz --rootDir:./myproject   # clone to specific directory
nasp clone --scriptId:abc123xyz --versionNumber:5       # clone a specific version
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--scriptId` | Yes | — | The Apps Script project ID to clone |
| `--versionNumber` | No | HEAD | Specific version to clone (if not provided, project's HEAD version is returned per Apps Script API) |
| `--rootDir` | No | current directory | Directory to store project files |
| `--profile` | No | current default | Profile to use for authentication |

**Finding the Script ID:**
- Open your Apps Script project in the browser
- Go to Project Settings (gear icon)
- Copy the "Script ID" value

**File Structure:**

Files are saved with their full name as stored in Apps Script. If your project uses folder-like naming on script.google.com, nasp will create matching local directories:

| On script.google.com | Locally |
|----------------------|---------|
| `tests/slides` | `tests/slides.js` |
| `tests/sheets` | `tests/sheets.js` |
| `utils/helpers` | `utils/helpers.js` |

**Notes:**
- Fails if `nasp.json` already exists in the target directory
- The `nasp.json` created has the same structure as create, but `type` will be `standalone` or `containerbound` (the specific container type like docs/sheets cannot be determined from the API)

---

## pull

Pull the latest changes from a remote Apps Script project. Must be run from a directory with `nasp.json`.

```bash
nasp pull                        # pull latest (HEAD) version
nasp pull --versionNumber:3      # pull a specific version
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--versionNumber` | No | HEAD | Specific version to pull (if not provided, project's HEAD version is returned per Apps Script API) |
| `--profile` | No | current default | Profile to use for authentication |

**Notes:**
- Requires `nasp.json` to exist in the current directory (run `clone` first)
- Uses `rootDir` from `nasp.json` to determine where to write files
- Overwrites existing local files with remote content
- Does NOT update `nasp.json` (preserves original config)
- Does NOT delete local files that were removed from the remote project
- Does NOT track or merge changes — simply replaces file contents
- This is simpler than `git pull`; consider using version control separately for your local files

---

## push

Push local project files to the remote Apps Script project. Must be run from a directory with `nasp.json`.

```bash
nasp push                # compile Nim files and push all files
nasp push --skipBuild    # push without compiling Nim files
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--skipBuild` | No | — | Skip Nim compilation step |
| `--profile` | No | current default | Profile to use for authentication |

**Supported file types:**

| Extension | Apps Script Type | Description |
|-----------|------------------|-------------|
| `.js` | SERVER_JS | Server-side JavaScript |
| `.html` | HTML | HTML files (for HtmlService) |
| `appsscript.json` | JSON | Manifest file (required) |

**Nim compilation:**

If you have `.nim` files in your project, nasp will compile them before pushing:
- `*.nim` → `*.js` (server-side code)
- `*_html.nim` → `*.html` (wrapped in `<script>` tags for HtmlService)
- Add `# exclude` to the first line of a `.nim` file to skip compilation

**Notes:**
- Requires `appsscript.json` manifest file (created automatically by Apps Script)
- Completely replaces remote project content with your local files
- Files that exist only on the remote (not in your local project) will be removed
- Preserves folder structure (e.g., `utils/helpers.js` → `utils/helpers` on Apps Script)
- This is simpler than `git push`; there is no merge, just full replacement

---

## open

Open Apps Script and GCP URLs in the browser. Must be run from a directory with `nasp.json`.

```bash
nasp open              # opens Apps Script editor (default)
nasp open --editor     # opens Apps Script editor
nasp open --logs       # opens script executions/logs
nasp open --gcp        # opens GCP project page (find Project Number here)
nasp open --apis       # opens GCP APIs dashboard
nasp open --creds      # opens GCP credentials page
nasp open --container  # opens container doc/sheet/etc (if container-bound)
nasp open --editor --logs  # open multiple URLs at once
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| *(none)* | — | — | Opens Apps Script editor (same as `--editor`) |
| `--editor` | No | — | Open Apps Script editor |
| `--logs` | No | — | Open script executions/logs |
| `--gcp` | No | — | Open GCP project page (shows Project Number, needed for remote apps script execution) |
| `--apis` | No | — | Open GCP APIs dashboard |
| `--creds` | No | — | Open GCP credentials page |
| `--container` | No | — | Open container document (sheets, docs, slides, forms) |

**Notes:**
- Multiple flags can be combined to open several URLs at once
- `--container` only works for projects created with nasp (where the specific container type is known)
- `--container` won't work for cloned container-bound projects (the API doesn't provide the container type). To fix this, manually edit `nasp.json` and change `"type": "containerbound"` to the specific type (`docs`, `sheets`, `slides`, or `forms`)

---

## run

Execute an Apps Script function remotely. Must be run from a directory with `nasp.json`.

```bash
nasp run --func:myFunction                              # run function with no arguments
nasp run --func:myFunction --args:'["arg1", 123]'       # run with arguments (bash/PowerShell)
nasp run --func:myFunction --argsFile:args.json         # run with arguments from file
nasp run --func:myFunction --deployed                   # run deployed version
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--func` | Yes | — | Name of the function to execute |
| `--args` | No | — | JSON array of arguments passed directly on command line |
| `--argsFile` | No | — | Path to JSON file containing arguments array (overrides `--args`) |
| `--deployed` | No | — | Run the most recent versioned deployment instead of dev mode |
| `--profile` | No | current default | Profile to use for authentication |

**Execution modes:**

| Mode | Description |
|------|-------------|
| Development (default) | Runs the most recently saved version of the script (HEAD) |
| Deployed (`--deployed`) | Runs the most recent versioned API Executable deployment |

**Prerequisites:**

Before using `nasp run`, you must configure your Apps Script project:

1. **Link to GCP Project:**
   - Open the project (`nasp open`)
   - Go to **Project Settings** (gear icon)
   - Under "Google Cloud Platform (GCP) Project", click **Change project**
   - Enter your GCP **Project Number** (find it at `nasp open --gcp`)
   - Click **Set project**

2. **Add to `appsscript.json`:**
   ```json
   {
     "executionApi": {
       "access": "ANYONE"
     }
   }
   ```

3. **Deploy as API Executable:**
   - Open the project (`nasp open`)
   - Click **Deploy** > **New deployment**
   - Select type: **API Executable**
   - Click **Deploy**

4. **Ensure scopes are listed** in `appsscript.json` for any APIs your function uses

**Notes:**
- Functions must be public (not nested or private)
- Arguments are passed as a JSON array; each element is one parameter
- Use `--argsFile` for complex arguments to avoid shell escaping issues
- On success, the function's return value is displayed
- On error, detailed error information from Apps Script is shown

**Passing arguments:**

For simple arguments (numbers, booleans), use `--args` directly with double quotes:
```bash
nasp run --func:addNumbers --args:"[5, 3, true]"
```

For arguments containing strings, use `--argsFile` to avoid shell escaping issues:
```bash
# Create args.json with: ["hello", "world", 123]
nasp run --func:myFunction --argsFile:args.json
```

