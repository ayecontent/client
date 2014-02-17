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

    @_queue = async.queue (task)=>
      commandName = @COMMANDS[task.command.name]
      # don't forget about task.callback
      @[commandName](task.command)

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
    deferred = Q.defer()
    @_queue.push({command: command}).then((result)=>
      deferred.resolve("success")
    ).catch((err)=>
      @logger.error err
      deferred.reject(err)
    ).done()
    deferred.promise

  _checkRepositoryStatus: () ->
    @logger.info "start to check git repository status in '#{@_source}'"
    deferred = Q.defer()
    exec "git --git-dir=#{@_gitDir} --work-tree=#{@_source} status", (err, stdout, stderr) =>
      @logger.info "CHECK GIT STATUS result:\n#{if stdout isnt "" then stdout else stderr}"
      if stderr isnt "" then deferred.resolve("not git")
      else deferred.resolve("git")
    deferred.promise

  _cloneRepository: () ->
    deferred = Q.defer()
    @logger.info "emptying backup directory '#{@_source}'"
    FS.removeTree(@_source)
    .then ()=>
        FS.makeTree(@_source)
    .then ()=>
        @logger.info "start to clone git repository '#{@_gitUrl}' into '#{@_source}'"
        exec "git clone #{@_gitUrl} #{@_source}", (err, stdout, stderr) =>
          @logger.info "CLONE GIT result:\n#{if stdout isnt "" then stdout else stderr}"
          if err isnt null then deferred.reject(err)
          else deferred.resolve("success")

    deferred.promise

  _pullRepository: () ->
    @logger.info "start to pull git repository into '#{@_source}'"
    deferred = Q.defer()
    exec "git --git-dir=#{@_gitDir} --work-tree=#{@_source} pull",
    (err, stdout, stderr) =>
      @logger.info "PULL GIT result:\n#{if stdout isnt "" then stdout else stderr}"
      if err isnt null then deferred.reject(err)
      else deferred.resolve("success")
    deferred.promise

  syncGit: (command)->
    Q.all([Sync.initFolders(@_source, @_dest), @updateFlagIndicators()])
    .then () =>
        if not @_flags.stopContentDelivery
          @_checkRepositoryStatus()
          .then (result) =>
              if result is "not git" then @_cloneRepository()
              else Q.resolve("success")
          .then (result) =>
              if result is "success" then @_pullRepository()
              else Q.reject("fail")
          .then (result) =>
              if result is "success" then @syncLocal(command)
              else Q.reject("fail")
        else
          @logger.info "content delivery file was found"
          Q.resolve("content delivery file was found")

  syncHttp: (command)->
    @logger.info "syncHttp message content: '#{util.inspect(command, { depth: null })}'"
    Q.all([Sync.initFolders(@_source, @_dest), @updateFlagIndicators()])
    .then ()=>
        if not @_flags.stopContentDelivery
          @logger.info "sync http"
          formUrl = "http://#{command.host}:#{command.port}"
          formUrl += "/#{@config.get("client:customer:id")}"
          formUrl += "/#{@config.get("client:hostId")}"
          formUrl += "/#{@config.get("client:contentRegion")}"
          formUrl += "/#{command.snapshot.id}"
          @logger.info "syncHttp server url: '#{formUrl}'"
          changeSet = command.snapshot.changeSet
          Q.all([
            async.eachLimit(changeSet.added.concat(changeSet.modified), 5, (added) =>
              wQ = Q.defer()
              dirname = path.dirname(path.join(@_source, added))
              fs.mkdirpSync(dirname)
              writeStream = fs.createWriteStream(path.join(@_source, added))
              writeStream.on "finish", ->
                wQ.resolve()
              writeStream.on "close", ->
                wQ.reject()
              rQ = Q.defer()
              req = request("#{formUrl}#{added}").pipe(writeStream)
              req.on "end", ->
                rQ.resolve()
              req.on "close", ->
                rQ.reject()
              Q.all([wQ, rQ])
            ),
            async.eachLimit(changeSet.deleted, 5, (deleted) =>
              FS.removeTree path.join(@_source, deleted)
            )
          ])
        else
          @logger.info "content delivery file was found"
          Q.resolve("content delivery file was found")
    .then ()=>
        @syncLocal(command)


  syncLocal: (command)->
    #TODO: excluded files
    deferred = Q.defer()
    Q.all([Sync.initFolders(@_source, @_dest), @updateFlagIndicators()])
    .then ()=>
        if not @_flags.stopContentDelivery
          @_rsync.source(@_source).destination(@_dest)
          @_rsync.execute (err, resultCode) =>
            if err then deferred.reject(err)
            result = if resultCode is 0 then "success" else "fail"
            @logger.info """LOCAL RSYNC result:\n'#{result}';
                  local sync from '#{@_source}' to '#{@_dest}';
                  """
            deferred.resolve(result)
        else
          @logger.info "content delivery file was found"
          deferred.resolve "content delivery file was found"
    deferred.promise

  _logChanges: (result, key) ->
    if @_lastKey isnt key
      @logger.info ("#{if key? then "as #{key} was found => " else ""}#{result}")
      @_lastKey = key

  startAutoSync: ()->
    @intervalId = setInterval ()=>
      @_syncAuto()
    , 10000 if not @intervalId?

  stopAutoSync: ()->
    if @intervalId?
      clearInterval @intervalId
      delete @intervalId

  syncReset: ()->
    deferred = Q.defer()
    @pushCommand(name: "sync-backup")
    .then (result) =>
        setTimeout ()=>
          @pushCommand(name: "sync-backup").then (result)=>
            deferred.resolve(result)
        , 10000
    deferred.promise

  _syncAuto: ()->
    @updateFlagIndicators().then ()=>
      if @_flags.stopContentDelivery
        @_logChanges('content delivery stopped', 'stopContentDelivery')
      else
        if @_lastKey is "stopContentDelivery"
          @_logChanges('content delivery restarted')
          @syncReset()
        else if @_flags.stopPeriodicRsync is on
          @_logChanges('periodic local syncstopped', 'stopPeriodicRsync')
        else
          @_logChanges('periodic local sync started')
          @pushCommand(name: "sync-local")


module.exports = Sync