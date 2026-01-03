# Package
version       = "0.1.0"
author        = "Niminem"
description   = "Nasp is a CLI tool for developing Apps Script projects on your local machine using the Nim programming language."
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["nasp"]

# Dependencies
requires "nim >= 2.0.0"
requires "https://github.com/Niminem/OAuth2.git" # TODO: replace with nimble package when published