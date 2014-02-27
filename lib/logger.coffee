"use strict"

winston = require "winston"
path = require "path"
fs = require "fs-extra"
moment = require "moment"

timestamp = () ->
  moment(new Date).format "YYYY-MM-DD HH:mm:ss,SSS"
  #2014-01-02 01:53:41,274

class Logger extends winston.Logger
  constructor: () ->
    logFolder = path.resolve(__dirname, "../log")
    fs.mkdirpSync(logFolder)
    logFilePath = path.join(logFolder, "client.log")
    @transports = [
      new winston.transports.Console(
        timestamp: timestamp,
        colorize: true,
        level: "debug" #if ENV == "development" then "debug" else "error",
        handleExceptions: true
      ),
      new winston.transports.DailyRotateFile(
        timestamp: timestamp,
        filename: logFilePath,
        json: false,
        level: "debug" #if ENV == "development" then "debug" else "error",
        handleExceptions: true
      )
    ]
    super {transports: @transports}


module.exports = Logger