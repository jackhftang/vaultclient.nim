import testutils
import common
import base, kv

suite "kv":
  var vault: VaultProcess

  setup:
    vault = newVaultProcess()
        
  teardown:
    vault.stop()

  asyncTest "conf":    
    let c = newVaultClient(DEFAULT_VAULT_ADDR, vault.rootToken)
    let kv = c.kv("custom")
    await kv.enable()

    let conf = await kv.conf()
    check: "data" in conf
    check: "cas_required" in conf["data"]
    check: "max_versions" in conf["data"]

  asyncTest "default secret/":
    let c = newVaultClient(DEFAULT_VAULT_ADDR, vault.rootToken)
    let kv = c.kv()

    let data =  %*{
      "a": 1,
      "b": 2,
    }

    # check key not exists
    var keys = await kv.list("foo")
    check: keys.len == 0

    # write and read
    await kv.put("foo/bar", data)
    let ret = await kv.get("foo/bar")
    check: data == ret

    # check key exists
    keys = await kv.list("foo")
    check: keys == @["bar"]

    # delete key and check 
    await kv.destroy("foo/bar")
    keys = await kv.list("foo")
    check: keys.len == 0
    
  asyncTest "custom kv path base/":
    let c = newVaultClient(DEFAULT_VAULT_ADDR, vault.rootToken)
    let kv = c.kv("base")
    await kv.enable()

    let data =  %*{
      "a": 1,
      "b": 2,
    }

    # check key not exists
    var keys = await kv.list("foo")
    require: keys.len == 0

    # write and read
    await kv.put("foo/bar", data)
    let ret = await kv.get("foo/bar")
    require: data == ret

    # check key exists
    keys = await kv.list("foo")
    require: keys == @["bar"]

    # delete key and check 
    await kv.destroy("foo/bar")
    keys = await kv.list("foo")
    require: keys.len == 0

  asyncTest "return nil if key does not exist":
    let path = "some/path/that/is/not/yet/exists"
    let data = %*{"a": 1}
    
    let c = newVaultClient(DEFAULT_VAULT_ADDR, vault.rootToken)
    let kv = c.kv()

    let v0 = await kv.get(path)
    require: v0.isNil
    await kv.put(path, data)
    let v1 = await kv.get(path)
    require: v1 == data
    