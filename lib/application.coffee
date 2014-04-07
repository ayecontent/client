"use strict"

Socket = require "./../eventhub-connector/socket-connector"
Sync = require "./../sync"
util = require "util"
fs = require "fs"
exec = require('child_process').exec

class Application
  constructor: (args) ->
    {@logger, @config} = args
    @eventHubConnector = new Socket(logger: @logger, config: @config)
    @sync = new Sync(logger: @logger, config: @config)

  replaceBasePath: (source, dest)->
    dest?=source
    fs.readFile "#{source}.template", 'utf8', (err, data) =>
      result = data.replace(/%CLIENT_PATH%/g, @config.get('basePath'))
      .replace(/%KEY_NAME%/g, @config.get('git:keyName'))
      fs.writeFile "#{dest}", result, 'utf8'

#  npmUpdate: ()->
#    exec "npm install", {cwd: @_source}, (err, stdout, stderr) =>
#      @logger.error stderr
#      @logger.info stdout


  start: ->
    @replaceBasePath('ssh-shell')
    @replaceBasePath('ssh', 'config/ssh')
    @initListeners()
    @eventHubConnector.start()
    @sync.syncReset (err) =>
      if err? then return @logger.error(util.inspect err, { depth: 30 })
      else
        @sync.startAutoSync()

  initListeners: ->
    @eventHubConnector.on "reconnect", @sync.syncReset.bind(@sync)

    @eventHubConnector.on "command", (command, callback) =>
      @sync.pushCommand command, (err, result) =>
        if err?
          @logger.error(util.inspect err, { depth: 30 })
          callback(err)
        else
          callback(null, result ? result: "SUCCESS")

module.exports = Application
