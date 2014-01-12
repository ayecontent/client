'use strict';

var winston = require('winston');
var path = require('path');
var stackTrace = require('stack-trace');

function prefixLog() {
    var file, frame, line, method;
    frame = stackTrace.get()[11];
    file = path.basename(frame.getFileName());
    line = frame.getLineNumber();
    method = frame.getFunctionName() ? frame.getFunctionName() : '(Object.<anonymous>)';
    return '' + file + ':' + line + '' in '' + method + '()';
}

function makeLogger() {
    //Transports configurations
    var transports = [
        new (winston.transports.Console)({
            timestamp: function () {
                return new Date().toString() + ' ' + prefixLog();
            },
            colorize: true,
            level: 'debug',
            handleExceptions: true
        }),
        new (winston.transports.File)({
            timestamp: function () {
                return new Date().toString() + ' ' + prefixLog();
            },
            filename: path.resolve(__dirname, '../log/data.log'),
            json: false,
            level: 'debug',
            handleExceptions: true
        })
    ];
    return new winston.Logger({ transports: transports });
}

module.exports = makeLogger();


