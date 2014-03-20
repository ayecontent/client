"use strict"

_ = require "lodash"
querystring = require "querystring"
jwt = require "jsonwebtoken"
events = require "events"
errors = require "./../errors"
socketIO = require "socket.io-client"
util = require "util"
EventHubConnector = require "./../eventhub-connector"

class Socket extends EventHubConnector

  _RECONNECT_MIN_DELAY: 1000
  _RECONNECT_MAX_DELAY: 10000

  constructor: (args) ->
    {@logger, @config} = args
    @_connectString = "ws://" + @config.get("eventhub:address") + ":" + @config.get("eventhub:port")
    @_clientId = @config.get("client:id")
    @_signature = @config.get("client:sign")

  initListeners: () ->
    @_socket.on "connect", () =>
      @logger.info("Client '#{@_clientId}' connected to EVENT-HUB. #{@logger.timeEnd "Connection to EVENT-HUB"}")
      @_delay = @_RECONNECT_MIN_DELAY

    @_socket.on "message", (message, callback) =>
      @logger.info "Received EVENT-HUB message: '#{util.inspect(message, { depth: 30 })}'"
      msg = "Finished processing of message '#{message.id}'. SYNC-TYPE: '#{message.command.name}'. Processing"
      @logger.time msg
      @emit "command", message.command, (err, result) =>
        @logger.info @logger.timeEnd msg
        err = errors.stringifyError(err) if err?
        @logger.info "Sending message id '#{message.id}' callback to the eventhub. Callback: '#{util.inspect {err: err, result: result}, {depth: 30}}'"
        callback(err, result)

    @_socket.on "disconnect", =>
      @logger.info("Client '#{@_clientId}' disconnected from EVENT-HUB")
      @reconnect()

    @_socket.on "error", (err) =>
      @logger.error "EVENT-HUB connection error: '#{err}'"
      @reconnect()

  start: () ->
    @logger.info "Start Socket EVENT-HUB Connector"
    client = @config.get("client")
    token = jwt.sign({client: client}, @config.get("secret"), { expiresInMinutes: 60 * 5 });
    query = querystring.stringify({token: token, id: client.id})
    @logger.info "Start connection to EVENT-HUB"
    @logger.time "Connection to EVENT-HUB"
    @_socket = socketIO.connect @_connectString, {
      reconnect: false,
      query: query
    } #handling reconnection manually
    @initListeners()

  reconnect: () ->
    @_socket.socket.disconnect()
    @_delay ?= @_RECONNECT_MIN_DELAY
    @_delay = if @_delay < @_RECONNECT_MAX_DELAY then @_delay else @_RECONNECT_MAX_DELAY

    setTimeout(=>
      @logger.info "Start reconnection to EVENT-HUB"
      @logger.time "Connection to EVENT-HUB"
      @_socket.socket.connect()
    , @_delay)
    @_delay *= 2

module.exports = Socket