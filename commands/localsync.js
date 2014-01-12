'use strict';

var Rsync = require('rsync');
var _ = require('lodash');
var fs = require('fs-extra');
var winston = require('winston');
var logger = require('../lib/log');

var rsync = new Rsync()
    .flags('avz')
    .set('delete')
    .exclude(['.git*', '.stop-content-delivery', '.stop-periodic-sync', '.start-content-delivery']);


exports.localSync = function localSync(options, callback) {
    fs.mkdirsSync(options.sourceFolder);
    fs.mkdirsSync(options.destFolder);

    rsync.source(options.sourceFolder)
        .destination(options.destFolder);

    options.profiling && winston.profile('Rsync-Profile-Test');
    rsync.execute(
        function (error, code, cmd) {
            logger.info('tried to do local rsync; result: ' + code);
            error && logger.info('tried to do local rsync; result output: ' + code + '; error result: ' + error);
            options.profiling && winston.profile('Rsync-Profile-Test');
            callback('success');
        }, null, function (err) {
            err && logger.error('tried to do local rsync; error result: ' + err.message);
            callback('error');
        }
    );
};

