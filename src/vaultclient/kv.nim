import lib/common
import base, os, httpcore

proc is404(fut: Future[JsonNode]): bool =
  if fut.failed:
    let err = fut.readError
    if err of ref VaultClientHttpRequestError:
      let e = cast[ref VaultClientHttpRequestError](err)
      if e.responseCode == Http404:
        return true
    raise err

type
  VaultKV* = ref object
    client: VaultClient
    path: string

proc kv*(client: VaultClient, mountPoint: string = "/secret"): VaultKV =
  VaultKV( 
    client: client,
    path: mountPoint
  )

proc enable*(kv: VaultKV, options: JsonNode = nil): Future[void] {.async.} =
  ## NOTE: only version 2 is supported. 
  var opts = if options.isNil: newJObject() else: options
  opts["options"] = if "options" in opts: opts["options"] else: newJObject()
  opts["options"]["version"] = %"2"
  let fut = kv.client.enableSecret(kv.path, "kv", opts)
  yield fut
  if not fut.failed: return
  let err = fut.readError()
  if err of ref VaultClientHttpRequestError:
    let verr = cast[ref VaultClientHttpRequestError](err)
    if verr.responseCode == Http400:
      let j = 
        try: parseJson(verr.responseBody)
        except: raise err
      if "errors" in j:
        let errs = j["errors"]
        if errs.len == 1 and errs[0].getStr().startsWith("path is already in use at"):
          # ignore if already enabled
          return
    raise err
  else:
    raise err

  

proc disable*(kv: VaultKV): Future[void] =
  kv.client.disableSecret(kv.path)

proc conf*(kv: VaultKV): Future[JsonNode] =
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#read-kv-engine-configuration
  kv.client.read(kv.path / "config")

proc conf*(kv: VaultKV, conf: JsonNode): Future[void] =
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#configure-the-kv-engine
  kv.client.write(kv.path / "config", conf).ignore()

proc put*(kv: VaultKV, key: string, val: JsonNode): Future[void] =
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#create-update-secret
  assert val.kind == JObject
  kv.client.write(kv.path / "data" / key, %*{
    "data": val
  }).ignore()

proc delete*(kv: VaultKV, key: string): Future[void] =
  ## Delete latest version of secret.
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#delete-latest-version-of-secret
  kv.client.delete(kv.path / "data" / key).ignore()

proc destroy*(kv: VaultKV, key: string): Future[void] =
  ## Delete metadata and all versions.
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#destroy-secret-versions
  kv.client.delete(kv.path / "metadata" / key).ignore()

proc get*(kv: VaultKV, key: string): Future[JsonNode] {.async.} =
  ## Get value by key. raise VaultClientHttpRequestError if key not found.
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#read-secret-version
  let json = await kv.client.read(kv.path / "data" / key )
  result = json["data"]["data"]

proc get*(kv: VaultKV, key: string, default: JsonNode): Future[JsonNode] {.async.} =
  ## Get value by key. Return default if key not found.
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#read-secret-version
  let fut = kv.client.read(kv.path / "data" / key )
  yield fut
  if is404(fut): 
      result = default
  else:
    result = fut.read["data"]["data"]


proc list*(kv: VaultKV, path: string = "/"): Future[seq[string]] {.async.} =
  ## List keys at path. Return @[] if directory not found.
  ## see https://www.vaultproject.io/api-docs/secret/kv/kv-v2#list-secrets
  let fut = kv.client.list(kv.path / "metadata" / path)
  yield fut
  if is404(fut): 
    return

  for key in fut.read["data"]["keys"]:
    result.add key.getStr()
    


