'use strict';

var Rsync = require('rsync');
//var git = require('gift');
var fs = require("fs");
var winston = require('winston');
var logger = new (winston.Logger)(require('./loggerConfig'));
var clientOptions = require('./options');
var async = require('async');

var git = require('nodegit'),
  path = require('path');

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

var deleteFolderRecursive = function(path) {
  if( fs.existsSync(path) ) {
    fs.readdirSync(path).forEach(function(file,index){
      var curPath = path + "/" + file;
      if(fs.statSync(curPath).isDirectory()) { // recurse
        deleteFolderRecursive(curPath);
      } else { // delete file
        fs.unlinkSync(curPath);
      }
    });
    fs.rmdirSync(path);
  }
};

function fullSyncFunc(value, callback) {
  logger.info('gitCommand');
  async.waterfall([
    function (callback) {
      git.Repo.open(path.resolve(clientOptions.sourceFolder, '.git'), function (error, repo) {
        if (error) {
          logger.error(error.message);
          deleteFolderRecursive(clientOptions.sourceFolder);
          winston.profile('test of repository git cloning');
          git.Repo.clone(clientOptions.gitUrl, clientOptions.sourceFolder, null, function (error, clonedRepo) {
            if (error) {
              logger.error(error.message);
              callback(error);
            } else {
              winston.profile('test of repository git cloning');
              callback(null, clonedRepo);
            }
          });
        } else {
          callback(null, repo);
        }
      });
    },
    function (repo, callback) {

      var remote = repo.getRemote("origin");
      winston.profile('test of repository git connection');
      fs.openSync(path.resolve(clientOptions.sourceFolder, clientOptions.stopContentDeliveryFile), 'w')
      remote.connect(0, function (error) {
        if (error) callback(error);
        winston.profile('test of repository git connection');
        winston.profile('test of repository git fetching');
        remote.download(function(data){
          logger.info(data);
        }, function (error) {
          if (error) logger.error(error.message);
          fs.unlinkSync(path.resolve(clientOptions.sourceFolder, clientOptions.stopContentDeliveryFile));
          if (error) callback(error);
          winston.profile('test of repository git fetching');
          logger.info("repository has fetched!");
          callback(null, 'done');
        })
      });

//      var repo = git(value.sourceFolder);

//      repo.remote_fetch('origin/master', function (err) {
//        winston.profile('test of repository git pooling');
//        if (err) {
//          logger.error('git repository sync error!');
//          callback(err);
//        } else {
//          callback(null, err);
//        }
//      });
    }
  ],
    function (err, result) {
      if (err) logger.error(err.message);
      if (err) throw err;
      rsync(value, callback);
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



