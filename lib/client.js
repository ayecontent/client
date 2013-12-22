'use strict';

var http = require("http");
var options = require("./options");

function pool() {
  http.get(options.server,
    function (res) {
      console.log("Got connection: " + res.statusCode);
      res.on('data', function (data) {
        console.log(data.toString());
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
