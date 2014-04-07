"use strict"

fs = require "fs-extra"

async = require "async"

path = require "path"
exec = require('child_process').exec
events = require "events"
util = require "util"
http = require "http"
stream = require "stream"

Rsync = require "rsync"

class Sync extends events.EventEmitter

  COMMANDS:
    "sync-http": "syncHttp"
    "sync-backup": "syncGit"
    "sync-local": "syncLocal"
    "sync-reset": "syncReset"

  constructor: (args)->
    {@config, @logger} = args
    @_source = @config.get "folder:backup"
    @_dest = @config.get "folder:dest"
    @_flags = {}
    @_switchURLattempts = 0
    @_gitDir = path.join @_source, '.git'
    @_gitUrl = (if @config.get("git:sync") is "ssh" then @config.get("git:ssh") else @config.get("git:http"))
    @_rsync = new Rsync({debug: true}).flags("avz").set("delete").exclude(@config.get("syncIgnore"))
    @_queue = async.queue (command, callback) =>
      commandName = @COMMANDS[command.name]
      @[commandName](command, callback)

  @initFolders: (folders, callback) ->
    async.each folders
    , (folder, callback) ->
      fs.mkdirp folder, callback
    , (err) ->
      return callback(err)

  _switchURL: (callback)->
    @config.set("git:sync", (if @config.get("git:sync") is "ssh" then "http" else "ssh"))
    @_switchURLattempts++
    @config.save (err) =>
      if err? then return callback(err)
      @_setURL callback

  _setURL: (callback) ->
    @_gitUrl = (if @config.get("git:sync") is "ssh" then @config.get("git:ssh") else @config.get("git:http"))
    @logger.info "Start set-url command'. Command: '#{@_wrapGit "git set-url origin '#{@_gitUrl}'"}'"
    @logger.time("GIT SET-URL command")
    @_execGit "git remote set-url origin #{@_gitUrl}", (err, stdout, stderr) =>
      @logger.info "GIT SET-URL command result: '#{if stdout isnt "" then stdout else stderr}'. #{@logger.timeEnd("GIT SET-URL command")}"
      callback(err)

  updateFlagIndicators: (callback)->
    indicators = @config.get "indicator"
    flags = (flag for flag of indicators)
    async.each flags
    , (flag, callback) =>
      fs.exists path.join(@_dest, indicators[flag]), (exists) =>
        @_flags[flag] = exists
        return callback()
    , (err) ->
      return callback(err)

  pushCommand: (command, callback) ->
    @logger.time ("Command #{util.inspect(command, {depth: 30})} in queue")
    @_queue.push(command, callback)

#  _testRepository: (callback) ->
#    @logger.info "Check GIT ls-remote of '#{@_source}'. Command: '#{@_wrapGit "git ls-remote -h origin HEAD"}'"
#    @logger.time("GIT LS-REMOTE command")
#    @_syncRepositoryType (err) =>
#      if err? then return callback(err)
#      @_execGit "git ls-remote -h origin HEAD", (err, stdout, stderr) =>
#        @logger.info "GIT LS-REMOTE command result: '#{if stdout isnt "" then stdout else stderr}'. #{@logger.timeEnd("GIT LS-REMOTE command")}"
#        if stderr isnt ""
#          @_switchURL callback
#        else
#          callback(err)

  _syncRepositoryType: (callback) ->
    exec "git config --get remote.origin.url", {cwd: @_source, timeout: @config.get("execTimeout")}, (err, stdout, stderr) =>
      repositorySync = if (/^http/i).test(stdout) then "http" else "ssh"
      gitURL = stdout.trim()
      if @config.get("git:sync") isnt repositorySync or gitURL isnt @_gitUrl
        @_setURL callback
      else
        callback(err)

  _checkRepositoryStatus: (callback) ->
    @logger.info "Check GIT status of '#{@_source}'. Command: '#{@_wrapGit "git status"}'"
    @logger.time("GIT STATUS command")
    @_execGit "git status", (err, stdout, stderr) =>
      @logger.info "GIT STATUS command result: '#{if stdout isnt "" then stdout else stderr}'. #{@logger.timeEnd("GIT STATUS command")}"
      if stderr isnt "" then return callback(null, "GIT STATUS: NOT_GIT")
      else
        @_syncRepositoryType (err) =>
          if err? then return callback(err)
          else callback(err, "GIT STATUS: GIT")

  _cloneRepository: (callback) ->
    @logger.info "Cleaning backup directory '#{@_source}'"
    fs.remove @_source, (err) =>
      if err? then return callback(err)
      fs.mkdirp @_source, (err) =>
        @logger.info "Start GIT CLONE command. Clone into '#{@_source}'. Command: '#{@_wrapGit("git clone #{@_gitUrl} #{@_source}")}'"
        @logger.time("GIT CLONE command")
        @_execGit "git clone #{@_gitUrl} #{@_source}", (err, stdout, stderr) =>
          @logger.info "GIT CLONE command result: '#{if stdout isnt "" then stdout else stderr}'. #{@logger.timeEnd("GIT CLONE command")}"
          if stderr isnt "" then return callback(err)
          else return callback(null)

  _wrapGit: (command) ->
    "GIT_SSH=#{path.join(@config.get("basePath"), @config.get("git:sshShell"))} #{command}"

  _execGit: (command, callback) ->
    exec (if @config.get("git:sync") is "ssh" then @_wrapGit(command) else command), {cwd: @_source, timeout: @config.get("execTimeout")}, callback

  _pullRepository: (callback) ->
    @logger.info "Start GIT CLEAN command. Command: '#{@_wrapGit "git clean -xdf"}'"
    @logger.time("GIT CLEAN command")
    @_execGit "git clean -xdf", (err, stdout, stderr) =>
      @logger.info "GIT CLEAN command result: '#{if stdout isnt "" then stdout else stderr}'. #{@logger.timeEnd("GIT CLEAN command")}"
      if stderr isnt "" then return callback(err)
      @logger.info "Start GIT RESET command. Command: '#{@_wrapGit "git reset --hard origin/master"}'"
      @logger.time "GIT RESET command"
      @_execGit "git reset --hard origin/master", (err, stdout, stderr) =>
        @logger.info "GIT RESET command result: '#{if stdout isnt "" then stdout else stderr}'. #{@logger.timeEnd("GIT RESET command")}"
        if stderr isnt "" then return callback(err)
        @logger.info "Start GIT PULL command. Command: '#{@_wrapGit "git pull --ff"}'"
        @logger.time "GIT PULL command"
        @_execGit "git pull --ff", (err, stdout, stderr) =>
          @logger.info "GIT PULL command result: '#{if stdout isnt "" then stdout else stderr}'. #{@logger.timeEnd("GIT PULL command")}"
          if stderr isnt ""
            if @_switchURLattempts < 1
              @_switchURL (err) =>
                if err? then return callback(err)
                @_pullRepository callback
            else
              @config.set "git:disabled", true
              return callback(null, "GIT PULL: FAIL. SYNC-GIT was disabled")
          else
            return callback(null, "GIT PULL: SUCCESS")

  syncGit: (command, callback) ->
    @logger.info "Start SYNC-GIT command."
    @logger.time("SYNC-GIT command")
    async.parallel [
        (callback) =>
          Sync.initFolders([@_source, @_dest], callback)
      , @updateFlagIndicators.bind(@) ]
    , (err) =>
      if err? then return callback(err)
      if not (@_flags.stopContentDelivery or @config.get "git:disabled")
        async.series [
            (callback)=>
              @_checkRepositoryStatus (err, result) =>
                if err? then return callback(err)
                if result is "GIT STATUS: NOT_GIT" then @_cloneRepository(callback)
                else return callback(null, result)
          , @_pullRepository.bind(@)
          , (callback) =>
              @syncLocal(command, callback)
          ]
        , (err, result) =>
          @logger.info @logger.timeEnd("SYNC-GIT command")
          callback(err, result)
      else
        message = "SYNC-GIT is disabled: #{( if @_flags.stopContentDelivery then 'Content delivery file was found.' else 'Disabled in config')}"
        @logger.info message
        callback(null, message)

  syncHttp: (command, callback)->
    @logger.info "Start SYNC-HTTP command."
    @logger.time("SYNC-HTTP command")
    async.parallel [
        (callback) =>
          Sync.initFolders([@_source, @_dest], callback)
      , @updateFlagIndicators.bind(@)
      ]
    , (err) =>
      if err? then return callback(err)
      if not @_flags.stopContentDelivery
        command.host = '54.200.235.215'
        formUrl = "http://#{command.host}:#{command.port}"
        #        formUrl += "/#{@config.get("client:customerId")}"
        #        formUrl += "/#{@config.get("client:hostId")}"
        #        formUrl += "/#{@config.get("client:contentRegion")}"
        #        formUrl += "/#{command.snapshot.id}"
        changeSet = command.snapshot.changeSet
        async.parallel [
            (callback) =>
              async.eachLimit(changeSet.added.concat(changeSet.modified), 5, (added, callback) =>
                dirname = path.dirname(path.join(@_source, @config.get("client:contentRegion"), added.rp))
                fs.mkdirp dirname, () =>
                  @logger.info("Start Download '#{formUrl}#{added.dp}'")
                  @logger.time("Download '#{added.rp}'")
                  writeStream = fs.createWriteStream(path.join(@_source, @config.get("client:contentRegion"), added.rp))
                  req = http.request "#{formUrl}#{added.dp}", (res) =>
                    if (res.statusCode == 200)
                      res.pipe(writeStream)
                      return
                    writeStream.emit('error', new Error(http.STATUS_CODES[res.statusCode]))
                  req.end()

                  req.on 'error', (err) =>
                    writeStream.emit('error', err)

                  writeStream.on 'error', (err) =>
                    writeStream.emit('close', err)

                  writeStream.on 'close', (err) =>
                    if err?
                      @logger.info("Download of #{added.rp} is FAILED. #{@logger.timeEnd("Download '#{added.rp}'")}")
                      callback(err)
                    else
                      @logger.info("Download of #{added.rp} is DONE. #{@logger.timeEnd("Download '#{added.rp}'")}")
                      callback(null, "DOWNLOAD of '#{added.rp}': SUCCESS")
              , callback.bind(@))
          , (callback) =>
              async.eachLimit(changeSet.deleted, 5, (deleted, callback) =>
                @logger.info("Delete '#{path.join(@_source, @config.get("client:contentRegion"), deleted)}'")
                fs.remove path.join(@_source, @config.get("client:contentRegion"), deleted), (err) =>
                  callback(err, "DELETION of '#{deleted}': SUCCESS")
              , callback.bind(@))
          ]
        , (err) =>
          @logger.info("SYNC-HTTP command is DONE. #{@logger.timeEnd("SYNC-HTTP command")}")
          if err? null then return callback(err)
          @syncLocal(command, callback)
      else
        @logger.info "Content delivery file is found."
        callback(null, "Content delivery file is found.")

  syncLocal: (command, callback)->
    @logger.info "Start LOCAL-SYNC command. Rsync from '#{@_source}' to '#{@_dest}'."
    @logger.time("LOCAL-SYNC command")
    async.parallel [
        (callback) =>
          Sync.initFolders([@_source, @_dest], callback)
      , @updateFlagIndicators.bind(@)
      ]
    , (err) =>
      if err? then return callback(err)
      if not @_flags.stopContentDelivery
        @_rsync.source(path.join(@_source, @config.get("client:contentRegion") + "/")).destination(@_dest)
        @_rsync.execute (err, resultCode) =>
          if err? then return callback(err, resultCode)
          @logger.info "LOCAL-SYNC command resultCode: '#{resultCode}'. #{@logger.timeEnd("LOCAL-SYNC command")}"
          callback(null, "LOCAL-SYNC: SUCCESS")
      else
        @logger.info "Content delivery file is found."
        callback(null, "Content delivery file is found.")

  _logChanges: (result, key) ->
    if @_lastKey isnt key
      @logger.info ("#{if key? then "#{key} is found. " else ""}#{result}")
      @_lastKey = key

  startAutoSync: () ->
    @logger.info "Start AUTO-SYNC process"
    @intervalId = setInterval () =>
      @_syncAuto()
    , 10000 if not @intervalId?

  stopAutoSync: () ->
    @logger.info "Stop AUTO-SYNC process"
    if @intervalId?
      clearInterval @intervalId
      delete @intervalId

  syncReset: (callback) ->
    @logger.info("SYNC-RESET command started.")
    @logger.time("SYNC-RESET command")
#    @logger.info "Tasks in queue to be reset: #{@_queue.tasks.length}"
    @_queue.tasks.length = 0
    @pushCommand {name: "sync-backup"}, (err) =>
      if err? then return callback?(err)
      setTimeout () =>
        @pushCommand {name: "sync-backup"}, (err) =>
          if err? then return callback?(err)
          @logger.info("SYNC-RESET command is DONE. #{@logger.timeEnd("SYNC-RESET command")}")
          callback?(null, "SYNC-REST: SUCCESS")
      , 10000

  _syncAuto: () ->
    @updateFlagIndicators (err) =>
      if err? then return @logger.error util.inspect err, {depth: 30}
      else if @_flags.stopContentDelivery
        @_logChanges('Content delivery stopped.', 'stopContentDelivery')
      else
        if @_lastKey is "stopContentDelivery"
          @_logChanges('Content delivery restarted.')
          @syncReset()
        else if @_flags.stopPeriodicRsync is on
          @_logChanges('Periodic LOCAL-SYNC stopped.', 'stopPeriodicRsync')
        else
          @_logChanges('Periodic LOCAL-SYNC started.')
          @pushCommand {name: "sync-local"}, (err) =>
            if err? then return @logger.error util.inspect err, {depth: 30}


  module.exports = Sync