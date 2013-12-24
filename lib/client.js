'use strict';

var http = require("http");
var fs = require("fs");
var options = require("./options");
var Rsync = require('rsync');

function pool() {
  http.get(options.server + ':' + options.port,
    function (res) {
      console.log("Got connection: " + res.statusCode);
      res.on('data', function (data) {
        console.log(data.toString());
        fs.stat(options.sourceFolder, function (err, stats) {
          if (err) throw err;
          console.log(stats);
          console.log(stats.isDirectory());

          var rsync = new Rsync()
            .shell('ssh')
            .flags('avrz')
            .source(options.sourceFolder)
            .destination(options.destFolder);

          // execute with stream callbacks
          rsync.execute(
            function (error, code, cmd) {
              console.log(error, code, cmd);
            }, function (data) {
              console.log(data.toString());
            }, function (data) {
              console.log(data.toString());
            }
          );

        });
      });

      res.on('end', function (data) {
        console.log("end request, restart");
        setTimeout(function () {
          pool();
        }, 1000);
      });

    }).on('error', function (e) {
      console.log("Got error: " + e.message);
    });
}
pool();
