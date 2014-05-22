expect = require "expect.js"
Sync = require "sync"
config = require "config"
util = require "util"
path = require "path"

longjohn = require('longjohn')
longjohn.async_trace_limit = -1



Logger = require("lib/logger")
Application = require "lib/application"
logger = new Logger

sync = new Sync("logger": logger, "config": config)

expect(sync._source).to.be.a('string')
expect(sync._dest).to.be.a('string')


sync.pushCommand({
  name: "sync-http",
  host: "localhost",
  port: "8080",
  added: ['first.txt'],
  modified: [],
  deleted: [],
  snapshot: { id: "123"}
})
.then((result)->
    console.log(result)
  )
.catch((error)->
  )
.done()

#sync.pushCommand({
#  name: "sync-backup",
#  host: "localhost",
#  port: "8080",
#  added: ['first.txt'],
#  modified: [],
#  deleted: [],
#  snapshot: { id: "123"}
#})
#.then((result)->
#    console.log(result)
#  )
#.done()

#application = new Application("logger": logger, "config": config)
