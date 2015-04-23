{$$, SelectListView} = require 'atom-space-pen-views'
fs = null

module.exports =
class SymbolsView extends SelectListView

  initialize: (@stack) ->
    super
    @panel = atom.workspace.addModalPanel(item: this, visible: false)
    @addClass('atom-ctags')

  destroy: ->
    @cancel()
    @panel.destroy()

  getFilterKey: -> 'name'

  viewForItem: ({position, name, file, directory}) ->
    if atom.project.getPaths().length > 1
      file = path.join(path.basename(directory), file)
    $$ ->
      @li class: 'two-lines', =>
        if position?
          @div "#{name}:#{position.row + 1}", class: 'primary-line'
        else
          @div name, class: 'primary-line'
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

  openTag: (tag) ->
    if editor = atom.workspace.getActiveTextEditor()
      previous =
        position: editor.getCursorBufferPosition()
        file: editor.getURI()

    {position} = tag
    atom.workspace.open(tag.file).done =>
      @moveToPosition(position) if position

    @stack.push(previous)

  moveToPosition: (position) ->
    if editor = atom.workspace.getActiveTextEditor()
      editor.scrollToBufferPosition(position, center: true)
      editor.setCursorBufferPosition(position)

  attach: ->
    @storeFocusedElement()
    @panel.show()
    @focusFilterEditor()
