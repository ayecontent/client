'use strict';

var commands = require('../commands');

module.exports = function (options) {

    require('../socket')(options).start();
    require('./autolocalsync')(options).start();

    new commands.GitSyncCommand(options, function (result) {
    }).execute();

    var client = {};

    return client;
};
