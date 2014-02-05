"use strict"

Injector = require "lib/injector"
Socket = require "socket"
Sync = require "lib/sync"

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

    @eventHubConnector.on "start", () =>
      #@logger.info "socket started, event handler is working"

    @eventHubConnector.on "error", (err) =>
      #@logger.info "socket error, event handler is working"

module.exports = Application
