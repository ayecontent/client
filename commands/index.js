'use strict';

var Rsync = require('rsync');
var _ = require('lodash');
var fs = require("fs-extra");
var winston = require('winston');
var logger = require('../lib/log');
var async = require('async');
var path = require('path');
var exec = require('child_process').exec;
var util = require('util');

var rsync = new Rsync()
  .flags('avz')
  .set('delete')
  .exclude([".git*", ".stop-content-delivery", ".stop-periodic-sync", ".start-content-delivery"]);

function localSync(options, callback) {
  fs.mkdirsSync(options.sourceFolder);
  fs.mkdirsSync(options.destFolder);

  rsync.source(options.sourceFolder)
    .destination(options.destFolder);

  options.profiling && winston.profile('Rsync-Profile-Test');
  rsync.execute(
    function (error, code, cmd) {
      logger.info('tried to do local rsync; result: ' + code);
      error && logger.info('tried to do local rsync; result output: ' + code + '; error result: ' + error);
      options.profiling && winston.profile('Rsync-Profile-Test');
      callback('success');
    }, null, function (err) {
      err && logger.error('tried to do local rsync; error result: ' + err.message);
      callback('error');
    }
  );
}


function gitSync(options, commandCallback) {
//  logger.info('starting to run git rsync' + ' source folder: ' + options.sourceFolder + ';' + ' destination folder: ' + options.destFolder);
  async.waterfall([
    function (callback) {
      fs.mkdirsSync(options.sourceFolder);
      options.profiling && winston.profile('Git-Status-Profile-Test');
      exec('git --git-dir=' + path.resolve(options.sourceFolder, '.git') + ' --work-tree=' + options.sourceFolder + ' status', function (error, stdout, stderr) {
        stdout && logger.info('checked git repository status; result output: ' + stdout);
        stderr && logger.error('checked git repository status; error output: ' + stderr);
        options.profiling && winston.profile('Git-Status-Profile-Test');
        if (!stderr) {
          callback(null, "success");
        } else {
          fs.removeSync(options.sourceFolder);
          fs.mkdirsSync(options.sourceFolder);
          stdout && logger.info('start to clone git repository; it may take some time');
          options.profiling && winston.profile('Git-Clone-Profile-Test');
          exec('git clone ' + options.gitUrl + ' ' + options.sourceFolder, function (error, stdout, stderr) {
            stdout && logger.info('tried to clone git repository; result output: ' + stdout);
            if (stderr) {
              callback(new Error(stderr));
            } else {
              options.profiling && winston.profile('Git-Clone-Profile-Test');
              callback(null, "success");
            }
          });
        }
      });
    },
    function (result, callback) {
      options.profiling && winston.profile('Git-Pool-Profile-Test');
      fs.openSync(path.resolve(options.sourceFolder, options.stopContentDeliveryFile), 'w');
      exec('git --git-dir=' + path.resolve(options.sourceFolder, '.git') + ' --work-tree=' + options.sourceFolder + ' pull', function (error, stdout, stderr) {
        stdout && logger.info('tried to pull git repository; result output: ' + stdout);
        var stopContentDeliveryPath = path.resolve(options.sourceFolder, options.stopContentDeliveryFile);
        if (fs.existsSync(stopContentDeliveryPath)) {
          fs.unlinkSync(stopContentDeliveryPath);
        }
        if (!stderr) {
          options.profiling && winston.profile('Git-Pool-Profile-Test');
          callback(null, 'success');
        } else {
          callback(new Error(stderr));
        }
      });
    }
  ],
    function (err, result) {
      if (err) {
        logger.error(err.message);
        commandCallback && commandCallback(err.message);
      }
      else {
        localSync(options, commandCallback);
      }
    }
  );
}

exports.commands = {
  localSync: function (options, callback) {
    return localSync(options, callback);
  },
  gitSync: function (options, callback) {
    return gitSync(options, callback);
  }
};

var Command = function (command, options, callback) {
  this.command = command;
  this.options = options;
  this.callback = callback;
}

Command.prototype.execute = function () {
  executionQueue.push(this);
}

exports.GitSyncCommand = _.partial(Command, 'gitSync');
util.inherits(exports.GitSyncCommand, Command);

exports.LocalSyncCommand = _.partial(Command, 'localSync');
util.inherits(exports.LocalSyncCommand, Command);


var executionQueue = async.queue(function (command, callback) {
  exports.commands[command.command](command.options, function (result) {
    callback(result); // internal callback
    return command.callback(result); // external callback
  });
});





