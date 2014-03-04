"use strict"

Socket = require "./../eventhub-connector/socket-connector"
Sync = require "./../sync"
util = require "util"

class Application
  constructor: (args) ->
    {@logger, @config} = args
    @eventHubConnector = new Socket(logger: @logger, config: @config)
    @sync = new Sync(logger: @logger, config: @config)

  start: ->
    @initListeners()
    @sync.syncReset().then () =>
      @sync.startAutoSync()
      @eventHubConnector.start()

  initListeners: ->
    @eventHubConnector.on "command", (command, callback) =>
      @sync.pushCommand(command)
      .then (result) =>
        callback(null, result)
      .catch (err) =>
        @logger.error(util.inspect err, { depth: 30 })
        callback(err)
      .done()

module.exports = Application
