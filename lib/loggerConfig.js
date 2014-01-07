'use strict';

var winston = require('winston');
var path = require('path');


module.exports = {
  transports: [
    new (winston.transports.Console)({timestamp: true, colorize: true, level: 'debug'}),
    new (winston.transports.File)({ filename: path.resolve(__dirname, '../log/data.log'), json: false, level: 'debug'  })
  ]
}