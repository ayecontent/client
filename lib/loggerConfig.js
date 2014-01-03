'use strict';

var winston = require('winston');

module.exports = {
  transports: [
    new (winston.transports.Console)(),
    new (winston.transports.File)({ filename: 'data.log' })
  ]
}