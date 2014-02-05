"use strict"

fs = require "fs-extra"
async = require "async"
path = require "path"
exec = require('child_process').exec
events = require "events"

Rsync = require "rsync"


class Sync extends events.EventEmitter

  SYNC_HTTP: "sync-http"
  SYNC_BACKUP: "sync-backup"
  GET_STATUS: "get-status"

  constructor: (args)->
    {@config, @logger} = args
    @source = @config.get "folder:backup"
    @dest = @config.get "folder:dest"
    @flags = {}
    @gitUrl = @config.get "git:url"
    @gitDir = path.resolve(@source, '.git')
    @forceEmpty = @config.get "folder:emptyBackupBeforeClone"

    @rsync = new Rsync()
    .flags('avz')
    .set('delete')
    .exclude(@config.get "syncignore")

    @queue = async.queue (task, callback)=>
      @[task.command]((err, result)->
        #TODO: handle errors
        callback()
        if err then task.callback(err)
        else task.callback(null, result)
      )

  @initFolders: (folders...) ->
    #TODO: async make dirs
    for folder in folders
      fs.mkdirsSync(folder)

  updateFlagIndicators: ->
    for key, file of @config.get "indicator"
      @flags[key] = fs.existsSync(path.join(@source, file))

  _logChanges: (result, key) ->
    if @lastKey? isnt key
      @logger.info (if key? then "As '#{key}' file was found => ") + result
      @lastKey = key

  pushCommand: (commandName, callback) ->
    switch commandName
      when @SYNC_BACKUP then command = 'gitSync'
      else command = 'gitSync'
    @queue.push({command: command, callback: callback})

  _checkRepositoryStatus: (callback) ->
    @logger.info "start to check git repository status in '#{@source}'"
    exec "git --git-dir=#{@gitDir} --work-tree=#{@source} status", (err, stdout, stderr) =>
      @logger.info "CHECK GIT STATUS result:\n#{if stdout isnt "" then stdout else stderr}"
      if stderr then return callback(null, false)
      return callback(null, true)

  _cloneRepository: (callback) ->
    @logger.info "start to clone git repository '#{@gitUrl}' into '#{@source}'"
    if @forceEmpty
      @logger.info "emptying backup directory '#{@source}'"
      fs.removeSync @source
      fs.mkdirsSync @source

    exec "git clone #{@gitUrl} #{@source}", (err, stdout, stderr) =>
      @logger.info "CLONE GIT result:\n#{if stdout isnt "" then stdout else stderr}"
      return callback(err) if err
      return callback(null, "success")

  _pullRepository: (callback) ->
    @logger.info "start to pull git repository into '#{@source}'"
    exec "git --git-dir=#{@gitDir} --work-tree=#{@source} pull", (err, stdout, stderr) =>
      @logger.info "PULL GIT result:\n#{if stdout isnt "" then stdout else stderr}"
      return callback(err) if err
      return callback(null, "success")

  gitSync: (callback)->
    Sync.initFolders(@source, @dest)
    @updateFlagIndicators()
    async.waterfall([
      @_checkRepositoryStatus.bind(@)

    , (exists, callback)=>
        if exists isnt true then @_cloneRepository(callback)
        else callback(null, "success")

    , (result, callback)=>
        if result is "success" then @_pullRepository(callback)
        else callback(null, result)

    , (result, callback)=>
        if result is "success" then @localSync(callback)
        else callback(null, result)
    ]
    , callback
    )

  localSync: (callback)->
    Sync.initFolders(@source, @dest)
    @rsync.source(@source).destination(@dest)
    @rsync.execute (err, resultCode) =>
      if err then callback err
      result = if resultCode is 0 then "success" else "fail"
      @logger.info """LOCAL RSYNC result:\n'#{result}';
                  local sync from '#{@source}' to '#{@dest}';
                  """
      callback(null, result)

    , null

    , callback

  startAutoSync: ()->
    @_autoSync()

  _autoSync: ()->
    @updateFlagIndicators()
    if @flags.stopPeriodicRsync is on
      @_logChanges('periodic local sync will be stopped', 'stopPeriodicRsync')
    else if @flags.stopContentDelivery is on
      @_logChanges('local sync will be stopped', 'stopPeriodicRsync')


module.exports = Sync