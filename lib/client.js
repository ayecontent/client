'use strict';

var http = require("http");
var options = require("./options");

function pool() {
  http.get(options.server,
    function (res) {
      console.log("Got response: " + res.statusCode);
      res.on('data', function (data) {

      });

      res.on('end', function (data) {
        console.log("end, start new");
        setTimeout(function () {
          pool();
        }, 1000);
      });

    }).on('error', function (e) {
      console.log("Got error: " + e.message);
    });
}
pool();
