"use strict"

Socket = require "./../connector/socket"
Sync = require "./../sync"

class Application
  constructor: (args) ->
    {@logger, @config} = args
    @eventHubConnector = new Socket(logger: @logger, config: @config)
    @sync = new Sync(logger: @logger, config: @config)

  configure: ->
    @initListeners()

  start: ->
    @configure()
    @eventHubConnector.start()
#    @sync.syncReset().then ()=>
    @sync.startAutoSync()


  initListeners: ->
    @eventHubConnector.on "connected", (event) =>
      @logger.info "connected to event hub"

    @eventHubConnector.on "command", (command, callback) =>
      @sync.pushCommand(command)
      .then((result) =>
          callback(null, result)
        )
      .catch((err) =>
          callback(err)
        )
      .done()

module.exports = Application
