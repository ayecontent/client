module.exports = require("./lib/client.js");

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