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
    @eventHubConnector.start()
    @sync.syncReset (err) =>
      if err isnt null then return @logger.error(util.inspect err, { depth: 30 })
      else @sync.startAutoSync()

  initListeners: ->
    @eventHubConnector.on "command", (command, callback) =>
      @sync.pushCommand command, (err, result) =>
        if err isnt null
          @logger.error(util.inspect err, { depth: 30 })
          callback(err)
        else
          callback(null, result ? result : "SUCCESS")

module.exports = Application
