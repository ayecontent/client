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

application = new Application {"logger": logger, "config": config}
application.start()
