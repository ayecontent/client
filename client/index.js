'use strict';
var fs = require('fs');
var path = require('path');
var commands = require('../commands');
var logger = require('../lib/log');
process.env.NODE_ENV !== 'production' && require('longjohn');

module.exports = function (options) {

  require('../socket')(options);

  var client = {};
  var lastStatus = null;
  client.autoLocalSync = function () {
    var startContentDeliveryPath = path.resolve(options.sourceFolder, options.startContentDeliveryFile);
    var stopContentDeliveryPath = path.resolve(options.sourceFolder, options.stopContentDeliveryFile);
    var stopPeriodicRsyncPath = path.resolve(options.sourceFolder, options.stopPeriodicRsyncFile);
    if (fs.existsSync(startContentDeliveryPath)) {
      if (lastStatus !== startContentDeliveryPath) {
        logger.info(options.startContentDeliveryFile + ' found in ' + options.sourceFolder + ' . Local sync will be performed');
      }
      new commands.GitSyncCommand(options, function (result) {
        if (fs.existsSync(startContentDeliveryPath)) {
          fs.unlinkSync(startContentDeliveryPath);
          setTimeout(client.autoLocalSync, 1000);
        }
      }).execute();
    }
    else if (fs.existsSync(stopPeriodicRsyncPath)) {
      if (lastStatus !== stopPeriodicRsyncPath) {
        logger.info(options.stopPeriodicRsyncFile + ' found in ' + options.sourceFolder + ' location. Periodic local sync will be stopped');
        lastStatus = stopPeriodicRsyncPath;
      }
      setTimeout(client.autoLocalSync, 10000);
    }
    else if (fs.existsSync(stopContentDeliveryPath)) {
      if (lastStatus !== stopContentDeliveryPath) {
        logger.info(options.stopContentDeliveryFile + ' found in ' + options.sourceFolder + ' location. Local sync will be stopped');
        lastStatus = stopContentDeliveryPath;
      }
      setTimeout(client.autoLocalSync, 1000);
    }
    else {
      if (lastStatus !== null) {
        logger.info('periodic local sync was switched to normal mode');
        lastStatus = null;
      }
      new commands.LocalSyncCommand(options, function (result) {
        setTimeout(client.autoLocalSync, 10000);
      }).execute();
    }
  };

  return client;
};
