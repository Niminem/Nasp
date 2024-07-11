# Nasp

> Develop [Apps Script](https://developers.google.com/apps-script/) projects locally using Nasp (Nim Apps Script Projects).

Nasp is an API wrapper and CLI tool for developing Apps Script projects on your local machine using the Nim programming language.


<!-- :) -->

Nasp is inspired by [Clasp](https://github.com/google/clasp), its JavaScript cousin.

----------------------

## Features
**Develop Locally**: `nasp` allows you to develop your Apps Script projects locally. Leverage source control, collaborate with other developers, and use your favorite tools to develop Apps Script.

**Structure Code**: `nasp` automatically converts your flat project on script.google.com into folders on your machine. For example:

- On script.google.com:
  - tests/slides.gs
  - tests/sheets.gs
- locally:
  - tests/
    - slides.js
    - sheets.js

The reverse is true as well. `nasp` will consider your file struture and flatten it for script.google.com.

**Write Apps Script in Nim / JavaScript / Both**: Write your Apps Script projects using Nim, good ol'-fashioned JavaScript, or both. Why would we even want to use Nim for this? For me:

- Single-file JavaScript from Nim's `js` backend. Helps with obfuscation. Apps Scripts share the same global space anyway, so effectively the same thing.
- `{.exportc.}` pragma can be given strings, like `{.exportc:"laksdglasdvaneg".}` and further improves obfuscation.
- Indentation > curly braces (readability)
- Code generation and code deduplication via compile-time `macros`
- Type safety
- Because it's cool (most important reason)


**Automated Builds**: When you 'push' your local project files to script.google.com, `nasp` will walk through your project folder recursively and compile all *included* Nim modules. You can *exclude* a Nim module by placing `# exclude` on the first line.

**Run Apps Script remotely**: Execute your Apps Script's functions remotely from the command line.

**Ease of Development**: Open your Apps Script editor, execution logs, or Google Cloud Project dashboard with a simple command.


----------------------

## Installation

1. Install from nimble: `nimble install nasp` or clone via git: `git clone https://github.com/Niminem/Nasp`
2. Enable the Google Apps Script API: https://script.google.com/home/usersettings
3. Setup Google Cloud Project (GCP):

- Create new Google Cloud Project
- Add/Enable Apps Script API, and Drive API
- Create credentials (desktop)

### Get started
1. Create a new project folder
2. Download client_secret_stuff.json file from GCP, placing it into the root of your project folder
3. Create a new folder for your apps script and nim files (optional, defaults to root)
4. run `nasp init --creds:"path-to-client-secret.json`, and include other necessary flags (refer below)

You're now ready to 

----------------------

## Usage

----------------------

## CLI

### Commands

- [`a command that is also a link`](#)

----------------------

### Reference

----------------------

<!-- 1. nimble install nasp
2. enable the Google Apps Script API: https://script.google.com/home/usersettings -->


TODO:
- add documentation for setting up GCP project. Nasp has to have certain APIs enabled for default scopes, such as google drive and google script APIs (I think that's it actually... need to test). Test with new GCP project, and learn the setup, then make unlisted YouTube video for demonstration.