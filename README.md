# nasp

> Develop [Apps Script](https://developers.google.com/apps-script/) projects locally using **Nasp** (Nim Apps Script Projects).

Nasp is a CLI tool for developing Apps Script projects on your local machine using the Nim programming language. Inspired by [Clasp](https://github.com/google/clasp), its JavaScript cousin.

---

## Features

**Develop Locally**  
Write and manage your Apps Script projects on your machine. Use source control, collaborate with other developers, and leverage your favorite editor and tools.

**Structure Your Code**  
Nasp automatically handles folder structure conversion between your local filesystem and script.google.com:

| On script.google.com | Locally |
|----------------------|---------|
| `tests/slides` | `tests/slides.js` |
| `tests/sheets` | `tests/sheets.js` |
| `utils/helpers` | `utils/helpers.js` |

When you `push`, nasp flattens your folder structure for Apps Script. When you `pull` or `clone`, it recreates directories based on file names containing `/`.

**Write in Nim, JavaScript, or Both**  
Use JavaScript for straightforward scripts, or write in Nim and let nasp compile to JavaScript automatically. Why Nim? For me:

- Single-file JavaScript output from Nim's `js` backend (Apps Scripts share the same global space anyway)
- `{.exportc.}` pragma for obfuscation (e.g., `{.exportc:"uweroiewt8wweh9w8th".}`)
- Indention > Braces
- Compile-time macros for code generation and deduplication
- Type safety
- Because it's cool (the most important reason)

**Automated Builds**  
When you `push`, nasp walks through your project and compiles all `.nim` files to JavaScript. Use `# exclude` on the first line of the nim file to skip compilation. Files named `*_html.nim` become HTML files with embedded `<script>` tags.

**Run Scripts Remotely**  
Execute your Apps Script functions directly from the command line with `nasp run`.

**Quick Access**  
Open the Apps Script editor, execution logs, or Google Cloud Project dashboard with `nasp open`.

---

## How It Works

Nasp manages Apps Script projects through a `nasp.json` config file that links your local directory to a remote Apps Script project.

### Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Google Cloud                                 │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Google Cloud Project (GCP)                                   │   │
│  │  • OAuth credentials (client_secret.json)                     │   │
│  │  • Apps Script API enabled                                    │   │
│  │  • Drive API enabled                                          │   │
│  │  • Service Usage API enabled                                  │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Apps Script Project                                          │   │
│  │  • scriptId identifies the project                            │   │
│  │  • Code files (.js → SERVER_JS, .html → HTML)                 │   │
│  │  • Manifest (appsscript.json)                                 │   │
│  │  • Optional: bound to Docs/Sheets/Slides/Forms                │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                               ▲
                               │  nasp push / pull / clone / run
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Local Machine                                │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  ~/.nasp/profiles/                                            │   │
│  │  • Profile configs (credentials, tokens, scopes)              │   │
│  │  • Multiple profiles supported                                │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Project Directory                                            │   │
│  │  • nasp.json (project config)                                 │   │
│  │  • appsscript.json (Apps Script manifest)                     │   │
│  │  • *.js, *.html, *.nim files                                  │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Typical Development Flow

1. **Setup (once)**
   - Create a Google Cloud Project
   - Enable Apps Script API, Drive API, and Service Usage API
   - Create OAuth credentials and download `client_secret.json`
   - Run `nasp login --creds:client_secret.json`

2. **Start a Project**
   - `nasp create` — Create a new Apps Script project
   - *or* `nasp clone --scriptId:...` — Clone an existing project

3. **Develop**
   - Edit `.js`, `.html`, or `.nim` files locally
   - `nasp push` — Upload changes (compiles Nim automatically)
   - `nasp pull` — Download remote changes
   - `nasp open` — Open editor/logs in browser

4. **Execute**
   - `nasp run --func:myFunction` — Run functions remotely

---

## Installation

### Install nasp

```bash
# From nimble
nimble install nasp

# Or clone via git
git clone https://github.com/Niminem/Nasp
cd Nasp
nimble install
```

### Setup Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or use an existing one)
3. Enable the following APIs:
   - [Apps Script API](https://console.cloud.google.com/apis/library/script.googleapis.com) — required for all nasp operations
   - [Google Drive API](https://console.cloud.google.com/apis/library/drive.googleapis.com) — required to list scripts and create container-bound scripts
   - [Service Usage API](https://console.cloud.google.com/apis/library/serviceusage.googleapis.com) — required to list/enable/disable APIs (future features)
4. Configure OAuth consent screen:
   - Go to **APIs & Services** > **OAuth consent screen**
   - Select **External** (or Internal if using Google Workspace)
   - Fill in app name, support email, and developer email
   - Add the required scopes (see [`src/google_apis/req_scopes.nim`](src/google_apis/req_scopes.nim)):
     - `script.deployments`, `script.projects`, `script.webapp.deploy`
     - `drive.metadata.readonly`, `drive.file`
     - `service.management`
     - `userinfo.email`, `userinfo.profile`
     - `cloud-platform`
   - Add **Test users**: Add your Google account email(s) that will use nasp
   - Save and continue
5. Create OAuth credentials:
   - Go to **APIs & Services** > **Credentials**
   - Click **Create Credentials** > **OAuth client ID**
   - Select **Desktop app**
   - Download the JSON file (rename to `client_secret.json`)
6. Enable the Apps Script API in your user settings:
   - Go to https://script.google.com/home/usersettings
   - Turn on **Google Apps Script API**

### Authenticate

```bash
nasp login --creds:path/to/client_secret.json
```

This opens a browser for Google authorization and creates your default profile.

---

## Quick Start

### Create a New Project

```bash
mkdir my-script && cd my-script
nasp create --title:"My Script"
```

This creates the Apps Script project, generates `nasp.json`, and pulls the manifest file.

### Clone an Existing Project

```bash
mkdir my-script && cd my-script
nasp clone --scriptId:YOUR_SCRIPT_ID
```

Find the Script ID in the Apps Script editor under **Project Settings** > **Script ID**.

### Push and Pull

```bash
# Edit files locally, then push
nasp push

# Pull remote changes
nasp pull
```

### Run a Function

```bash
# First: link Apps Script project to GCP and deploy as API Executable
# See full prerequisites in COMMANDS.md
nasp run --func:myFunction
nasp run --func:addNumbers --args:"[5, 3]"
```

---

## Commands

| Command | Description |
|---------|-------------|
| `login` | Authenticate with Google and create a profile |
| `logout` | Delete profile credentials |
| `config` | View/manage profiles and configuration |
| `create` | Create a new Apps Script project |
| `clone` | Clone an existing project by script ID |
| `pull` | Download remote project files |
| `push` | Upload local files (with Nim compilation) |
| `open` | Open Apps Script/GCP URLs in browser |
| `run` | Execute a function remotely |

**[→ Full Commands Reference](src/commands/COMMANDS.md)**

---

## Project Files

### nasp.json

Created by `create` or `clone`. Links your local directory to a remote Apps Script project.

```json
{
  "scriptId": "abc123...",
  "title": "My Script",
  "type": "standalone",
  "projectId": "my-gcp-project",
  "rootDir": "."
}
```

| Field | Description |
|-------|-------------|
| `scriptId` | Apps Script project ID |
| `title` | Project title |
| `type` | `standalone`, `docs`, `sheets`, `slides`, `forms`, or `containerbound` |
| `projectId` | GCP project ID from your profile |
| `rootDir` | Directory for project files |
| `parentId` | Container document ID (if container-bound) |

### appsscript.json

The Apps Script manifest file. Defines runtime version, scopes, and other project settings. Pulled from the remote project automatically.

```json
{
  "timeZone": "America/New_York",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8"
}
```

---

## Nim Integration

Nasp compiles Nim files to JavaScript before pushing. This is optional— you can use plain JavaScript if you prefer.

### How It Works

- `*.nim` → `*.js` (server-side code)
- `*_html.nim` → `*.html` (wrapped in `<script>` tags for HtmlService)
- Add `# exclude` on the first line to skip compilation

### Example

```nim
# hello.nim
proc greet(name: string): string {.exportc.} =
  result = "Hello, " & name & "!"
```

After `nasp push`, this becomes `hello.js` on Apps Script with an exported `greet` function.

---

## Tips

- **Use version control**: Nasp's `push`/`pull` are simple overwrites. Use Git for proper change tracking.
- **Multiple profiles**: Use `--profile:name` for different Google accounts or GCP projects.
- **Open shortcuts**: `nasp open --logs` for execution logs, `nasp open --gcp` for the GCP console.
- **Remote execution**: Link project to GCP, deploy as API Executable, then use `nasp run`. See [run command docs](src/commands/COMMANDS.md#run).
- **Complex arguments**: Use `--argsFile:args.json` instead of `--args` for strings or complex data.
