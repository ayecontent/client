'use strict';


if (process.env.NODE_ENV !== 'production') {
  var longjohn = require('longjohn');
}

var http = require("http");
var clientOptions = require("./options");
var Executor = new require("./executor")();
var fs = require("fs");
var sys = require('util');
var command = require("./commands");
var winston = require('winston');
var logger = new (winston.Logger)(require('./loggerConfig'));
var async = require('async');


var poolingOptions = {
  host: clientOptions.server,
  port: clientOptions.port,
  path: '/pool',
  method: 'GET'
};

var acknowledgeOptions = {
  host: clientOptions.server,
  port: clientOptions.port,
  path: '/send',
  method: 'POST'
};


Executor.execute(new command.FullSyncCommand(clientOptions, function (result) {
  logger.info(' is executed! result ', result);
}));

var rsyncQueue = async.queue(function (objectName, callback) {
  Executor.execute(new command.FullSyncCommand(clientOptions, function (result) {
    logger.info(objectName, ' is executed! result ', result);
    var acknowledgeRequest = http.request(acknowledgeOptions, callback);
    acknowledgeRequest.write(JSON.stringify({"command": "fullSync", "result": result}));
    acknowledgeRequest.end();
  }));
}, 1);

async.forever(function (foCallback) {
//    logger.info('rsync ', clientOptions.stopContentDeliveryFile, ' check');
    if (fs.existsSync(clientOptions.sourceFolder + clientOptions.startContentDeliveryFile)) {
      logger.info(clientOptions.startContentDeliveryFile, ' file is found, rsync auto queue is started');
      Executor.execute(new command.RsyncCommand(clientOptions, function (result) {
        logger.info('rsynced with result=', result);
        fs.unlinkSync(clientOptions.sourceFolder + clientOptions.startContentDeliveryFile);
        foCallback(null);
      }));
    }
    else if (fs.existsSync(clientOptions.sourceFolder) && !fs.existsSync(clientOptions.sourceFolder + clientOptions.stopContentDeliveryFile)) {
      logger.info('rsync operation with home folder started');
      async.whilst(
        function () {
          return fs.existsSync(clientOptions.sourceFolder) && !fs.existsSync(clientOptions.sourceFolder + clientOptions.stopContentDeliveryFile);
        },
        function (callback) {
          if (fs.existsSync(clientOptions.sourceFolder) && !fs.existsSync(clientOptions.sourceFolder + clientOptions.stopPeriodicRsyncFile)) {
            Executor.execute(new command.RsyncCommand(clientOptions, function (result) {
              logger.info('rsynced with result=', result);
              setTimeout(function () {
                callback(null);
              }, 10000);
            }));
          } else {
            logger.info(clientOptions.stopPeriodicRsyncFile, ' was placed, rsync auto queue is stopped');
            setTimeout(function () {
              callback(null);
            }, 10000);
          }
        },
        function (err) {
          logger.info(clientOptions.stopContentDeliveryFile, ' was placed, rsync auto queue is stopped');
          foCallback(null);
        }
      );
    } else {
//      logger.info(clientOptions.stopContentDeliveryFile, ' exists, rsync auto queue is stopped');
      setTimeout(function () {
        foCallback(null);
      }, 1000);
    }
  },
  function (err) {
    if (err) logger.error(err);
//    if (err) throw err;
  }
);

//process.on('uncaughtException', function (err) {
//    logger.error(err);
//});

function pool() {
  var poolingRequest = http.request(poolingOptions);

  poolingRequest.on('error', function (e) {
    logger.error("Got error: " + e.message);
    setTimeout(function () {
      pool();
    }, 3000);
  });

  poolingRequest.end();

  poolingRequest.on('response', function (res) {
    logger.info('STATUS: ' + res.statusCode);
    logger.info('HEADERS: ' + JSON.stringify(res.headers));
    res.setEncoding('utf8');
    logger.info('start pooling ');

    res.on('data', function (data) {  //message from server is received
      logger.info('message from server is received ', data.toString());
      var message = JSON.parse(data.toString());
      if (!message) return;
      switch (message.command.toString()) {
        case 'getClientId':
          logger.info('sending response to the server');
          var acknowledgeRequest = http.request(acknowledgeOptions);
          acknowledgeRequest.write(JSON.stringify({"command": "getClientId", "result": clientOptions.clientId}));
          acknowledgeRequest.end();
          break;
        case 'fullRsync':
          rsyncQueue.push('RSYNC');
          break;
      }
    });

    res.on('end', function (data) {
      poolingRequest.end();
      logger.info("end request, restart");
      setTimeout(function () {
        pool();
      }, 1000);
    });

  });

}
pool();
