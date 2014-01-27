"use strict";

"use strict"

class Application
  constructor: (args) ->
    {@logger, @$http, @$socketIOClient, @$Socket, @$EventHandler, @Stomp, @$config} = args
    @eventHandler = new @$EventHandler()
    @socket = new @$Socket {
      "$socketIOClient": @$socketIOClient
      "logger": @logger
      "eventHandler": @eventHandler
      "$config": @$config
    }
  configure: ->
    @initListeners()
  start: ->
    @configure()
    @socket.start()
  initListeners: ->
    @eventHandler.on "socket/connect", =>
      #@logger.info "socket connected, event handler is working"

    @eventHandler.on "socket/start", =>
      #@logger.info "socket started, event handler is working"

    @eventHandler.on "socket/error", =>
      #@logger.info "socket error, event handler is working"

module.exports = Application


#var commands = require("../commands");
#
#module.exports = function (options) {
#
#    require("../socket")(options).start();
#    require("./autolocalsync")(options).start();
#
#    new commands.GitSyncCommand(options, function (result) {
#    }).execute();
#
#    var client = {};
#
#    return client;
#};
