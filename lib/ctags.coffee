{Tags} = require('../node_modules/ctags/build/Release/ctags.node')
es = require '../node_modules/ctags/node_modules/event-stream'

exports.findTags = (tagsFilePath, tag, options, callback) ->
  unless typeof tagsFilePath is 'string'
    throw new TypeError('tagsFilePath must be a string')

  unless typeof tag is 'string'
    throw new TypeError('tag must be a string')

  if typeof options is 'function'
    callback = options
    options = null

  {partialMatch, caseInsensitive} = options ? {}

  tagsWrapper = new Tags(tagsFilePath)
  tagsWrapper.findTags tag, partialMatch, caseInsensitive, (error, tags) ->
    tagsWrapper.end()
    callback?(error, tags)

  undefined

exports.createReadStream = (tagsFilePath, options={}) ->
  unless typeof tagsFilePath is 'string'
    throw new TypeError('tagsFilePath must be a string')

  {chunkSize} = options
  chunkSize = 100 if typeof chunkSize isnt 'number'

  tagsWrapper = new Tags(tagsFilePath)
  es.readable (count, callback) ->
    unless tagsWrapper.exists()
      return callback(new Error("Tags file could not be opened: #{tagsFilePath}"))

    tagsWrapper.getTags chunkSize, (error, tags) =>
      tagsWrapper.end() if error? or tags.length is 0
      callback(error, tags)
      @emit('end') if error? or tags.length is 0
