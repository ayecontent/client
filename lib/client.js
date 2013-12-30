'use strict';

var http = require("http");
var fs = require("fs");
var clientOptions = require("./options");
var Executor = new require("./executor")();
var command = require("./commands");
var log = require('util').log;

function pool() {

  var poolingOptions = {
    host: clientOptions.server,
    port: clientOptions.port,
    path: '/',
    method: 'GET'
  };

  var acknowledgeOptions = {
    host: clientOptions.server,
    port: clientOptions.port,
    path: '/',
    method: 'POST'
  };

  var poolingRequest = http.request(poolingOptions, function (res) {
    res.setEncoding('utf8');

    res.on('data', function (chunk) {
      Executor.execute(new command.GitCommand(clientOptions, function (result) {
        var acknowledgeRequest = http.request(acknowledgeOptions);
        log(result);
        acknowledgeRequest.write(result + '\n');
        acknowledgeRequest.end();
      }));
    });


    res.on('end', function (data) {
      poolingRequest.end();
//      log("end request, restart");
      setTimeout(function () {
        pool();
      }, 1000);
    });
  });

  poolingRequest.on('error', function (e) {
    log("Got error: " + e.message);
    setTimeout(function () {
      pool();
    }, 3000);
  });
  poolingRequest.end();
}
pool();
