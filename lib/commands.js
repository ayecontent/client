'use strict';

var Rsync = require('rsync');
var log = require('util').log;
var git = require('gift');
var clientOptions = require("./options");
var fs = require("fs");


var command = module.exports = {};

function rsync(value, callback) {
  log('rsyncCommand');

  var rsync = new Rsync()
    .flags('avrz')
    .source(value.sourceFolder)
    .destination(value.destFolder);

  // execute with stream callbacks
  rsync.execute(
    function (error, code, cmd) {
      console.log('All done executing', code);
      callback(code);
    }, function (data) {
//      log(data.toString());
    }, function (data) {
//      log(data.toString());
    }
  );

}

function gitFunc(value, callback) {
  log('gitCommand');

  fs.stat(value.sourceFolder + '.git/', function (err, stats) {
    if (!err) {
      var gitExists = stats.isDirectory();
    }
    if (!gitExists || err) {
      git.clone(value.gitUrl, value.sourceFolder, function (err) {
        if (err) {
          log('clone error!');
          throw err;
        }
      });
    }
    var repo = git(value.sourceFolder);
    repo.sync('origin', 'master', function (err) {
      if (err) {
        log('sync error!');
        throw err;
      } else {
        rsync(value, callback);
      }
    });
  });

}

command.Command = function (execute, value, callback) {
  this.execute = execute;
  this.value = value;
  this.callback = callback;
}

command.RsyncCommand = function (value, callback) {
  return new command.Command(rsync, value, callback);
};

command.GitCommand = function (value, callback) {
  return new command.Command(gitFunc, value, callback);
};

