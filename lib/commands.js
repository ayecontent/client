'use strict';

var Rsync = require('rsync');
var git = require('gift');
var fs = require("fs");
var winston = require('winston');
var logger = new (winston.Logger)(require('./loggerConfig'));
var clientOptions = require('./options');
var async = require('async');


var command = module.exports = {};

function rsync(value, callback) {
  logger.info('rsyncCommand');

  var rsync = new Rsync()
    .flags('avz')
    .set('delete')
    .source(value.sourceFolder)
    .destination(value.destFolder)
    .exclude(clientOptions.excludedRsyncFiles);
  logger.info('rsync command', rsync.command());

  // execute with stream callbacks
  winston.profile('test of rsync');
  rsync.execute(
    function (error, code, cmd) {
      logger.info('All done executing', code);
      winston.profile('test of rsync');
      callback(code);
    }, function (data) {
      logger.info(data.toString());
    }, function (data) {
      logger.error(data.toString());
    }
  );
}

function gitClone(value, callback) {
  logger.info('gitClone');
  winston.profile('test of repository cloning');
  git.clone(value.gitUrl, value.sourceFolder, function (err) {
    if (err) {
      logger.error('git repository clone error!');
      throw err;
    }
    winston.profile('test of repository cloning');
    return callback({cloned: true});
  });
}

function fullSyncFunc(value, callback) {
  logger.info('gitCommand');
  async.waterfall([
    function (callback) {
      fs.stat(value.sourceFolder + '.git/', function (err, stats) {
        if (!err) {
          var gitExists = stats.isDirectory();
        }
        if (!gitExists || err) {
          return gitClone(value, callback);
        }
        else {
          callback(null, {cloned: false});
        }
      });
    },
    function (result, callback) {
      var repo = git(value.sourceFolder);
      winston.profile('test of repository git pooling');
      repo.remote_fetch('origin/master', function (err) {
        winston.profile('test of repository git pooling');
        if (err) {
          logger.error('git repository sync error!');
          callback(err);
        } else {
          callback(null, err);
        }
      });
    }
  ],
    function (result, err) {
      if (err) logger.error(err);
      if (err) throw err;
      rsync(value, callback);
    }
  );
}

command.Command = function (execute, value, callback) {
  this.execute = execute;
  this.value = value;
  this.callback = callback;
}

command.RsyncCommand = function (value, callback) {
  return new command.Command(rsync, value, callback);
};

command.GitCloneCommand = function (value, callback) {
  return new command.Command(gitClone, value, callback);
};

command.FullSyncCommand = function (value, callback) {
  return new command.Command(fullSyncFunc, value, callback);
};

