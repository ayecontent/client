path = require('path')
startStopDaemon = require('start-stop-daemon')
Logger = require "./lib/logger"
logger = new Logger()
_ = require "lodash"
fs = require "fs"
config = require "nconf"

daemon = startStopDaemon {
  silent: false,
  max: 1000,
  watch: false,
  errFile: path.join(__dirname, 'log/forever.err')
}, () ->
  logger.info "----------- START -----------"

  Application = require "./lib/application"

  config.file {file: path.join __dirname, "./config/config.json"}
  config.set "basepath", __dirname

  config.save () =>
    application = new Application ("logger": logger, "config": config)
    application.start()


daemon.on "restart", () ->
  process.stdout.write('Restarting at ' + new Date() + '\n');
  logger.info "----------- RESTART -----------"

daemon.on 'exit', () ->
  process.stdout.write('index.js has exited after max restarts')
  logger.info "----------- RESTART -----------"