'use strict'

#var fs = require('fs');
#var path = require('path');
#var commands = require('../commands');
#var logger = require('../lib/log');
#
#module.exports = function (options) {
#
#    var startContentDeliveryPath = path.resolve(options.sourceFolder, options.startContentDeliveryFile);
#    var stopContentDeliveryPath = path.resolve(options.sourceFolder, options.stopContentDeliveryFile);
#    var stopPeriodicRsyncPath = path.resolve(options.sourceFolder, options.stopPeriodicRsyncFile);
#    var lastStatus = null;
#
#    function logChanges(path, logResult) {
#        if (lastStatus !== path) {
#            logger.info((path ? path + ' was found; ' : '') + logResult);
#            lastStatus = path;
#        }
#    }
#
#    function autoLocalSync() {
#        if (fs.existsSync(startContentDeliveryPath)) {
#            logChanges(startContentDeliveryPath, 'local sync will be forced');
#            var gitSyncCommand = new commands.GitSyncCommand(options, function (result) {
#                if (fs.existsSync(startContentDeliveryPath)) {
#                    fs.unlinkSync(startContentDeliveryPath);
#                    setTimeout(autoLocalSync, 1000);
#                }
#            });
#            gitSyncCommand.execute();
#        }
#        else if (fs.existsSync(stopPeriodicRsyncPath)) {
#            logChanges(stopPeriodicRsyncPath, 'periodic local sync will be stopped');
#            setTimeout(autoLocalSync, 10000);
#        }
#        else if (fs.existsSync(stopContentDeliveryPath)) {
#            logChanges(stopContentDeliveryPath, 'local sync will be stopped');
#            setTimeout(autoLocalSync, 1000);
#        }
#        else {
#            logChanges(null, 'periodic local sync was switched to normal mode');
#            new commands.LocalSyncCommand(options, function (result) {
#                setTimeout(autoLocalSync, 10000);
#            }).execute();
#        }
#    }
#
#    return {'start': autoLocalSync};
#};