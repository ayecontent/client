'use strict';

var winston = require('winston');
var path = require('path');
var stackTrace = require('stack-trace');

var stackTraceLevel = 11;

module.exports = makeLogger();

function log() {
  var file, frame, line, method;
  frame = stackTrace.get()[stackTraceLevel];
  file = path.basename(frame.getFileName());
  line = frame.getLineNumber();
  method = frame.getFunctionName();
  return "" + file + ":" + line + " in " + method + "()"
};

function makeLogger() {
  var transports = [
    new (winston.transports.Console)({timestamp: function () {
      return new Date().toString() + ' ' + log();
    }, colorize: true, level: 'debug'}),
    new (winston.transports.File)({ timestamp: function () {
      return new Date().toString() + ' ' + log();
    }, filename: path.resolve(__dirname, '../log/data.log'), json: false, level: 'debug'  })
  ]
  return new winston.Logger({ transports: transports });
}