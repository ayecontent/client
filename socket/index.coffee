"use strict"

Injector = require "lib/injector"
crypto = require "crypto"
querystring = require "querystring"


class Socket
  _RECONNECT_MIN_DELAY = 1000
  _RECONNECT_MAX_DELAY = 10000

  constructor: () ->
    do Injector.resolve(((@logger, @config, @socketIO,@eventHandler)->), @)
    @_connectString = "ws://" + @config.get("eventhub:address") + ":" + @config.get("eventhub:port")
    @_clientId = @config.get("client:id")
    @_signature = @config.get("client:sign")

  configure: ()->

    @_socket.on "connect", =>
      @logger.info("client '#{@_clientId}' has connected to eventhub socket")
      @eventHandler.emit "socket/connect"

    @_socket.on "command", (command,callback) =>
      @logger.info "received socket COMMAND '#{command}'"
      @eventHandler.emit "socket/command", command, callback

    @_socket.on "disconnect", =>
      @logger.info("client '#{@_clientId}' has disconnected to eventhub socket")
      @reconnect()

    @_socket.once "error", (err) =>
      @logger.error """Socket connection error:
      #{err}"""
      @reconnect()
      @eventHandler.emit "socket/error"

  start: () ->
    query = querystring.stringify({ id: @_clientId, sign: @_signature })
    @_socket = @socketIO.connect @_connectString, {
      reconnect: false,
      query: query
    } #handling reconnection manually
    @configure()
    @eventHandler.emit "socket/start"

  reconnect: () ->
    @_delay ?= _RECONNECT_MIN_DELAY
    @_delay = if @_delay < _RECONNECT_MAX_DELAY then @_delay else _RECONNECT_MAX_DELAY
    @_socket.once "error", (err) =>
      @logger.error """Socket connection error. Trying to reconnect.
      #{err}
      """
      setTimeout(=>
        @reconnect()
      , @_delay)
      @_delay *= 2
      @eventHandler.emit "socket/error"
    @_socket.socket.connect()


module.exports = Socket