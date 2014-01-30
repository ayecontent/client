"use strict"

Logger = require "lib/logger"
config = require "config"
expect = require "expect.js"


logger = new Logger

logger.info """

            ----------------------
                    START
            ----------------------
            """

Application = require "lib/application"
Injector = require "lib/injector"
Sync = require "lib/sync"

EventHandler = require "lib/eventHandler"
eventHandler = new EventHandler

Injector.register("eventHandler", eventHandler)
Injector.register("config", config)
Injector.register("logger", logger)
Injector.register("socketIO", require('socket.io-client'))
Injector.register("http", require "http")

sync = new Sync()
Injector.register("sync", sync)

application = new Application()
application.start()