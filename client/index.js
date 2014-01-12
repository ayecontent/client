'use strict';

module.exports = function (options) {

    require('../socket')(options).start();
    require('./autolocalsync')(options).start();

    var client = {};

    return client;
};
