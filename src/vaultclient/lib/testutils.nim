import common
import macros, osproc, streams

import unittest, asyncdispatch
export unittest, asyncdispatch

macro asyncTest*(name: static[string], code: untyped): untyped = 
  result = quote do:
    test `name`:
      proc doTest {.async.} =
        `code`
      let fut = doTest()
      while not fut.finished:
        poll()
      if fut.failed:
        echo fut.readError.msg
        # do not abort
        check false
      

type
  VaultProcess* = ref object
    process: Process
    unsealKey*: string # -dev has only one unseal key
    rootToken*: string

proc newVaultProcess*(): VaultProcess =
  result.new()
  # vault is required to run test
  result.process = startProcess(
    "vault",
    args=["server", "-dev"],
    options={poUsePath, poStdErrToStdOut}
  )
  var line = newStringOfCap(120).TaintedString
  while true:
    # look for these two lines
    # Unseal Key: 0E/8wGXozd4nYTlJ3JgXoTDwbGsZOW6+0ziwZyU0aUU=
    # Root Token: s.W7qCabnaaWX6R4PAbPakPV37
    if result.process.outputStream.readLine(line):
      if line.startsWith("Unseal Key:"):
        line.removePrefix("Unseal Key:")
        result.unsealKey = line.strip()
      elif line.startsWith("Root Token:"):
        line.removePrefix("Root Token:")
        result.rootToken = line.strip()
        break
    else:
      break

proc stop*(vault: VaultProcess) =
  if vault.process.running:
    vault.process.terminate()
    let code = vault.process.waitForExit()
    assert code == 0
    vault.process.close()