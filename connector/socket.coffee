"use strict"

_ = require "lodash"
crypto = require "crypto"
querystring = require "querystring"
events = require "events"
errors = require "errors"
socketIO = require "socket.io-client"
EventHubConnector = require "connector"

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
      @_delay = @_RECONNECT_MIN_DELAY
      @logger.info("client '#{@_clientId}' has connected to eventhub socket")
      @emit "connected", {clientId: @_clientId}

    @_socket.on "message", (message, callback) =>
      @logger.info "received socket COMMAND '#{message.command.name}'"
      @emit "command", {command: message.command, callback: (err, result)=>
        err = errors.stringifyError(err) if err?
        callback(err, result)
      }

    @_socket.on "disconnect", =>
      @logger.info("client '#{@_clientId}' has disconnected to eventhub socket")
      @reconnect()

    @_socket.on "error", (err) =>
      @logger.error "Socket connection error:\n'#{err}'"
      @reconnect()

  start: () ->
    query = querystring.stringify({ id: @_clientId, sign: @_signature })
    @_socket = socketIO.connect @_connectString, {
      reconnect: false,
      query: query
    } #handling reconnection manually
    @configure()
    @emit "start"

  reconnect: () ->
    @_socket.socket.disconnect()
    @_delay ?= @_RECONNECT_MIN_DELAY
    @_delay = if @_delay < @_RECONNECT_MAX_DELAY then @_delay else @_RECONNECT_MAX_DELAY

    setTimeout(=>
      @logger.info "reconnect invoked"
      @_socket.socket.connect()
    , @_delay)
    @_delay *= 2

module.exports = Socket