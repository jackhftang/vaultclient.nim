import testutils
import common
import base

suite "base":
  var vault: VaultProcess

  setup:
    vault = newVaultProcess()
        
  teardown:
    vault.stop()

  asyncTest "status":
    let c = newVaultClient(DEFAULT_VAULT_ADDR, vault.rootToken)
    let json = await c.status()
    assert json["initialized"].getBool()
    assert not json["sealed"].getBool()
    assert json["t"].getInt() == 1
    assert json["n"].getInt() == 1
    
  asyncTest "secrets":
    let c = newVaultClient(DEFAULT_VAULT_ADDR, vault.rootToken)
    
    # precondition
    var lis =  await c.secretsList()
    assert "mypath/" notin lis["data"]

    # enable 
    await c.secretsEnable("mypath", "kv")

    # check
    lis =  await c.secretsList()
    assert "mypath/" in lis["data"]
    assert lis["data"]["mypath/"]["type"].getStr() == "kv"

    # disable
    await c.secretsDisable("mypath")

    # check 
    lis =  await c.secretsList()
    assert "mypath/" notin lis["data"]



  # asyncTest "status":
  #   let c = newVaultClient("http://127.0.0.1:8200", "s.XmR8sf9uTdITaBlaXoLW7I3y")
  #   let status = await c.status()

  # asyncTest "approle":
  #   let c = newVaultClient("http://127.0.0.1:8200")
  #   await c.loginAppRole("7a5ff2e7-e458-38df-6c25-e15ddf76a9d8", "807b5519-0799-7e6c-c7a0-8a0382a22c43")
  #   echo c.token
  #   echo await c.read("token/lookup")