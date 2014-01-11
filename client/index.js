'use strict';
var fs = require('fs');
var path = require('path');
var commands = require('../commands');
process.env.NODE_ENV !== 'production' && require('longjohn');

module.exports = function (options) {

  require('../socket')(options);

  var client = {};

  client.autoLocalSync = function () {
    var startContentDeliveryPath = path.resolve(options.sourceFolder, options.startContentDeliveryFile);
    var stopContentDeliveryPath = path.resolve(options.sourceFolder, options.stopContentDeliveryFile);
    var stopPeriodicRsyncPath = path.resolve(options.sourceFolder, options.stopPeriodicRsyncFile);
    if (fs.existsSync(startContentDeliveryPath)) {
      new commands.LocalSyncCommand(options, function (result) {
        if (fs.existsSync(startContentDeliveryPath)) {
          fs.unlinkSync(startContentDeliveryPath);
          setTimeout(client.autoLocalSync, 1000);
        }
      }).execute();
    }
    else if (fs.existsSync(stopPeriodicRsyncPath)) {
      setTimeout(client.autoLocalSync, 10000);
    }
    else if (fs.existsSync(stopContentDeliveryPath)) {
      setTimeout(client.autoLocalSync, 1000);
    }
    else {
      new commands.LocalSyncCommand(options, function (result) {
        setTimeout(client.autoLocalSync, 10000);
      }).execute();
    }
  };

  return client;
};
