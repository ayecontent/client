'use strict';

var logger = require('../lib/log');
var io = require('socket.io-client');
var commands = require('../commands');

module.exports = function (options) {

    function reconnect(delay) {
        delay = delay || 200;
        delay = delay < 10000 ? delay : 10000;
        socket.once('error', function () {
            logger.error('socket connection error. trying to reconnect; clientId: ' + options.clientId + '; eventhub ip address: ' + options.server);
            setTimeout(function () {
                reconnect(delay * 2)
            }, delay);
        })
        socket.socket.connect();
    }

    var socket = io.connect('ws://' + options.server + ':' + options.port, {
        reconnect: false //handling reconnection manually
    });

    socket.once('error', function () {
        logger.error('socket connection error. trying to reconnect; clientId: ' + options.clientId + '; eventhub ip address: ' + options.server);
        reconnect();
    });

    socket
      .on('command', function (command, cb) {
          logger.info('client received socket command from eventhub; clientId: ' + options.clientId + '; command: ' + command);
          new commands[command + 'Command'](options, function (result) {
              cb && cb(result);
          }).execute();
      })
      .on('connect', function () {
          logger.info('client has connected to eventhub socket; clientId: ' + options.clientId + '; eventhub ip address: ' + options.server);
          socket.emit('login', { clientId: options.clientId });
      })
      .on('disconnect', function () {
          //TODO: change logging level to warn when implemented
          logger.info('client disconnected from eventhub socket; clientId: ' + options.clientId + '; eventhub ip address: ' + options.server);
          !socket.socket.options.reconnect && reconnect();
      })

}