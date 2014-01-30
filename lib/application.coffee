"use strict"

Injector = require "lib/injector"
Socket = require "socket"

class Application
  constructor: (@message)->
    do Injector.resolve(((@logger, @http, @socketIO, @stomp, @eventHandler, @sync)->), @)
    @socket = new Socket()
  test: ->
    "application" + @message
  configure: ->
    @initListeners()
  start: ->
    @configure()
    @socket.start()
  initListeners: ->
    @eventHandler.on "socket/connect", =>
      @logger.info "socket connected"

    @eventHandler.on "socket/command", (command, callback) =>
      @logger.info "socket command"
      @sync[command] (err, result)=>
        @logger.info "socket command result #{result}"
        callback(err, result)

    @eventHandler.on "socket/start", =>
      #@logger.info "socket started, event handler is working"

    @eventHandler.on "socket/error", =>
      #@logger.info "socket error, event handler is working"

module.exports = Application
