"use strict";



#var _ = require("lodash");
#var async = require("async");
#var util = require("util");
#
#
#var executionQueue = async.queue(function (command, callback) {
#command.func(command.options, function (result) {
#callback(result); / / internal queue"
#s callback for async
#command.callback(result);
#/ / external callback
#});
#});
#
#exports.Command = function (func, options, callback
#)
#{
#this.func = func;
#this.options = options;
#this.callback = callback;
#};
#
#exports.Command.prototype.execute = function () {
#executionQueue.push(this);
#};
#
#exports.GitSyncCommand = _.partial(exports.Command, require("commands/gitsync").gitSync);
#util.inherits(exports.GitSyncCommand, exports.Command);
#
#exports.LocalSyncCommand = _.partial(exports.Command, require("commands/localsync").localSync);
#util.inherits(exports.LocalSyncCommand, exports.Command);