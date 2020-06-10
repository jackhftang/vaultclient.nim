import lib/common
import os
import httpclient

type
  VaultClientError* = object of CatchableError

  VaultClientHttpRequestError* = object of VaultClientError
    requestMethod*: HttpMethod
    requestUri*: Uri
    requestHeaders*: HttpHeaders
    requestBody*: string
    responseCode*: HttpCode
    responseHeaders*: HttpHeaders
    responseBody*: string

  VaultClient* = ref object
    host*: Uri
    token*: string

const DEFAULT_VAULT_ADDR* = "http://127.0.0.1:8200"

proc newVaultClient*(host, token: string): VaultClient =
  ## Create VaultClient
  VaultClient(
    # currently only v1
    host: parseUri(host) / "/v1",
    token: token,
  )

proc newVaultClient*(host: string): VaultClient =
  ## Create VaultClient with token reading from environment variable `VAULT_TOKEN`
  let token = getEnv("VAULT_TOKEN", "")
  VaultClient(
    # currently only v1
    host: parseUri(host) / "/v1",
    token: token,
  )

proc newVaultClient*(): VaultClient =
  ## Create VaultClient with host and token from environment variable `VAULT_ADDR` and `VAULT_TOKEN`
  let host = getEnv("VAULT_ADDR", DEFAULT_VAULT_ADDR)
  let token = getEnv("VAULT_TOKEN", "")
  newVaultClient(host, token)

# -------------------------------------------------------------
# read, list, write and delete

proc req(client: VaultClient, httpMethod: HttpMethod, uri: Uri, headers: HttpHeaders = nil, data: JsonNode = nil): Future[JsonNode] {.async.} =
  let h = if headers.isNil: newHttpHeaders() else: headers
  # required. Otherwise if response payload is empty, httpclient hang
  h["Connection"] = "close" 
  if client.token.len != 0:
    h["X-Vault-Token"] = client.token
  let payload = 
    if data.isNil: "" 
    else: $data
  
  when defined(debugVaultClient):
    echo httpMethod, " ", $uri, " ", h, " ", payload

  let agent = newAsyncHttpClient()
  let res = await agent.request($uri, httpMethod, payload, h)

  when defined(debugVaultClient):
    echo res.code, await res.body

  if not res.code.is2xx:
    var err = newException(VaultClientHttpRequestError, res.status)
    err.requestMethod = httpMethod
    err.requestUri = uri
    err.requestHeaders = h
    err.requestBody = payload
    err.responseCode = res.code
    err.responseHeaders = res.headers
    err.responseBody = await res.body
    raise err
  let body = await res.body
  result = 
    if body.len == 0: newJNull() 
    else: parseJson(body)

proc read*(client: VaultClient, path: string): Future[JsonNode] =
  ## Read data and retrieves secrets
  let uri = client.host / path
  client.req(HttpGet, uri)
  
proc list*(client: VaultClient, path: string): Future[JsonNode] =
  ## List data or secrets
  let uri = client.host / path ? { "list": "true" }
  client.req(HttpGet, uri)
  
proc write*(client: VaultClient, path: string, data: JsonNode = nil): Future[JsonNode] =
  ## Write data, configuration and secrets
  let headers = newHttpHeaders()
  headers["Content-Type"] = "application/json"
  let uri = client.host / path
  client.req(HttpPost, uri, headers, data)

proc delete*(client: VaultClient, path: string): Future[JsonNode] =
  ## Delete secrets and configuration
  let uri = client.host / path
  client.req(HttpDelete, uri)

# -------------------------------------------------------------
# /sys

proc status*(client: VaultClient): Future[JsonNode] =
  ## Print seal and HA status
  client.read("sys/seal-status")

proc seal*(client: VaultClient): Future[void] =
  ## see https://www.vaultproject.io/api-docs/system/seal#seal
  client.write("sys/seal").ignore()

proc unseal*(client: VaultClient, key: string, reset = false, migrate = false): Future[JsonNode] =
  ## see https://www.vaultproject.io/api-docs/system/unseal#sys-unseal
  client.write("sys/unseal", %*{
    "key": key,
    "reset": reset,
    "migrate": migrate
  })

# -------------------------------------------------------------
# vault secrets <subcommand>

proc listSecrets*(client: VaultClient): Future[JsonNode] =
  ## see https://www.vaultproject.io/api-docs/system/mounts#list-mounted-secrets-engines
  client.read("sys/mounts")

proc enableSecret*(client: VaultClient, path, engine: string, options: JsonNode = nil): Future[void] =
  ## see https://www.vaultproject.io/api-docs/system/mounts#enable-secrets-engine
  var payload = %*{
    "type": engine
  }
  if not options.isNil and options.kind == JObject:
    for k, v in options:
      payload[k] = v
  # ignore any error
  client.write("sys/mounts" / path, payload).ignore()
  
proc disableSecret*(client: VaultClient, path: string): Future[void] =
  ## see https://www.vaultproject.io/api-docs/system/mounts#disable-secrets-engine
  client.delete("sys/mounts" / path).ignore()
  
proc tuneSecret*(client: VaultClient, path: string, options: JsonNode): Future[JsonNode] =
  ## see https://www.vaultproject.io/api-docs/system/mounts#tune-mount-configuration
  client.write("sys/mounts" / path / "tune", options)

# -------------------------------------------------------------
# vault auth <subcommand>

proc listAuths*(client: VaultClient): Future[JsonNode] =
  ## see https://www.vaultproject.io/api-docs/auth/approle#list-roles
  client.read("sys/auth")

proc enableAuth*(client: VaultClient, path, authEngine: string, options: JsonNode): Future[void] = 
  ## see https://www.vaultproject.io/api-docs/system/auth#enable-auth-method
  var opt = if options.isNil: newJObject() else: options
  opt["type"] = %authEngine
  client.write("sys/auth" / path, opt).ignore()

proc disableAuth*(client: VaultClient, path: string): Future[void] = 
  ## see https://www.vaultproject.io/api-docs/system/auth#disable-auth-method
  client.delete("sys/auth" / path).ignore()

proc getAuthConfig*(client: VaultClient, path: string): Future[JsonNode] = 
  ## see https://www.vaultproject.io/api-docs/system/auth#read-auth-method-tuning
  client.read("sys/auth" / path / "tune")

proc putAuthConfig*(client: VaultClient, path: string, options: JsonNode): Future[void] =
  ## see https://www.vaultproject.io/api-docs/system/auth#tune-auth-method
  client.write("sys/auth" / path / "tune", options).ignore()