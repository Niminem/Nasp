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
requires "oauth2 >= 0.1.0"