# NASP Manual Test Guide

## Prerequisites

- `nasp.exe` built and installed (`nimble install`)
- `client_secret.json` from GCP
- Two test user emails in GCP OAuth consent screen

---

## Test Flow

### 1. LOGIN

**Test default profile:**
```bash
nasp login --creds:"path/to/client_secret.json"
```
- Browser opens for OAuth
- Complete login with first test user
- **Expected:** "Login successful!" message, credentials saved

**Test named profile with custom port:**
```bash
nasp login --creds:"path/to/client_secret.json" --profile:testuser2 --port:9999
```
- Complete login with second test user
- **Expected:** OAuth callback uses port 9999, profile "testuser2" created

**Test re-authentication (no --creds needed):**
```bash
nasp login --profile:default
```
- **Expected:** Re-authenticates using stored client credentials

---

### 2. CONFIG

**List profiles:**
```bash
nasp config --list
```
- **Expected:** Both `default` and `testuser2` shown, default marked with `*`

**Show profile info:**
```bash
nasp config --info
nasp config --info:testuser2
```
- **Expected:** Project ID, Client ID, scopes, token status displayed

**Switch default:**
```bash
nasp config --default:testuser2
nasp config
```
- **Expected:** Default profile changed to testuser2

**Reset default:**
```bash
nasp config --default:default
```

---

### 3. CREATE

**Standalone project:**
```bash
mkdir test_standalone
cd test_standalone
nasp create --title:"Test Standalone"
```
- **Expected:** 
  - Project created on Google
  - `nasp.json` created with `"type": "standalone"`
  - `appsscript.json` automatically pulled
  - "Project created successfully!" message

**Container-bound project (sheets):**
```bash
mkdir ../test_sheets
cd ../test_sheets
nasp create --title:"Test Sheets" --type:sheets
```
- **Expected:**
  - Google Sheet created first
  - Script bound to it
  - `nasp.json` has `"type": "sheets"` and `"parentId"`
  - `appsscript.json` automatically pulled

**Create with --rootDir (from parent directory):**
```bash
cd ..
nasp create --title:"Test RootDir" --rootDir:./test_rootdir
```
- **Expected:**
  - `test_rootdir` directory created
  - `nasp.json` and `appsscript.json` inside it

**Create with --profile:**
```bash
nasp create --title:"Test Profile Create" --rootDir:./test_profile_create --profile:testuser2
```
- **Expected:** Project created using testuser2's GCP project

---

### 4. OPEN

From a project directory with `nasp.json`:

```bash
cd test_standalone
nasp open              # Opens Apps Script editor
nasp open --logs       # Opens executions page
nasp open --gcp        # Opens GCP project page (shows Project Number)
nasp open --apis       # Opens GCP APIs dashboard
nasp open --creds      # Opens GCP credentials
```
- **Expected:** Correct URLs open in browser

**Container-specific:**
```bash
cd ../test_sheets
nasp open --container  # Opens the Google Sheet
```
- **Expected:** Google Sheet opens in browser

**Multiple at once:**
```bash
nasp open --editor --logs
```
- **Expected:** Both editor and logs open

---

### 5. SETUP TEST FILES & PUSH

This section tests the full push workflow including Nim compilation.

**Go back to standalone project:**
```
cd test_standalone
```

**Create directory structure:**
```
test_standalone/
├── appsscript.json    (already exists from create)
├── nasp.json          (already exists from create)
├── main.js
├── compile_me.nim
├── excluded.nim
├── utils/
│   ├── format.js
│   └── helpers/
│       └── deep.js
└── api/
    └── fetch.js
```

**Create the following files using your editor:**

`main.js`:
```javascript
function mainEntry() { return 'Hello from main'; }
```

`utils/format.js`:
```javascript
function formatDate(d) { return d.toISOString(); }
```

`utils/helpers/deep.js`:
```javascript
function deepHelper() { return 42; }
```

`api/fetch.js`:
```javascript
function fetchData() { return {}; }
```

`compile_me.nim` (will be compiled to JS):
```nim
proc greetFromNim(): cstring {.exportc.} =
  return "Hello from Nim!"
```

`excluded.nim` (will be skipped due to `# exclude`):
```nim
# exclude
proc thisWontCompile(): cstring {.exportc.} =
  return "This should not appear"
```

**First push - test Nim compilation:**
```bash
nasp push
```
- **Expected:**
  - "Compiling Nim files..." message appears
  - `compile_me.nim` compiled to `compile_me.js`
  - `excluded.nim` skipped (has `# exclude`)
  - All files uploaded successfully
  - "Project pushed successfully!"

**Verify in browser:**
```bash
nasp open
```
- **Expected files on Apps Script:**
  - `main`
  - `utils/format`
  - `utils/helpers/deep`
  - `api/fetch`
  - `compile_me` (compiled from Nim)
  - `appsscript` (manifest)
- **Should NOT exist:** `excluded` (was skipped)

**Push with --skipBuild:**
```bash
nasp push --skipBuild
```
- **Expected:** No "Compiling Nim files..." message, uses existing .js files

**Push with --profile:**
```bash
nasp push --profile:testuser2
```
- **Expected:** Error (testuser2 doesn't own this project) OR success if shared

---

### 6. CREATE VERSIONS IN APPS SCRIPT

This step is done manually in the browser to create version history for pull testing.

**In the Apps Script editor (nasp open):**

1. **Make a change:**
   - Edit `main.js`: change `'Hello from main'` to `'Version 1 content'`
   - Save (Ctrl+S)

2. **Create Version 1:**
   - Click the **Deploy** button (top right) > **New deployment**
   - For "Select type", choose "Web App"
   - **Important:** Before deploying, note this creates a new **version** automatically

3. **Make another change:**
   - Edit `main.js`: change to `'Version 2 content'`
   - Add a new file via the **+** button > **Script**: name it `browser_added`
   - Add content: `function fromBrowser() { return 'added in browser'; }`
   - Save

4. **Create Version 2:**
   - Click **Deploy** > **New deployment** (or manage deployments to create a new version)

5. **Make one more change (HEAD, unsaved as version):**
   - Edit `main.js`: change to `'HEAD content - latest'`
   - Save (but don't create a new deployment/version)

Now you have:
- Version 1: `'Version 1 content'`
- Version 2: `'Version 2 content'` + `browser_added.gs`
- HEAD: `'HEAD content - latest'` + `browser_added.gs` (latest saved, but not versioned)

---

### 7. PULL & VERSION TESTING

**Pull HEAD (latest unsaved):**
```bash
cd ../test_standalone
nasp pull
```
- **Expected:**
  - Files updated from remote
  - `main.js` contains `'HEAD content - latest'`
  - `browser_added.js` downloaded (new file from browser)
  - Local-only files (like `excluded.nim`) still exist

**Pull specific version 1:**
```bash
nasp pull --versionNumber:1
```
- **Expected:**
  - `main.js` contains `'Version 1 content'`
  - `browser_added.js` may or may not exist (wasn't in v1)

**Pull specific version 2:**
```bash
nasp pull --versionNumber:2
```
- **Expected:**
  - `main.js` contains `'Version 2 content'`
  - `browser_added.js` exists

**Pull with --profile:**
```bash
nasp pull --profile:testuser2
```
- **Expected:** Uses testuser2's credentials (may fail if no access)

**Test pull overwrites local changes:**
1. Edit `main.js` locally (add a comment)
2. Run `nasp pull`
3. **Expected:** Local change is overwritten with remote content

**Test pull does NOT delete local-only files:**
1. Verify `excluded.nim` still exists
2. Create a file `localonly.txt` with any content
3. Run `nasp pull`
4. **Expected:** Both `excluded.nim` and `localonly.txt` still exist

---

### 8. CLONE

Get the `scriptId` from `test_standalone/nasp.json` (open the file or use `type test_standalone\nasp.json` on Windows).

**Clone HEAD:**
```bash
cd ..
mkdir test_clone
nasp clone --scriptId:<scriptId> --rootDir:./test_clone
```
- **Expected:**
  - `nasp.json` created with same scriptId
  - All current HEAD files downloaded
  - Directory structure preserved (`utils/format.js`, etc.)

**Verify nasp.json contents:**

Open `test_clone/nasp.json` and check it has: scriptId, title, type, projectId, rootDir

**Clone specific version:**
```bash
nasp clone --scriptId:<scriptId> --rootDir:./test_clone_v1 --versionNumber:1
```
- **Expected:** Files match Version 1 content

**Clone with different profile:**
```bash
nasp clone --scriptId:<scriptId> --rootDir:./test_clone_profile2 --profile:testuser2
```
- **Expected:** Cloned using testuser2's credentials (if permissions are granted)

**Verify cloned project works (push from clone):**
```
cd test_clone
```

Create `clonetest.js`:
```javascript
function cloneTest() { return 'from clone'; }
```

Then push and verify:
```
nasp push
nasp open
```
- **Expected:** `clonetest` file appears in Apps Script editor

---

### 9. RUN

**Prerequisites - Update appsscript.json:**

To execute functions remotely via the API, you must enable the Execution API in the manifest.

1. Open `test_standalone/appsscript.json`
2. Add the `executionApi` block to the existing JSON:
```json
"executionApi": {
  "access": "ANYONE"
}
```

So if your `appsscript.json` looks like:
```json
{
  "timeZone": "America/New_York",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8"
}
```

It should become:
```json
{
  "timeZone": "America/New_York",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "executionApi": {
    "access": "ANYONE"
  }
}
```

**What `executionApi.access` means:**
- `"ANYONE"` - Anyone with valid OAuth credentials can execute functions
- `"MYSELF"` - Only the script owner can execute
- `"DOMAIN"` - Only users in the same Google Workspace domain
3. Push the updated manifest:
```bash
cd test_standalone
nasp push
```

**Link to GCP Project:**

1. Open the project: `nasp open`
2. Click the **Project Settings** (gear icon in left sidebar)
3. Under "Google Cloud Platform (GCP) Project", click **Change project**
4. Enter your GCP **Project Number** (not the Project ID!)
   - Run `nasp open --gcp` to open the GCP project page where you can find the Project Number
   - The Project Number is a numeric ID (e.g., `314053285323`)
   - The `projectId` in nasp.json is the Project ID (e.g., `my-project-123`), which is different
5. Click **Set project**

**Deploy as API Executable:**

1. Click **Deploy** > **New deployment**
2. Select type: **API Executable**
3. Click **Deploy**

**Create a test function for run command:**

Create `runtest.js` with simple functions to test:
```javascript
function helloWorld() {
  return 'Hello from nasp run!';
}

function addNumbers(a, b) {
  return a + b;
}

function greetUser(name) {
  return 'Hello, ' + name + '!';
}
```

Push it:
```bash
nasp push
```

**Run a simple function (no arguments):**
```bash
nasp run --func:helloWorld
```
- **Expected:** 
  - "Function executed successfully!"
  - Result: `"Hello from nasp run!"`

**Run function with number arguments:**
```bash
nasp run --func:addNumbers --args:"[5, 3]"
```
- **Expected:** Result: `8`
- **Note:** Double quotes work on all shells for numbers/booleans

**Run function with string argument (using --argsFile):**

Create a file `args.json`:
```json
["World"]
```

Then run:
```bash
nasp run --func:greetUser --argsFile:args.json
```
- **Expected:** Result: `"Hello, World!"`
- **Note:** `--argsFile` is recommended for string arguments to avoid shell escaping issues

**Note:** For string arguments, always use `--argsFile` to avoid shell escaping issues across different platforms.

**Run deployed version:**
```bash
nasp run --func:helloWorld --deployed
```
- **Expected:** Runs the most recent versioned API Executable deployment (not HEAD). If you saved changes after deploying, this will run the older deployed code, not the latest saved code.

**Run with --profile:**
```bash
nasp run --func:helloWorld --profile:testuser2
```
- **Expected:** Error (testuser2 doesn't own this project) OR success if shared

**Error cases for run:**

Missing --func:
```bash
nasp run
```
- **Expected:** Error "Missing required --func flag"

Invalid --args (not JSON):
```bash
nasp run --func:helloWorld --args:"not json"
```
- **Expected:** Error about invalid JSON

Invalid --args (not an array):
```bash
nasp run --func:helloWorld --args:"123"
```
- **Expected:** Error "--args must be a JSON array"

Invalid --argsFile (file not found):
```bash
nasp run --func:helloWorld --argsFile:nonexistent.json
```
- **Expected:** Error "Arguments file not found"

Non-existent function:
```bash
nasp run --func:doesNotExist
```
- **Expected:** Error from Apps Script about function not found

---

### 10. CREATE WITH --parentId

**Get the parentId from test_sheets:**

Open `test_sheets/nasp.json` and copy the `parentId` value (this is the Google Sheet ID).

**Create bound to existing document:**
```bash
cd ..
nasp create --title:"Bound to Existing" --parentId:<parentId> --rootDir:./test_parentid
```
- **Expected:**
  - New script created and bound to the existing Sheet
  - `nasp.json` has `"type": "containerbound"` and the `parentId`

---

### 11. PUSH EDGE CASES

**Test push replaces remote content:**
```bash
cd test_standalone
```
1. In Apps Script editor, create a file `remotefile.gs`
2. Locally, don't have this file
3. Run `nasp push`
4. **Expected:** `remotefile` is removed from remote (push is full replacement)

**Verify appsscript.json is required:**
```
cd ..
mkdir test_nomanifest
cd test_nomanifest
```

Create `nasp.json`:
```json
{"scriptId":"xxx","title":"test","type":"standalone","projectId":"xxx","rootDir":"."}
```

Create `test.js`:
```javascript
function test() {}
```

Then try to push:
```
nasp push
```
- **Expected:** Error "Missing appsscript.json manifest file"

---

### 12. ERROR CASES

**Clone without scriptId:**
```bash
nasp clone
```
- **Expected:** Error "No --scriptId flag provided"

**Pull without nasp.json:**
```bash
cd ..
nasp pull
```
- **Expected:** Error "nasp.json not found"

**Push without nasp.json:**
```bash
nasp push
```
- **Expected:** Error "nasp.json not found"

**Create where nasp.json exists:**
```bash
cd test_standalone
nasp create
```
- **Expected:** Error "nasp.json already exists"

**Clone where nasp.json exists:**
```bash
nasp clone --scriptId:abc123
```
- **Expected:** Error "nasp.json already exists"

**Invalid profile:**
```bash
nasp push --profile:nonexistent
```
- **Expected:** Error about profile not found

---

### 13. LOGOUT

**Single profile:**
```bash
nasp logout --profile:testuser2
nasp config --list
```
- **Expected:** testuser2 removed, only default remains

**All profiles:**
```bash
nasp logout --all
nasp config --list
```
- **Expected:** "No profiles found"

---

## Cleanup

1. Delete local test directories:
   - `test_standalone`
   - `test_sheets`
   - `test_rootdir`
   - `test_profile_create`
   - `test_clone`
   - `test_clone_v1`
   - `test_clone_profile2`
   - `test_parentid`
   - `test_nomanifest`

2. Delete test projects from https://script.google.com/home

3. Delete test Google Sheets/Docs from https://drive.google.com

---

## Test Summary Checklist

| Command | Arguments Tested |
|---------|------------------|
| login | `--creds`, `--profile`, `--port`, re-auth |
| logout | `--profile`, `--all` |
| config | `--list`, `--info`, `--info:name`, `--default` |
| create | `--title`, `--type`, `--rootDir`, `--parentId`, `--profile` |
| clone | `--scriptId`, `--rootDir`, `--versionNumber`, `--profile` |
| pull | `--versionNumber`, `--profile`, HEAD |
| push | `--skipBuild`, `--profile`, Nim compilation |
| run | `--func`, `--args`, `--argsFile`, `--deployed`, `--profile` |
| open | `--editor`, `--logs`, `--gcp`, `--apis`, `--creds`, `--container`, multiple |
