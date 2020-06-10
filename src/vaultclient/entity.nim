import lib/common
import base

proc takeData(fut: Future[JsonNode]): Future[JsonNode] {.async.} =
  yield fut
  if fut.failed:
    raise fut.readError
  result = fut.read["data"]

proc createEntity*(client: VaultClient, options: JsonNode): Future[JsonNode] =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#create-an-entity
  client.write("identity/entity", options).takeData()

proc createEntity*(client: VaultClient, name: string, policies: openarray[string], metadata: JsonNode = nil, disabled = false): Future[JsonNode] =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#create-update-entity-by-name
  var options = %*{
    "name": name,
    "policies": policies,
    "disabled": disabled
  }
  if metadata.isNotNil:
    options["metadata"] = metadata
  client.write("identity/entity/name" / name, options).takeData()

proc getEntity*(client: VaultClient, id: string): Future[JsonNode] =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#read-entity-by-id
  client.read("identity/entity/id" / id).takeData()

proc putEntity*(client: VaultClient, id: string, options: JsonNode): Future[void] =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#update-entity-by-id
  client.write("identity/entity/id" / id, options).ignore()

proc listEntityIds*(client: VaultClient): Future[seq[string]] {.async.} =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#list-entities-by-id
  let json = await client.list("identity/entity/id")
  for x in json["data"]["keys"]: result.add x.getStr()

proc deleteEntity*(client: VaultClient, id: string): Future[void] =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#delete-entity-by-id
  client.delete("identity/entity/id" / id).ignore()

proc deleteEntity*(client: VaultClient, ids: openarray[string]): Future[void] =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#batch-delete-entities
  client.write("identity/entity/batch-delete", %*{
    "entity_ids": ids
  }).ignore()

proc mergeEntity*(client: VaultClient, toId: string, fromIds: openarray[string], force = false): Future[void] =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#merge-entities
  client.write("identity/entity/merge", %*{
    "from_entity_ids": fromIds,
    "to_entity_id": toId,
    "force": force
  }).ignore()

# -------------------------------------------------------------
# byName

proc getEntityByName*(client: VaultClient, name: string): Future[JsonNode] =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#read-entity-by-name
  client.read("identity/entity/name" / name).takeData()

proc putEntityByName*(client: VaultClient, name: string, options: JsonNode): Future[void] =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#create-update-entity-by-name
  client.write("identity/entity/name" / name, options).ignore()

proc deleteEntityByName*(client: VaultClient, name: string): Future[void] =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#delete-entity-by-id
  client.delete("identity/entity/name" / name).ignore()

proc listEntityNames*(client: VaultClient): Future[seq[string]] {.async.} =
  ## see https://www.vaultproject.io/api-docs/secret/identity/entity#list-entities-by-name
  let json = await client.list("identity/entity/name")
  for x in json["data"]["keys"]: result.add x.getStr()