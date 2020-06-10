import lib/testutils
import lib/common
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

  asyncTest "auth":
    let c = newVaultClient(DEFAULT_VAULT_ADDR, vault.rootToken)

    let auths = await c.listAuths()
    require: "data" in auths
    
    # token/ is enabled by default
    require: "token/" in auths["data"]
    
    
    # read is same as list
    var conf = await c.getAuthConfig("token/")
    let defaultLeaseTTL = conf["default_lease_ttl"].getInt()
    let maxLeaseTTL = conf["max_lease_ttl"].getInt()

    # update auth config
    await c.putAuthConfig("token/", %*{
      "default_lease_ttl": defaultLeaseTTL div 2,
      "max_lease_ttl": maxLeaseTTL div 2,
    })
    conf = await c.getAuthConfig("token/")
    require: conf["default_lease_ttl"].getInt() == defaultLeaseTTL div 2
    require: conf["max_lease_ttl"].getInt() == maxLeaseTTL div 2


  asyncTest "secrets":
    let c = newVaultClient(DEFAULT_VAULT_ADDR, vault.rootToken)
    
    # precondition
    var lis =  await c.listSecrets()
    assert "mypath/" notin lis["data"]

    # enable 
    await c.enableSecret("mypath", "kv")

    # check
    lis =  await c.listSecrets()
    assert "mypath/" in lis["data"]
    assert lis["data"]["mypath/"]["type"].getStr() == "kv"

    # disable
    await c.disableSecret("mypath")

    # check 
    lis =  await c.listSecrets()
    assert "mypath/" notin lis["data"]

  asyncTest "unseal and seal":
    let c = newVaultClient(DEFAULT_VAULT_ADDR, vault.rootToken)

    let s1 = await c.status()
    require: not s1["sealed"].getBool()

    await c.seal()

    let s2 = await c.status()
    require: s2["sealed"].getBool()

    let s3 = await c.unseal(vault.unsealKey)
    require: not s3["sealed"].getBool() 


  # asyncTest "status":
  #   let c = newVaultClient("http://127.0.0.1:8200", "s.XmR8sf9uTdITaBlaXoLW7I3y")
  #   let status = await c.status()

  # asyncTest "approle":
  #   let c = newVaultClient("http://127.0.0.1:8200")
  #   await c.loginAppRole("7a5ff2e7-e458-38df-6c25-e15ddf76a9d8", "807b5519-0799-7e6c-c7a0-8a0382a22c43")
  #   echo c.token
  #   echo await c.read("token/lookup")