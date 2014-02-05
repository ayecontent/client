"use strict"

_ = require "lodash"
Injector = require "lib/injector"
crypto = require "crypto"
querystring = require "querystring"
events = require "events"
socketIO = require "socket.io-client"
EventHubConnector = require "lib/EventHubConnector"

class Socket extends EventHubConnector

  _RECONNECT_MIN_DELAY: 1000
  _RECONNECT_MAX_DELAY: 10000

  constructor: (args) ->
    {@logger, @config} = args
    @_connectString = "ws://" + @config.get("eventhub:address") + ":" + @config.get("eventhub:port")
    @_clientId = @config.get("client:id")
    @_signature = @config.get("client:sign")

  configure: () ->
    @_socket.on "connect", () =>

      @removeAllListeners "reconnect"
      @once "reconnect", () =>
        @reconnect()

      @_delay = @_RECONNECT_MIN_DELAY
      @logger.info("client '#{@_clientId}' has connected to eventhub socket")
      @emit "connected", {clientId: @_clientId}

    @_socket.on "message", (message, callback) =>
      @logger.info "received socket COMMAND '#{message.command.name}'"
      @emit "command", {command: message.command, callback: callback}

    @_socket.on "disconnect", =>
      @logger.info("client '#{@_clientId}' has disconnected to eventhub socket")
      @emit "reconnect"

    @_socket.once "error", (err) =>
      @logger.error "Socket connection error:\n'#{err}'"
      @emit "reconnect"

    @.once "reconnect", () =>
      @reconnect()

  start: () ->
    query = querystring.stringify({ id: @_clientId, sign: @_signature })
    @_socket = socketIO.connect @_connectString, {
      reconnect: false,
      query: query
    } #handling reconnection manually
    @configure()
    @emit "start"

  reconnect: _.throttle(() ->
    @logger.info "reconnect invoked"
    @_socket.socket.disconnect()

    @_delay ?= @_RECONNECT_MIN_DELAY
    @_delay = if @_delay < @_RECONNECT_MAX_DELAY then @_delay else @_RECONNECT_MAX_DELAY

    @removeAllListeners "reconnect"
    @once "reconnect", () =>
      @reconnect()

    @_socket.once "error", (err) =>
      @logger.error "Socket connection error. Trying to reconnect. Error:\n#{err}"
      setTimeout(=>
        @emit "reconnect"
      , @_delay)
      @_delay *= 2
      @emit "error", err
    @_socket.socket.connect()

  ,@_RECONNECT_MIN_DELAY)

module.exports = Socket