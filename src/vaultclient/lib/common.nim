import json, sequtils, strutils, strformat, asyncdispatch, uri
export json, sequtils, strutils, strformat, asyncdispatch, uri

import os
export os.`/`

proc ignore*(fut: Future[JsonNode]): Future[void] {.async.} =
  # ignore result
  yield fut
  if fut.failed:
    raise fut.readError()

template isNotNil*(x: typed): bool = not x.isNil