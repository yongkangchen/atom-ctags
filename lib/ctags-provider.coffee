checkSnippet = (tag)->
  #TODO support more language
  if tag.kind == "require"
    return tag.pattern.substring(2, tag.pattern.length-2)
  if tag.kind == "function"
    return tag.pattern.substring(tag.pattern.indexOf(tag.name), tag.pattern.length-2)
    
tagToSuggestion = (tag)->
  text: tag.name
  displayText: tag.pattern.substring(2, tag.pattern.length-2)
  type: tag.kind
  snippet: checkSnippet(tag)
    
module.exports =
class CtagsProvider
  selector: '*'

  tag_options = { partialMatch: true, maxItems: 10 }
  prefix_opt = {wordRegex: /[a-zA-Z0-9_]+[\.\:]/}

  getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix}) ->
    return [] if @disabled

    if prefix == "." or prefix == ":"
      prefix = editor.getWordUnderCursor(prefix_opt)

    # No prefix? Don't autocomplete!
    return unless prefix.length

    matches = @ctagsCache.findTags prefix, tag_options

    suggestions = []
    if tag_options.partialMatch
      output = {}
      k = 0
      while k < matches.length
        tag = matches[k++]
        continue if output[tag.name]
        output[tag.name] = tag
        suggestions.push tagToSuggestion(tag)
      if suggestions.length == 1 and suggestions[0].text == prefix
        return []
    else
      for tag in matches
        suggestions.push tagToSuggestion(tag)

    # No suggestions? Don't autocomplete!
    return unless suggestions.length

    # Now we're ready - display the suggestions
    return suggestions
