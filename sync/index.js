// Generated by CoffeeScript 1.7.1
"use strict";
var Rsync, Sync, async, events, exec, fs, http, path, stream, util,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

fs = require("fs-extra");

async = require("async");

path = require("path");

exec = require('child_process').exec;

events = require("events");

util = require("util");

http = require("http");

stream = require("stream");

Rsync = require("rsync");

Sync = (function(_super) {
  __extends(Sync, _super);

  Sync.prototype.COMMANDS = {
    "sync-http": "syncHttp",
    "sync-backup": "syncGit",
    "sync-local": "syncLocal",
    "sync-reset": "syncReset"
  };

  Sync.prototype.FILES = {
    stopContentDelivery: '.stop-content-delivery',
    stopPeriodicSync: '.stop-periodic-sync',
    startContentDelivery: '.start-content-delivery'
  };

  function Sync(args) {
    this.config = args.config, this.logger = args.logger;
    this._source = path.join(this.config.get("basepath"), "backup");
    this._dest = this.config.get("folder:dest");
    this._flags = {};
    this._switchURLattempts = 0;
    this._gitDir = path.join(this._source, '.git');
    this._gitUrl = (this.config.get("git:sync") === "ssh" ? this.config.get("git:ssh") : this.config.get("git:http"));
    this._rsync = new Rsync({
      debug: true
    }).flags("avz").set("delete").exclude(this.config.get("syncIgnore"));
    this._queue = async.queue((function(_this) {
      return function(command, callback) {
        var commandName;
        commandName = _this.COMMANDS[command.name];
        return _this[commandName](command, callback);
      };
    })(this));
  }

  Sync.initFolders = function(folders, callback) {
    return async.each(folders, function(folder, callback) {
      return fs.mkdirp(folder, callback);
    }, function(err) {
      return callback(err);
    });
  };

  Sync.prototype._switchURL = function(callback) {
    this.config.set("git:sync", (this.config.get("git:sync") === "ssh" ? "http" : "ssh"));
    this._switchURLattempts++;
    return this.config.save((function(_this) {
      return function(err) {
        if (err != null) {
          return callback(err);
        }
        return _this._setURL(callback);
      };
    })(this));
  };

  Sync.prototype._setURL = function(callback) {
    this._gitUrl = (this.config.get("git:sync") === "ssh" ? this.config.get("git:ssh") : this.config.get("git:http"));
    this.logger.info("Start set-url command'. Command: '" + (this._wrapGit("git set-url origin '" + this._gitUrl + "'")) + "'");
    this.logger.time("GIT SET-URL command");
    return this._execGit("git remote set-url origin " + this._gitUrl, (function(_this) {
      return function(err, stdout, stderr) {
        _this.logger.info("GIT SET-URL command result: '" + (stdout !== "" ? stdout : stderr) + "'. " + (_this.logger.timeEnd("GIT SET-URL command")));
        return callback(err);
      };
    })(this));
  };

  Sync.prototype.updateFlagIndicators = function(callback) {
    var flag, flags;
    flags = (function() {
      var _results;
      _results = [];
      for (flag in this.FILES) {
        _results.push(flag);
      }
      return _results;
    }).call(this);
    return async.each(flags, (function(_this) {
      return function(flag, callback) {
        return fs.exists(path.join(_this._dest, _this.FILES[flag]), function(exists) {
          _this._flags[flag] = exists;
          return callback();
        });
      };
    })(this), function(err) {
      return callback(err);
    });
  };

  Sync.prototype.pushCommand = function(command, callback) {
    this.logger.time("Command " + (util.inspect(command, {
      depth: 30
    })) + " in queue");
    return this._queue.push(command, callback);
  };

  Sync.prototype._syncRepositoryType = function(callback) {
    return exec("git config --get remote.origin.url", {
      cwd: this._source,
      timeout: this.config.get("execTimeout")
    }, (function(_this) {
      return function(err, stdout, stderr) {
        var gitURL, repositorySync;
        repositorySync = /^http/i.test(stdout) ? "http" : "ssh";
        gitURL = stdout.trim();
        if (_this.config.get("git:sync") !== repositorySync || gitURL !== _this._gitUrl) {
          return _this._setURL(callback);
        } else {
          return callback(err);
        }
      };
    })(this));
  };

  Sync.prototype._checkRepositoryStatus = function(callback) {
    this.logger.info("Check GIT status of '" + this._source + "'. Command: '" + (this._wrapGit("git status")) + "'");
    this.logger.time("GIT STATUS command");
    return this._execGit("git status", (function(_this) {
      return function(err, stdout, stderr) {
        _this.logger.info("GIT STATUS command result: '" + (stdout !== "" ? stdout : stderr) + "'. " + (_this.logger.timeEnd("GIT STATUS command")));
        if (stderr !== "") {
          return callback(null, "GIT STATUS: NOT_GIT");
        } else {
          return _this._syncRepositoryType(function(err) {
            if (err != null) {
              return callback(err);
            } else {
              return callback(err, "GIT STATUS: GIT");
            }
          });
        }
      };
    })(this));
  };

  Sync.prototype._cloneRepository = function(callback) {
    this.logger.info("Cleaning backup directory '" + this._source + "'");
    return fs.remove(this._source, (function(_this) {
      return function(err) {
        if (err != null) {
          return callback(err);
        }
        return fs.mkdirp(_this._source, function(err) {
          _this.logger.info("Start GIT CLONE command. Clone into '" + _this._source + "'. Command: '" + (_this._wrapGit("git clone " + _this._gitUrl + " " + _this._source)) + "'");
          _this.logger.time("GIT CLONE command");
          return _this._execGit("git clone " + _this._gitUrl + " " + _this._source, function(err, stdout, stderr) {
            _this.logger.info("GIT CLONE command result: '" + (stdout !== "" ? stdout : stderr) + "'. " + (_this.logger.timeEnd("GIT CLONE command")));
            if (stderr !== "") {
              return callback(err);
            } else {
              return callback(null);
            }
          });
        });
      };
    })(this));
  };

  Sync.prototype._wrapGit = function(command) {
    return "GIT_SSH=" + (path.join(this.config.get("basePath"), this.config.get("git:sshShell"))) + " " + command;
  };

  Sync.prototype._execGit = function(command, callback) {
    return exec((this.config.get("git:sync") === "ssh" ? this._wrapGit(command) : command), {
      cwd: this._source,
      timeout: this.config.get("execTimeout")
    }, callback);
  };

  Sync.prototype._pullRepository = function(callback) {
    this.logger.info("Start GIT CLEAN command. Command: '" + (this._wrapGit("git clean -xdf")) + "'");
    this.logger.time("GIT CLEAN command");
    return this._execGit("git clean -xdf", (function(_this) {
      return function(err, stdout, stderr) {
        _this.logger.info("GIT CLEAN command result: '" + (stdout !== "" ? stdout : stderr) + "'. " + (_this.logger.timeEnd("GIT CLEAN command")));
        if (stderr !== "") {
          return callback(err);
        }
        _this.logger.info("Start GIT RESET command. Command: '" + (_this._wrapGit("git reset --hard origin/master")) + "'");
        _this.logger.time("GIT RESET command");
        return _this._execGit("git reset --hard origin/master", function(err, stdout, stderr) {
          _this.logger.info("GIT RESET command result: '" + (stdout !== "" ? stdout : stderr) + "'. " + (_this.logger.timeEnd("GIT RESET command")));
          if (stderr !== "") {
            return callback(err);
          }
          _this.logger.info("Start GIT PULL command. Command: '" + (_this._wrapGit("git pull --ff")) + "'");
          _this.logger.time("GIT PULL command");
          return _this._execGit("git pull --ff", function(err, stdout, stderr) {
            _this.logger.info("GIT PULL command result: '" + (stdout !== "" ? stdout : stderr) + "'. " + (_this.logger.timeEnd("GIT PULL command")));
            if (stderr !== "") {
              if (_this._switchURLattempts < 1) {
                return _this._switchURL(function(err) {
                  if (err != null) {
                    return callback(err);
                  }
                  return _this._pullRepository(callback);
                });
              } else {
                _this.config.set("git:disabled", true);
                return callback(null, "GIT PULL: FAIL. SYNC-GIT was disabled");
              }
            } else {
              return callback(null, "GIT PULL: SUCCESS");
            }
          });
        });
      };
    })(this));
  };

  Sync.prototype.syncGit = function(command, callback) {
    this.logger.info("Start SYNC-GIT command.");
    this.logger.time("SYNC-GIT command");
    return async.parallel([
      (function(_this) {
        return function(callback) {
          return Sync.initFolders([_this._source, _this._dest], callback);
        };
      })(this), this.updateFlagIndicators.bind(this)
    ], (function(_this) {
      return function(err) {
        var message;
        if (err != null) {
          return callback(err);
        }
        if (!(_this._flags.stopContentDelivery || _this.config.get("git:disabled"))) {
          return async.series([
            function(callback) {
              return _this._checkRepositoryStatus(function(err, result) {
                if (err != null) {
                  return callback(err);
                }
                if (result === "GIT STATUS: NOT_GIT") {
                  return _this._cloneRepository(callback);
                } else {
                  return callback(null, result);
                }
              });
            }, _this._pullRepository.bind(_this), function(callback) {
              return _this.syncLocal(command, callback);
            }
          ], function(err, result) {
            _this.logger.info(_this.logger.timeEnd("SYNC-GIT command"));
            return callback(err, result);
          });
        } else {
          message = "SYNC-GIT is disabled: " + (_this._flags.stopContentDelivery ? 'Content delivery file was found.' : 'Disabled in config');
          _this.logger.info(message);
          return callback(null, message);
        }
      };
    })(this));
  };

  Sync.prototype.syncHttp = function(command, callback) {
    this.logger.info("Start SYNC-HTTP command.");
    this.logger.time("SYNC-HTTP command");
    return async.parallel([
      (function(_this) {
        return function(callback) {
          return Sync.initFolders([_this._source, _this._dest], callback);
        };
      })(this), this.updateFlagIndicators.bind(this)
    ], (function(_this) {
      return function(err) {
        var changeSet, formUrl;
        if (err != null) {
          return callback(err);
        }
        if (!_this._flags.stopContentDelivery) {
          command.host = '54.200.235.215';
          formUrl = "http://" + command.host + ":" + command.port;
          changeSet = command.snapshot.changeSet;
          return async.parallel([
            function(callback) {
              return async.eachLimit(changeSet.added.concat(changeSet.modified), 5, function(added, callback) {
                var dirname;
                dirname = path.dirname(path.join(_this._source, _this.config.get("client:contentRegion"), added.rp));
                return fs.mkdirp(dirname, function() {
                  var req, writeStream;
                  _this.logger.info("Start Download '" + formUrl + added.dp + "'");
                  _this.logger.time("Download '" + added.rp + "'");
                  writeStream = fs.createWriteStream(path.join(_this._source, _this.config.get("client:contentRegion"), added.rp));
                  req = http.request("" + formUrl + added.dp, function(res) {
                    if (res.statusCode === 200) {
                      res.pipe(writeStream);
                      return;
                    }
                    return writeStream.emit('error', new Error(http.STATUS_CODES[res.statusCode]));
                  });
                  req.end();
                  req.on('error', function(err) {
                    return writeStream.emit('error', err);
                  });
                  writeStream.on('error', function(err) {
                    return writeStream.emit('close', err);
                  });
                  return writeStream.on('close', function(err) {
                    if (err != null) {
                      _this.logger.info("Download of " + added.rp + " is FAILED. " + (_this.logger.timeEnd("Download '" + added.rp + "'")));
                      return callback(err);
                    } else {
                      _this.logger.info("Download of " + added.rp + " is DONE. " + (_this.logger.timeEnd("Download '" + added.rp + "'")));
                      return callback(null, "DOWNLOAD of '" + added.rp + "': SUCCESS");
                    }
                  });
                });
              }, callback.bind(_this));
            }, function(callback) {
              return async.eachLimit(changeSet.deleted, 5, function(deleted, callback) {
                _this.logger.info("Delete '" + (path.join(_this._source, _this.config.get("client:contentRegion"), deleted)) + "'");
                return fs.remove(path.join(_this._source, _this.config.get("client:contentRegion"), deleted), function(err) {
                  return callback(err, "DELETION of '" + deleted + "': SUCCESS");
                });
              }, callback.bind(_this));
            }
          ], function(err) {
            _this.logger.info("SYNC-HTTP command is DONE. " + (_this.logger.timeEnd("SYNC-HTTP command")));
            if (typeof err === "function" ? err(null) : void 0) {
              return callback(err);
            }
            return _this.syncLocal(command, callback);
          });
        } else {
          _this.logger.info("Content delivery file is found.");
          return callback(null, "Content delivery file is found.");
        }
      };
    })(this));
  };

  Sync.prototype.syncLocal = function(command, callback) {
    this.logger.info("Start LOCAL-SYNC command. Rsync from '" + this._source + "' to '" + this._dest + "'.");
    this.logger.time("LOCAL-SYNC command");
    return async.parallel([
      (function(_this) {
        return function(callback) {
          return Sync.initFolders([_this._source, _this._dest], callback);
        };
      })(this), this.updateFlagIndicators.bind(this)
    ], (function(_this) {
      return function(err) {
        if (err != null) {
          return callback(err);
        }
        if (!_this._flags.stopContentDelivery) {
          _this._rsync.source(path.join(_this._source, _this.config.get("client:contentRegion") + "/")).destination(_this._dest);
          return _this._rsync.execute(function(err, resultCode) {
            if (err != null) {
              return callback(err, resultCode);
            }
            _this.logger.info("LOCAL-SYNC command resultCode: '" + resultCode + "'. " + (_this.logger.timeEnd("LOCAL-SYNC command")));
            return callback(null, "LOCAL-SYNC: SUCCESS");
          });
        } else {
          _this.logger.info("Content delivery file is found.");
          return callback(null, "Content delivery file is found.");
        }
      };
    })(this));
  };

  Sync.prototype._logChanges = function(result, key) {
    if (this._lastKey !== key) {
      this.logger.info("" + (key != null ? "" + key + " is found. " : "") + result);
      return this._lastKey = key;
    }
  };

  Sync.prototype.startAutoSync = function() {
    this.logger.info("Start AUTO-SYNC process");
    if (this.intervalId == null) {
      return this.intervalId = setInterval((function(_this) {
        return function() {
          return _this._syncAuto();
        };
      })(this), 10000);
    }
  };

  Sync.prototype.stopAutoSync = function() {
    this.logger.info("Stop AUTO-SYNC process");
    if (this.intervalId != null) {
      clearInterval(this.intervalId);
      return delete this.intervalId;
    }
  };

  Sync.prototype.syncReset = function(callback) {
    this.logger.info("SYNC-RESET command started.");
    this.logger.time("SYNC-RESET command");
    this._queue.tasks.length = 0;
    return this.pushCommand({
      name: "sync-backup"
    }, (function(_this) {
      return function(err) {
        if (err != null) {
          return typeof callback === "function" ? callback(err) : void 0;
        }
        return setTimeout(function() {
          return _this.pushCommand({
            name: "sync-backup"
          }, function(err) {
            if (err != null) {
              return typeof callback === "function" ? callback(err) : void 0;
            }
            _this.logger.info("SYNC-RESET command is DONE. " + (_this.logger.timeEnd("SYNC-RESET command")));
            return typeof callback === "function" ? callback(null, "SYNC-REST: SUCCESS") : void 0;
          });
        }, 10000);
      };
    })(this));
  };

  Sync.prototype._syncAuto = function() {
    return this.updateFlagIndicators((function(_this) {
      return function(err) {
        if (err != null) {
          return _this.logger.error(util.inspect(err, {
            depth: 30
          }));
        } else if (_this._flags.stopContentDelivery) {
          return _this._logChanges('Content delivery stopped.', 'stopContentDelivery');
        } else {
          if (_this._lastKey === "stopContentDelivery") {
            _this._logChanges('Content delivery restarted.');
            return _this.syncReset();
          } else if (_this._flags.stopPeriodicRsync === true) {
            return _this._logChanges('Periodic LOCAL-SYNC stopped.', 'stopPeriodicRsync');
          } else {
            _this._logChanges('Periodic LOCAL-SYNC started.');
            return _this.pushCommand({
              name: "sync-local"
            }, function(err) {
              if (err != null) {
                return _this.logger.error(util.inspect(err, {
                  depth: 30
                }));
              }
            });
          }
        }
      };
    })(this));
  };

  module.exports = Sync;

  return Sync;

})(events.EventEmitter);
