//Logging on start
var logger = require('./lib/log');

logger.info('----------------------');
logger.info('START');
logger.info('----------------------');

//Apply patch of modules
require("./patch");

var options = require("./options");

//Run client's code
var client = require("./client")(options);

client.autoLocalSync();

var commands = require('./commands');

new commands.GitSyncCommand(options, function (result) {
}).execute();

//Forever monitor option for running

//var forever = require('forever-monitor');
//
//var child = new (forever.Monitor)('./lib/client.js', {
//   max: 10,
//   silent: false,
//   options: []
//});
//
//child.on('exit', function () {
//   console.log('client.js has exited after 3 restarts');
//});
//
//child.start();