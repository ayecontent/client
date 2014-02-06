"use strict"

FS = require "q-io/fs"
fs = require "fs"

async = require "async-q"
Q = require "q"

path = require "path"
exec = require('child_process').exec
events = require "events"
request = require "request"

Rsync = require "rsync"

class Sync extends events.EventEmitter

  COMMANDS:
    "sync-http": "syncHttp"
    "sync-backup": "syncGit"
    "sync-local": "syncLocal"

  constructor: (args)->
    {@config, @logger} = args
    @_source = @config.get "folder:backup"
    @_dest = @config.get "folder:dest"
    @_flags = {}
    @_gitUrl = @config.get "git:url"
    @_gitDir = path.resolve(@_source, '.git')

    @_rsync = new Rsync()
    .flags('avz')
    .set('delete')
    .exclude(@config.get "syncignore")

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
      FS.exists(path.join(@_source, indicators[flag]))
      .then((result)=>
          @_flags[flag] = result
        )
    )

  _logChanges: (result, key) ->
    if @lastKey? isnt key
      @logger.info (if key? then "As '#{key}' file was found => ") + result
      @lastKey = key

  pushCommand: (command) ->
    deferred = Q.defer()
    @_queue.push({command: command}).then((result)=>
      deferred.resolve("success")
    ).catch((err)=>
      @logger.error err.message
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
    @logger.info "start to clone git repository '#{@_gitUrl}' into '#{@_source}'"
    @logger.info "emptying backup directory '#{@_source}'"
    deferred = Q.defer()
    async.series([FS.removeTree(@_source), FS.makeTree(@_source)])
    .then( =>
        exec "git clone #{@_gitUrl} #{@_source}", (err, stdout, stderr) =>
          @logger.info "CLONE GIT result:\n#{if stdout isnt "" then stdout else stderr}"
          if stderr isnt "" then deferred.reject(err)
          else deferred.resolve("success")
      )
    deferred.promise

  _pullRepository: () ->
    @logger.info "start to pull git repository into '#{@_source}'"
    deferred = Q.defer()
    exec "git --git-dir=#{@_gitDir} --work-tree=#{@_source} pull",
    (err, stdout, stderr) =>
      @logger.info "PULL GIT result:\n#{if stdout isnt "" then stdout else stderr}"
      if stderr isnt "" then deferred.reject(err)
      else deferred.resolve("success")
    deferred.promise

  syncGit: (command)->
    async.series(
      Q.all([Sync.initFolders(@_source, @_dest), @updateFlagIndicators()]),
      async.waterfall([
        @_checkRepositoryStatus.bind(@)
      ,(result) =>
          if result is "not git" then @_cloneRepository()
          else Q.resolve("success")
      ,(result) =>
          if result is "success" then @_pullRepository()
          else Q.reject("fail")
      ,(result) =>
          if result is "success" then @syncLocal()
          else Q.reject("fail")
      ]
      )
    )

  syncHttp: (command)->
    formUrl = "http://#{command.host}:#{command.port}"
    formUrl += "/#{@config.get("client:customer:id")}"
    formUrl += "/#{@config.get("client:hostId")}"
    formUrl += "/#{@config.get("client:contentRegion")}"
    formUrl += "/#{command.snapshot.id}"

    Sync.initFolders(@_source, @_dest).then(=>
      Q.all([
        async.eachLimit(command.added.concat(command.modified), 5, (added) =>
          wQ = Q.defer()
          writeStream = fs.createWriteStream(path.resolve(@_source, added))
          writeStream.on "finish", ->
            wQ.resolve()
          writeStream.on "close", ->
            wQ.reject()
          rQ = Q.defer()
          req = request("#{formUrl}/#{added}").pipe(writeStream)
          req.on "end", ->
            rQ.resolve()
          req.on "close", ->
            rQ.reject()
          Q.all([wQ, rQ])
        ),
        async.eachLimit(command.deleted, 5, (deleted) =>
          FS.removeTree path.resolve(@_source, deleted)
        )
      ])
    )

  syncLocal: (command)->
    deferred = Q.defer()
    Sync.initFolders(@_source, @_dest).then(=>
      @_rsync.source(@_source).destination(@_dest)
      @_rsync.execute (err, resultCode) =>
        if err then deferred.reject(err)
        result = if resultCode is 0 then "success" else "fail"
        @logger.info """LOCAL RSYNC result:\n'#{result}';
                    local sync from '#{@_source}' to '#{@_dest}';
                    """
        deferred.resolve(result)
    )
    deferred.promise

  startAutoSync: ()->
    @_autoSync()

  _autoSync: ()->
    @updateFlagIndicators().then(()=>
      if @_flags.stopPeriodicRsync is on
        @_logChanges('periodic local sync will be stopped', 'stopPeriodicRsync')
      else if @_flags.stopContentDelivery is on
        @_logChanges('local sync will be stopped', 'stopPeriodicRsync')
    )

module.exports = Sync