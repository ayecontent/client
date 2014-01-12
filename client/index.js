'use strict';
var fs = require('fs');
var path = require('path');
var commands = require('../commands');
var logger = require('../lib/log');

module.exports = function (options) {

    require('../socket')(options);
    require('./autolocalsync')(options).start();

    var client = {};

    return client;
};
