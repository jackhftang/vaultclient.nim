import lib/common, base, asyncdispatch

## see https://www.vaultproject.io/api-docs/auth/approle#list-roles
## see https://www.vaultproject.io/api-docs/auth/approle#create-update-approle
## see https://www.vaultproject.io/api-docs/auth/approle#read-approle
## see https://www.vaultproject.io/api-docs/auth/approle#delete-approle
## see https://www.vaultproject.io/api-docs/auth/approle#read-approle-role-id
## see https://www.vaultproject.io/api-docs/auth/approle#update-approle-role-id
## see https://www.vaultproject.io/api-docs/auth/approle#generate-new-secret-id
## see https://www.vaultproject.io/api-docs/auth/approle#list-secret-id-accessors
## see https://www.vaultproject.io/api-docs/auth/approle#read-approle-secret-id
## see https://www.vaultproject.io/api-docs/auth/approle#destroy-approle-secret-id
## see https://www.vaultproject.io/api-docs/auth/approle#read-approle-secret-id-accessor
## see https://www.vaultproject.io/api-docs/auth/approle#destroy-approle-secret-id-accessor
## see https://www.vaultproject.io/api-docs/auth/approle#create-custom-approle-secret-id

proc loginAppRole*(client: VaultClient, roleId, secretId: string, useToken = true): Future[JsonNode] {.async.} =
  ## see https://www.vaultproject.io/api-docs/auth/approle#login-with-approle
  result = await client.write("auth/approle/login", %*{
    "role_id": roleId,
    "secret_id": secretId
  })
  if useToken:
    let token = result["auth"]["client_token"].getStr()
    client.token = token
  

## see https://www.vaultproject.io/api-docs/auth/approle#read-update-or-delete-approle-properties
## see https://www.vaultproject.io/api-docs/auth/approle#tidy-tokens