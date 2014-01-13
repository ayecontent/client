'use strict';

var Rsync = require('rsync');
var _ = require('lodash');
var fs = require('fs-extra');
var winston = require('winston');
var logger = require('../lib/log');
var async = require('async');
var path = require('path');
var exec = require('child_process').exec;
var localSync = require('./localsync').localSync;

exports.gitSync = function (options, commandCallback) {
    var stopContentDeliveryPath = path.resolve(options.sourceFolder, options.stopContentDeliveryFile);

    function cloneRepository(callback) {
        logger.info('start to clone git repository; it may take some time');
        options.profiling && winston.profile('Git-Clone-Profile-Test');
        exec('git clone ' + options.gitUrl + ' ' + options.sourceFolder, function (error, stdout, stderr) {
            stdout && logger.info('tried to clone git repository; result output: ' + stdout);
            if (stderr) {
                return callback(new Error(stderr));
            } else {
                options.profiling && winston.profile('Git-Clone-Profile-Test');
                return callback(null, 'success');
            }
        });
    }

    function checkRepositoryStatus(callback) {
        options.profiling && winston.profile('Git-Status-Profile-Test');
        exec('git --git-dir=' + path.resolve(options.sourceFolder, '.git') + ' --work-tree=' + options.sourceFolder + ' status', function (error, stdout, stderr) {
            stdout && logger.info('checked git repository status; result output: ' + stdout);
            stderr && logger.error('checked git repository status; error output: ' + stderr);
            options.profiling && winston.profile('Git-Status-Profile-Test');
            if (!stderr) {
                return callback(null, 'success');
            } else {
                fs.removeSync(options.sourceFolder);
                fs.mkdirsSync(options.sourceFolder);
                cloneRepository(callback);
            }
        });
    }

    function pullRepository(callback) {
        options.profiling && winston.profile('Git-Pool-Profile-Test');
        exec('git --git-dir=' + path.resolve(options.sourceFolder, '.git') + ' --work-tree=' + options.sourceFolder + ' pull', function (error, stdout, stderr) {
            stdout && logger.info('tried to pull git repository; result output: ' + stdout);
            if (!stderr) {
                options.profiling && winston.profile('Git-Pool-Profile-Test');
                return callback(null, 'success');
            } else {
                return callback(new Error(stderr));
            }
        });
    }

    async.waterfall(
        [
            function (callback) {
                if (fs.existsSync(stopContentDeliveryPath)) {
                    return callback(null, 'success');
                }
                fs.mkdirsSync(options.sourceFolder);
                checkRepositoryStatus(callback);
            },
            function (result, callback) {
                if (fs.existsSync(stopContentDeliveryPath)) {
                    return callback(null, 'success');
                }
                pullRepository(callback);
            }
        ],
        function (err, result) {
            if (err) {
                logger.error(err.message);
                commandCallback && commandCallback(err.message);
            }
            else {
                localSync(options, commandCallback);
            }
        }
    );
};