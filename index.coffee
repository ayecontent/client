"use strict"

Logger = require("lib/logger")
logger = new Logger()

logger.info """

            ----------------------
                    START
            ----------------------
            """


Application = require "lib/application"

application = new Application({
  $http: require "http"
  logger: logger
  $socketIOClient: require "socket.io-client"
  $Socket: require "socket"
  $EventHandler: require "lib/eventHandler"
  $config: require "config"
})

application.start()