expect = require "expect.js"
Sync = require "lib/sync"
Injector = require "lib/injector"
config = require "config"


Logger = require("lib/logger")
logger = new Logger

Application = require "lib/application"

EventHandler = require "lib/eventHandler"
eventHandler = new EventHandler

Injector.register("http", require "http")
Injector.register("logger", logger)
Injector.register("socketIO", require "socket.io-client")
Injector.register("eventHandler", eventHandler)
Injector.register("config", config)

sync = new Sync()
Injector.register("sync", sync)

#sync.startAutoSync()

console.log(sync.flags)



expect(sync.source).to.be.a('string')
expect(sync.dest).to.be.a('string')

sync.pushCommand("gitSync", (err, result)->
  expect(result).to.be("success")
)
#
#sync.pushCommand("localSync", (err, result)->
#  expect(result).to.be("success")
#)

sync["_logChanges"]("result")

#Injector.register("config", require "../config")

application = new Application(" test")
expect(application instanceof Application).to.be true
application.logger.info "Hello"
expect(application.test()).to.be "application test"