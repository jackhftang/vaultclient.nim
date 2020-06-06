import base, json, asyncdispatch, os, httpcore

proc is404(fut: Future[JsonNode]): bool =
  if fut.failed:
    let err = fut.readError
    if err of ref VaultClientHttpRequestError:
      let e = cast[ref VaultClientHttpRequestError](err)
      if e.statusCode == Http404:
        return true
    raise err

proc except404(fut: Future[JsonNode]) {.inline.} = 
  # raise if not 404
  discard is404(fut)

type
  VaultKV* = ref object
    client: VaultClient
    path: string

proc kv*(client: VaultClient, mountPoint: string = "/secret"): VaultKV =
  VaultKV( 
    client: client,
    path: mountPoint
  )

proc enable*(kv: VaultKV, options: JsonNode = nil): Future[void] =
  ## NOTE: only version 2 is supported. 
  var opts = if options.isNil: newJObject() else: options
  opts["options"] = if "options" in opts: opts["options"] else: newJObject()
  opts["options"]["version"] = %"2"
  kv.client.secretsEnable(kv.path, "kv", opts)

proc disable*(kv: VaultKV): Future[void] =
  kv.client.secretsDisable(kv.path)

proc conf*(kv: VaultKV): Future[JsonNode] =
  kv.client.read(kv.path / "config")

proc put*(kv: VaultKV, key: string, val: JsonNode): Future[void] {.async.} =
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#create-update-secret
  let fut = kv.client.write(kv.path / "data" / key, %*{
    "data": val
  })
  yield fut
  except404(fut)

proc get*(kv: VaultKV, key: string): Future[JsonNode] {.async.} =
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#read-secret-version
  let res = await kv.client.read(kv.path / "data" / key )
  result = res["data"]["data"]

proc delete*(kv: VaultKV, key: string): Future[void] {.async.} =
  ## Delete latest version of secret.
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#delete-latest-version-of-secret
  yield kv.client.delete(kv.path / "data" / key)

proc destroy*(kv: VaultKV, key: string): Future[void] {.async.} =
  ## Delete metadata and all versions.
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#destroy-secret-versions
  yield kv.client.delete(kv.path / "metadata" / key)

proc list*(kv: VaultKV, path: string): Future[seq[string]] {.async.} =
  ## List keys at path. Return @[] if not keys.
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#list-secrets
  let fut = kv.client.list(kv.path / "metadata" / path)
  yield fut
  if is404(fut): return

  for key in fut.read["data"]["keys"]:
    result.add key.getStr()
    
proc loginAppRole*(client: VaultClient, roleId, secretId: string): Future[void] {.async.} =
  ## Login with approle auth engine. Auto set token. 
  let res = await client.write("auth/approle/login", %*{
    "role_id": roleId,
    "secret_id": secretId
  })
  let token = res["auth"]["client_token"].getStr()
  client.token = token

