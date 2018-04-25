{$$} = require 'atom-space-pen-views'
SymbolsView = require './symbols-view'

module.exports =
class FileView extends SymbolsView
  initialize: ->
    super

    @editorsSubscription = atom.workspace.observeTextEditors (editor) =>
      disposable = editor.onDidSave =>
        f = editor.getPath()
        return unless atom.project.contains(f)
        @ctagsCache.generateTags(f, true)

      editor.onDidDestroy -> disposable.dispose()

  destroy: ->
    @editorsSubscription.dispose()
    super

  viewForItem: ({lineNumber, name, file, pattern}) ->
    $$ ->
      @li class: 'two-lines', =>
        @div class: 'primary-line', =>
          @span name, class: 'pull-left'
          @span pattern.substring(2, pattern.length-2), class: 'pull-right'

        @div class: 'secondary-line', =>
          @span "Line: #{lineNumber}", class: 'pull-left'
          @span file, class: 'pull-right'

  toggle: ->
    if @panel.isVisible()
      @cancel()
    else
      editor = atom.workspace.getActiveTextEditor()
      return unless editor
      filePath = editor.getPath()
      return unless filePath
      @cancelPosition = editor.getCursorBufferPosition()
      @populate(filePath)
      @attach()

  cancel: ->
    super
    @scrollToPosition(@cancelPosition, false) if @cancelPosition
    @cancelPosition = null

  toggleAll: ->
    if @panel.isVisible()
      @cancel()
    else
      @list.empty()
      @maxItems = 10
      tags = []
      for key, val of @ctagsCache.cachedTags
        tags.push tag for tag in val
      @setItems(tags)
      @attach()

  getCurSymbol: ->
    editor = atom.workspace.getActiveTextEditor()
    if not editor
      console.error "[atom-ctags:getCurSymbol] failed getActiveTextEditor "
      return

    scopes = editor.getLastCursor().getScopeDescriptor().getScopesArray()
    if scopes.indexOf('source.ruby') isnt -1
      # Include ! and ? in word regular expression for ruby files
      wordRegex = /[\w!?]*/g
    else if scopes.indexOf('source.clojure') isnt -1
      wordRegex = /[\w\*\+!\-_'\?<>]([\w\*\+!\-_'\?<>\.:]+[\w\*\+!\-_'\?<>]?)?/g
    else
      wordRegex = null

    # Workaround: use editor.getWordUnderCursor(wordRegex, includeNonWordCharacters: false) instead of
    # cursor.getCurrentWordBufferRange(wordRegex) to avoid these atom bugs that I think never got resolved:
    # - https://github.com/atom/atom/issues/6538
    # - https://github.com/atom/atom/pull/8906
    #
    # Concretely, with cursor.getCurrentWordBufferRange, invoking go-to-declaration on text 'foo.bar' with the cursor on
    # 'b' would incorrectly return '.', whereas editor.getWordUnderCursor correctly returns 'bar'.
    return editor.getWordUnderCursor(wordRegex: wordRegex, includeNonWordCharacters: false)

  rebuild: ->
    projectPaths = atom.project.getPaths()
    if projectPaths.length < 1
      console.error "[atom-ctags:rebuild] cancel rebuild, invalid projectPath: #{projectPath}"
      return
    @ctagsCache.cachedTags = {}
    @ctagsCache.generateTags projectPath for projectPath in projectPaths

  goto: ->
    symbol = @getCurSymbol()
    if not symbol
      console.error "[atom-ctags:goto] failed getCurSymbol"
      return

    tags = @ctagsCache.findTags(symbol)

    if tags.length is 1
      @openTag(tags[0])
    else
      @setItems(tags)
      @attach()

  populate: (filePath) ->
    @list.empty()
    @setLoading('Generating symbols\u2026')

    @ctagsCache.getOrCreateTags filePath, (tags) =>
      @maxItem = Infinity
      @setItems(tags)

  scrollToItemView: (view) ->
    super
    return unless @cancelPosition

    tag = @getSelectedItem()
    @scrollToPosition(@getTagPosition(tag))

  scrollToPosition: (position, select = true)->
    if editor = atom.workspace.getActiveTextEditor()
      editor.scrollToBufferPosition(position, center: true)
      editor.setCursorBufferPosition(position)
      editor.selectWordsContainingCursors() if select
