"use strict"

FS = require "q-io/fs"
fs = require "fs-extra"

async = require "async-q"
Q = require "q"

path = require "path"
exec = require('child_process').exec
events = require "events"
request = require "request"
util = require "util"

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
    @_gitUrl = @config.get "git:url"
    @_gitDir = path.join(@_source, '.git')

    @_rsync = new Rsync({debug: true})
    .flags('avz')
    .set('delete')
    .exclude(@config.get("syncIgnore"))

    @_queue = async.queue (command) =>
      @logger.startTime ("Command #{util.inspect(command, {depth: 30})} processing")
      commandName = @COMMANDS[command.name]
      @[commandName](command).then ()=>
        @logger.info @logger.printTime ("Command #{util.inspect(command, {depth: 30})} processing")

  @initFolders: () ->
    args = Array.prototype.slice.call(arguments, 0)
    async.each(args, (file)->
      FS.makeTree file
    )

  updateFlagIndicators: ->
    indicators = @config.get("indicator")
    flags = (flag for flag of indicators)
    async.each(flags, (flag) =>
      FS.exists(path.join(@_dest, indicators[flag]))
      .then((result)=>
          @_flags[flag] = result
        )
    )

  pushCommand: (command) ->
    @logger.startTime ("Command #{util.inspect(command, {depth: 30})} in queue")
    @_queue.push(command)

  _checkRepositoryStatus: () ->
    @logger.info "Start GIT status of '#{@_source}'. Command: '#{@_wrapGit "git status"}'"
    deferred = Q.defer()
    @logger.startTime("GIT STATUS")
    @_execGit "git status", (err, stdout, stderr) =>
      @logger.info "GIT STATUS result: #{if stdout isnt "" then stdout else stderr}#{@logger.printTime("GIT STATUS")}"
      if stderr isnt "" then deferred.resolve("NOT_GIT")
      else deferred.resolve("GIT")
    deferred.promise

  _cloneRepository: () ->
    deferred = Q.defer()
    @logger.info "Cleaning backup directory '#{@_source}'"
    FS.removeTree(@_source)
    .then ()=>
        FS.makeTree(@_source)
    .then ()=>
        @logger.info "Start GIT CLONE. Clone '#{@_gitUrl}' into '#{@_source}'. Command: '#{@_wrapGit("git clone #{@_gitUrl} #{@_source}")}'"
        @logger.startTime("GIT CLONE")
        @_execGit "git clone #{@_gitUrl} #{@_source}", (err, stdout, stderr) =>
          @logger.info "GIT CLONE result: #{if stdout isnt "" then stdout else stderr}#{@logger.printTime("GIT CLONE")}"
          if err isnt null then deferred.reject(err)
          else deferred.resolve("SUCCESS")
    deferred.promise

  _wrapGit: (command) ->
    "GIT_SSH=#{path.join(@config.get("basePath"), @config.get("git:sshShell"))} #{command}"

  _execGit: (command, callback) ->
    exec @_wrapGit(command), {cwd: @_source, timeout: @config.get("execTimeout")}, callback

  _pullRepository: () ->
    deferred = Q.defer()
    @logger.info "Start GIT CLEAN. Command: '#{@_wrapGit "git clean -xdf"}'"
    @logger.startTime("GIT CLEAN")
    @_execGit "git clean -xdf", (err, stdout, stderr) =>
      @logger.info "GIT CLEAN result: #{if stdout isnt "" then stdout else stderr}#{@logger.printTime("GIT CLEAN")}"
      if err isnt null then return deferred.reject(err)
      @logger.info "Start GIT RESET. Command: '#{@_wrapGit "git reset --hard origin/master"}'"
      @logger.startTime("GIT RESET")
      @_execGit "git reset --hard origin/master", (err, stdout, stderr) =>
        @logger.info "GIT RESET result: #{if stdout isnt "" then stdout else stderr}#{@logger.printTime("GIT RESET")}"
        if err isnt null then return deferred.reject(err)
        @logger.info "Start GIT PULL. Command: '#{@_wrapGit "git pull --ff"}'"
        @logger.startTime("GIT PULL")
        @_execGit "git pull --ff", (err, stdout, stderr) =>
          @logger.info "GIT PULL result: #{if stdout isnt "" then stdout else stderr}#{@logger.printTime("GIT PULL")}"
          if err isnt null then return deferred.reject(err)
          deferred.resolve("SUCCESS")
    deferred.promise

  syncGit: (command)->
    Q.all([Sync.initFolders(@_source, @_dest), @updateFlagIndicators()])
    .then () =>
        if not @_flags.stopContentDelivery
          @_checkRepositoryStatus()
          .then (result) =>
              if result is "NOT_GIT" then @_cloneRepository()
              else Q.resolve("SUCCESS")
          .then (result) =>
              if result is "SUCCESS" then @_pullRepository()
              else Q.reject("FAIL")
          .then (result) =>
              if result is "SUCCESS" then @syncLocal(command)
              else Q.reject("FAIL")
        else
          @logger.info "Content delivery file was found."
          Q.resolve("Content delivery file was found.")

  syncHttp: (command)->
    @logger.info "Start SYNC-HTTP."
    @logger.startTime("SYNC-HTTP")
    Q.all([Sync.initFolders(@_source, @_dest), @updateFlagIndicators()])
    .then ()=>
        if not @_flags.stopContentDelivery
          formUrl = "http://#{command.host}:#{command.port}"
          formUrl += "/#{@config.get("client:customerId")}"
          formUrl += "/#{@config.get("client:hostId")}"
          formUrl += "/#{@config.get("client:contentRegion")}"
          formUrl += "/#{command.snapshot.id}"
          @logger.info "Constructed SYNC-HTTP fetch url: '#{formUrl}'"
          changeSet = command.snapshot.changeSet
          Q.all([
            async.eachLimit(changeSet.added.concat(changeSet.modified), 5, (changed) =>
              wQ = Q.defer()
              dirname = path.dirname(path.join(@_source, @config.get("client:contentRegion"), added))
              fs.mkdirpSync(dirname)
              writeStream = fs.createWriteStream(path.join(@_source, @config.get("client:contentRegion"), added))
              writeStream.on "finish", ->
                wQ.resolve()
              writeStream.on "close", ->
                wQ.reject()
              rQ = Q.defer()
              @logger.info("Start Download '#{formUrl}#{changed}'")
              @logger.startTime("Download #{changed}")
              req = request("#{formUrl}#{changed}").pipe(writeStream)
              req.on "end", ->
                rQ.resolve()
              req.on "close", ->
                rQ.reject()
              Q.all([wQ, rQ]).then ()->
                @logger.info("Download of #{changed} is DONE. #{@logger.printTime("Download #{changed}")}")
            ),
            async.eachLimit(changeSet.deleted, 5, (deleted) =>
              FS.removeTree path.join(@_source, @config.get("client:contentRegion"), deleted)
            )
          ])
        else
          @logger.info "Content delivery file is found."
          Q.resolve("Content delivery file is found.")
    .then ()=>
        @logger.info("SYNC-HTTP is DONE. #{@logger.printTime("SYNC-HTTP")}")
        @syncLocal(command)


  syncLocal: (command)->
    deferred = Q.defer()
    @logger.info "Start LOCAL-SYNC. Rsync from '#{@_source}' to '#{@_dest}'."
    @logger.startTime("LOCAL-SYNC")
    Q.all([Sync.initFolders(@_source, @_dest), @updateFlagIndicators()])
    .then ()=>
        if not @_flags.stopContentDelivery
          @_rsync.source(path.join(@_source, @config.get("client:contentRegion") + "/")).destination(@_dest)
          @_rsync.execute (err, resultCode) =>
            if err then deferred.reject(err)
            result = if resultCode is 0 then "SUCCESS" else "FAIL"
            @logger.info "LOCAL-SYNC result: '#{result}'. #{@logger.printTime("LOCAL-SYNC")}"
            deferred.resolve(result)
        else
          @logger.info "Content delivery file is found."
          deferred.resolve "Content delivery file is found."
    deferred.promise

  _logChanges: (result, key) ->
    if @_lastKey isnt key
      @logger.info ("#{if key? then "#{key} is found. " else ""}#{result}")
      @_lastKey = key

  startAutoSync: () ->
    @logger.info "Start AUTO-SYNC"
    @intervalId = setInterval () =>
      @_syncAuto()
    , 10000 if not @intervalId?

  stopAutoSync: () ->
    @logger.info "Stop AUTO-SYNC"
    if @intervalId?
      clearInterval @intervalId
      delete @intervalId

  syncReset: () ->
    deferred = Q.defer()
    @logger.startTime("SYNC-RESET started.")
    @logger.startTime("SYNC-RESET")
    @pushCommand(name: "sync-backup")
    .then (result) =>
        setTimeout () =>
          @pushCommand(name: "sync-backup").then (result) =>
            @logger.info("SYNC-RESET is DONE. #{@logger.printTime("SYNC-RESET")}")
            deferred.resolve(result)
        , 10000
    deferred.promise

  _syncAuto: () ->
    @updateFlagIndicators().then () =>
      if @_flags.stopContentDelivery
        @_logChanges('Content delivery stopped.', 'stopContentDelivery')
      else
        if @_lastKey is "stopContentDelivery"
          @_logChanges('Content delivery restarted.')
          @syncReset()
        else if @_flags.stopPeriodicRsync is on
          @_logChanges('Periodic LOCAL-SYNC stopped.', 'stopPeriodicRsync')
        else
          @_logChanges('Periodic LOCAL-SYNC started.')
          @pushCommand(name: "sync-local")


  module.exports = Sync