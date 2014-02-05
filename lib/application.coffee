"use strict"

Socket = require "eventhub_connector/socket"
Sync = require "sync"

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

  initListeners: ->
    @eventHubConnector.on "connected", (event) =>
      @logger.info "connected to event hub"

    @eventHubConnector.on "command", (event) =>
      @sync.pushCommand(event.command.name, event.callback)

module.exports = Application
