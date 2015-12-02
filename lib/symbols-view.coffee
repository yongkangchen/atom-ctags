{$$, SelectListView} = require 'atom-space-pen-views'
{Point} = require 'atom'
fs = null

module.exports =
class SymbolsView extends SelectListView
  @activate: ->
    new SymbolsView

  initialize: (@stack) ->
    super
    @panel = atom.workspace.addModalPanel(item: this, visible: false)
    @addClass('atom-ctags')

  destroy: ->
    @cancel()
    @panel.destroy()

  getFilterKey: -> 'name'

  viewForItem: ({lineNumber, name, file, directory}) ->
    $$ ->
      @li class: 'two-lines', =>
        @div "#{name}:#{lineNumber}", class: 'primary-line'
        @div file, class: 'secondary-line'

  getEmptyMessage: (itemCount) ->
    if itemCount is 0
      'No symbols found'
    else
      super

  cancelled: ->
    @panel.hide()

  confirmed : (tag) ->
    @cancelPosition = null
    @cancel()
    @openTag(tag)

  getTagPosition: (tag) ->
    if not tag.position and tag.lineNumber and tag.pattern
      tag.position = new Point(tag.lineNumber-1, tag.pattern.indexOf(tag.name)-2)
    if not tag.position
      console.error "Atom Ctags: please create a new issue: " + JSON.stringify(tag)
    return tag.position

  openTag: (tag) ->
    if editor = atom.workspace.getActiveTextEditor()
      previous =
        position: editor.getCursorBufferPosition()
        file: editor.getURI()

    if tag.file
      atom.workspace.open(tag.file).then =>
        @moveToPosition(tag.position) if @getTagPosition(tag)

    @stack.push(previous)

  moveToPosition: (position) ->
    if editor = atom.workspace.getActiveTextEditor()
      editor.scrollToBufferPosition(position, center: true)
      editor.setCursorBufferPosition(position)

  attach: ->
    @storeFocusedElement()
    @panel.show()
    @focusFilterEditor()
