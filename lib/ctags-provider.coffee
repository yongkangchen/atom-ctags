module.exports =
class CtagsProvider
  id: 'autocomplete-ctags-ctagssprovider'
  selector: '*'

  tag_options = { partialMatch: true, maxItems: 10 }

  requestHandler: (options) ->
    prefix = options.prefix

    # TODO: support : .
    # tag_options.partialMatch = true
    # if not prefix.length
    #   selection = options.editor.getSelection()
    #   #here to show pre symbol tag pattern
    #   selectionRange = selection.getBufferRange()
    #   selectionRange = selectionRange.add([0, -1])
    #   prefix = @prefixOfSelection { getBufferRange: ()-> selectionRange }
    #   tag_options.partialMatch = false

    # No prefix? Don't autocomplete!
    return unless prefix.length

    matches = @ctagsCache.findTags prefix, tag_options

    suggestions = []
    if tag_options.partialMatch
      output = {}
      k = 0
      while k < matches.length
        v = matches[k++]
        continue if output[v.name]
        output[v.name] = v
        suggestions.push {word: v.name, prefix: prefix, label: v.pattern}
      if suggestions.length == 1 and suggestions[0].word == prefix
        return []
    else
      for i in matches
        suggestions.push {word: i.name, prefix: prefix, label: i.pattern}

    # No suggestions? Don't autocomplete!
    return unless suggestions.length

    # Now we're ready - display the suggestions
    return suggestions
