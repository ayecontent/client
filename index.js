// Generated by CoffeeScript 1.7.1
"use strict";
var Application, Logger, application, config, expect, logger;

Logger = require("lib/logger");

config = require("config");

expect = require("expect.js");

logger = new Logger;

logger.info("\n----------------------\n        START\n----------------------");

Application = require("lib/application");

application = new Application({
  "logger": logger,
  "config": config
});

application.start();
