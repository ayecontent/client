path = require('path')
startStopDaemon = require('start-stop-daemon')

daemon = startStopDaemon {
  silent: false,
  max: 1000,
  watch: true,
  watchDirectory: __dirname, # Top-level directory to watch from.
  watchIgnoreDotFiles: true, # whether to ignore dot files
  watchIgnorePatterns: ["#{path.resolve(__dirname, 'log')}/**"],
# array of glob patterns to ignore, merged with contents of watchDirectory + '/.foreverignore' file
  logFile: path.resolve(__dirname, 'log/forever.log'), # Path to log output from forever process (when daemonized)
#  outFile: 'log/forever.out', # Path to log output from child stdout
  errFile: path.resolve(__dirname, 'log/forever.err')
}, () ->
    Logger = require "./lib/logger"
    logger = new Logger()

    logger.info "----------- START -----------"

    Application = require "./lib/application"

    config = require "./config"
    config.set "basePath", __dirname

    application = new Application ("logger": logger, "config": config)
    application.start()


daemon.on "restart", () ->
  process.stdout.write('Restarting at ' + new Date() + '\n');

daemon.on 'exit', () ->
  process.stdout.write('index.js has exited after max restarts')

