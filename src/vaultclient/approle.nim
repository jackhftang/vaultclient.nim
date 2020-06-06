import base, asyncdispatch

proc loginAppRole*(client: VaultClient, roleId, secretId: string): Future[void] {.async.} =
  ## Login with approle auth engine. Auto set token. 
  let res = await client.write("auth/approle/login", %*{
    "role_id": roleId,
    "secret_id": secretId
  })
  let token = res["auth"]["client_token"].getStr()
  client.token = token