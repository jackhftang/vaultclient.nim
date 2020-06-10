import lib/[common, testutils]
import algorithm
import base, entity

suite "approle":
  var vault: VaultProcess

  setup:
    vault = newVaultProcess()
        
  teardown:
    vault.stop()

  asyncTest "create get list put delete":
    let c = newVaultClient(DEFAULT_VAULT_ADDR, vault.rootToken)
    
    let en1 = await c.createEntity("test1", ["policy1", "policy2"])
    let en2 = await c.createEntity("test2", ["policy2", "policy3"])
    let id1 = en1["id"].getStr()
    let id2 = en2["id"].getStr()

    var en = await c.getEntity(id1)
    require en["name"] == %"test1"
    require en["id"] == %id1
    require en["policies"] == %["policy1", "policy2"]

    var ens = await c.listEntityNames()
    require ens.sorted() == @["test1", "test2"]

    ens = await c.listEntityIds()
    require ens.sorted() == @[id1, id2].sorted()

    await c.deleteEntity(id1)

    ens = await c.listEntityNames()
    require ens == @["test2"]
    ens = await c.listEntityIds()
    require ens == @[id2]

    await c.putEntity(id2, %*{
      "name": "test3"
    })
    ens = await c.listEntityNames()
    require ens == @["test3"]
