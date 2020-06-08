# vaultclient 

Hashicorp Vault HTTP Client

## Overview

The fundamental four operations of Vault `write`, `read`, `list` and `delete` are provided. Most if not all other high level operations can be built upon these four operations. In particular, high level binding of `kv2` secret engine is available. 

PRs are welcome~

## Usage

```nim
import vaultclient, asyncdispatch, json, strformat

proc main() {.async.} =
  # read VAULT_TOKEN from environment
  let client = newVaultClient("http://127.0.0.1:8200")

  # create an instance of kv secret engine at mys/ecret/
  let kv = client.kv("my/secrets")

  # enable the kv secret engine 
  await kv.enable()

  # get document or default value if not found
  let doc = await kv.get("doc", %*{
    "cnt": 0
  })

  # read json value
  let n = doc["cnt"].getInt()
  echo n

  # update document
  await kv.put("doc", %*{
    "cnt": n + 1
  })
  
  # list documents at /
  let keys = await kv.list()
  echo keys

  for key in keys:
    # destroy key
    await kv.destroy(key)


when isMainModule:
  waitFor main()
```



