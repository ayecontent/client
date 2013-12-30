'use strict';

var log = require('util').log;

var Executor = function () {
  var commands = [];

  function action(command) {
    var name = command.execute.toString();
    return name.charAt(0).toUpperCase() + name.slice(1);
  }

  return {
    execute: function (command) {
      command.execute(command.value, command.callback);
      commands.push(command);
//      log(action(command) + ": " + command.value);
    }
  }
}

exports = module.exports = Executor;