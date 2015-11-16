
TagGenerator = require './tag-generator'
ctags = require 'ctags'
fs = require "fs"
path = require "path"

getTagsFile = (directoryPath) ->
  tagsFile = path.join(directoryPath, ".tags")
  return tagsFile if fs.existsSync(tagsFile)

matchOpt = {matchBase: true}
module.exports =
  activate: () ->
    @cachedTags = {}
    @extraTags = {}

  deactivate: ->
    @cachedTags = null

  initTags: (paths, auto)->
    return if paths.length == 0
    @cachedTags = {}
    for p in paths
      tagsFile = getTagsFile(p)
      if tagsFile
        @readTags(tagsFile, @cachedTags)
      else
        @generateTags(p) if auto

  initExtraTags: (paths) ->
    @extraTags = {}
    for p in paths
      p = p.trim()
      continue unless p
      @readTags(p, @extraTags)

  readTags: (p, container, callback) ->
    console.log "[atom-ctags:readTags] #{p} start..."
    startTime = Date.now()

    stream = ctags.createReadStream(p)

    stream.on 'error', (error)->
      console.error 'atom-ctags: ', error

    stream.on 'data', (tags)->
      for tag in tags
        continue unless tag.pattern
        data = container[tag.file]
        if not data
          data = []
          container[tag.file] = data
        data.push tag
    stream.on 'end', ()->
      console.log "[atom-ctags:readTags] #{p} cost: #{Date.now() - startTime}ms"
      callback?()

  #options = { partialMatch: true, maxItems }
  findTags: (prefix, options) ->
    tags = []
    return tags if @findOf(@cachedTags, tags, prefix, options)
    return tags if @findOf(@extraTags, tags, prefix, options)

    #TODO: prompt in editor
    console.warn("[atom-ctags:findTags] tags empty, did you RebuildTags or set extraTagFiles?") if tags.length == 0
    return tags

  findOf: (source, tags, prefix, options)->
    for key, value of source
      for tag in value
        if options?.partialMatch and tag.name.indexOf(prefix) == 0
            tags.push tag
        else if tag.name == prefix
          tags.push tag
        return true if options?.maxItems and tags.length == options.maxItems
    return false

  generateTags:(p, isAppend, callback) ->
    delete @cachedTags[p]

    startTime = Date.now()
    console.log "[atom-ctags:rebuild] start @#{p}@ tags..."

    cmdArgs = atom.config.get("atom-ctags.cmdArgs")
    cmdArgs = cmdArgs.split(" ") if cmdArgs

    TagGenerator p, isAppend, @cmdArgs || cmdArgs, (tagpath) =>
      console.log "[atom-ctags:rebuild] command done @#{p}@ tags. cost: #{Date.now() - startTime}ms"

      startTime = Date.now()
      @readTags(tagpath, @cachedTags, callback)

  getOrCreateTags: (filePath, callback) ->
    tags = @cachedTags[filePath]
    return callback?(tags) if tags

    @generateTags filePath, true, =>
      tags = @cachedTags[filePath]
      callback?(tags)
