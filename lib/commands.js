'use strict';

var Rsync = require('rsync');
var fs = require("fs");
var winston = require('winston');
var logger = require('./log');
var clientOptions = require('./options');
var async = require('async');
var path = require('path');

var exec = require('child_process').exec;


var command = module.exports = {};

function rsync(value, callback) {
  logger.info('rsyncCommand');

  var rsync = new Rsync()
    .flags('avz')
    .set('delete')
    .source(value.sourceFolder)
    .destination(value.destFolder)
    .exclude(clientOptions.excludedRsyncFiles);
//  logger.info('rsync command', rsync.command());

  // execute with stream callbacks
  winston.profile('test of rsync');
  rsync.execute(
    function (error, code, cmd) {
      logger.info('All done executing', code);
      winston.profile('test of rsync');
      callback(code);
    }, function (data) {
//      logger.info(data.toString());
    }, function (data) {
      logger.error(data.toString());
    }
  );
}

var deleteFolderRecursive = function (path) {
  if (fs.existsSync(path)) {
    fs.readdirSync(path).forEach(function (file, index) {
      var curPath = path + "/" + file;
      if (fs.statSync(curPath).isDirectory()) { // recurse
        deleteFolderRecursive(curPath);
      } else { // delete file
        fs.unlinkSync(curPath);
      }
    });
    fs.rmdirSync(path);
  }
};

function fullSyncFunc(value, callback) {
  logger.info('fullSyncFunc');
  async.waterfall([
    function (callback) {
      logger.info("trying to get repository status");

      exec('git --git-dir=' + path.resolve(clientOptions.sourceFolder, '.git') + ' --work-tree=' + clientOptions.sourceFolder + ' status', function (error, stdout, stderr) {
        logger.info(stdout);
        if (error) {
          logger.error(stderr);
          deleteFolderRecursive(clientOptions.sourceFolder);
          fs.mkdirSync(clientOptions.sourceFolder);
          winston.profile('test of repository git cloning');
          logger.info("trying to clone repository");
          exec('git clone ' + clientOptions.gitUrl + ' ' + clientOptions.sourceFolder, function (error, stdout, stderr) {
            if (error) {
              callback(stderr);
            } else {
              winston.profile('test of repository git cloning');
              logger.info(stdout);
              callback(null, "done");
            }
          });
        } else {
          callback(null, "done");
        }
      });
    },
    function (result, callback) {
      winston.profile('test of repository git pulling');
      fs.openSync(path.resolve(clientOptions.sourceFolder, clientOptions.stopContentDeliveryFile), 'w');
      exec('git --git-dir=' + path.resolve(clientOptions.sourceFolder, '.git') + ' --work-tree=' + clientOptions.sourceFolder + ' pull', function (error, stdout, stderr) {
        if (fs.existsSync(path.resolve(clientOptions.sourceFolder, clientOptions.stopContentDeliveryFile))) {
          fs.unlinkSync(path.resolve(clientOptions.sourceFolder, clientOptions.stopContentDeliveryFile));
        }
        if (error) {
          callback(stderr);
        } else {
          winston.profile('test of repository git pulling');
          logger.info(stdout);
          callback(null);
        }
      });
    }
  ],
    function (err, result) {
      if (err) logger.error(err);
      if (err) throw err;
      else rsync(value, callback);
    }
  )
  ;
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



