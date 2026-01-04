import std/[cmdline, strtabs, strutils]
import commands/commands
import utils

type Command = enum Login, Logout, Config, Create, Open, Clone, Pull

when isMainModule:
    var parameters = paramsToTable(commandLineParams()) # gives [key]:value for cmdline args
    if parameters.len < 1: quit("No command provided", QuitFailure)
    let commandStr = parameters["command"].capitalizeAscii() # Convert "login" -> "Login"
    let command = parseEnum[Command](commandStr)
    case command
    of Login: handleLogin(parameters)
    of Logout: handleLogout(parameters)
    of Config: handleConfig(parameters)
    of Create: handleCreate(parameters)
    of Open: handleOpen(parameters)
    of Clone: handleClone(parameters)
    of Pull: handlePull(parameters)