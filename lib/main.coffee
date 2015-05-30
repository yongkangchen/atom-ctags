$ = null
{CompositeDisposable} = require 'atom'

module.exports =
  disposable: null

  config:
    autoBuildTagsWhenActive:
        title: 'Automatically rebuild tags'
        description: 'Rebuild tags file each time a project path changes'
        type: 'boolean'
        default: false
    buildTimeout:
        title: 'Build timeout'
        description: 'Time (in milliseconds) to wait for a tags rebuild to finish'
        type: 'integer'
        default: 5000
    cmd:
        type: 'string'
        default: ""
    cmdArgs:
        type: 'string'
        default: ""
    extraTagFiles:
        type: 'string'
        default: ""

  provider: null

  activate: ->
    @stack = []

    @ctagsCache = require "./ctags-cache"

    @ctagsCache.activate()

    @ctagsCache.initTags(atom.project.getPaths(), atom.config.get('atom-ctags.autoBuildTagsWhenActive'))
    @disposable = atom.project.onDidChangePaths (paths)=>
      @ctagsCache.initTags(paths, atom.config.get('atom-ctags.autoBuildTagsWhenActive'))

    atom.commands.add 'atom-workspace', 'atom-ctags:rebuild', (e, cmdArgs)=>
      console.error "rebuild: ", e
      @ctagsCache.cmdArgs = cmdArgs if Array.isArray(cmdArgs)
      @createFileView().rebuild(true)
      if t
        clearTimeout(t)
        t = null

    atom.commands.add 'atom-workspace', 'atom-ctags:toggle-project-symbols', =>
      @createFileView().toggleAll()

    atom.commands.add 'atom-text-editor',
      'atom-ctags:toggle-file-symbols': => @createFileView().toggle()
      'atom-ctags:go-to-declaration': => @createFileView().goto()
      'atom-ctags:return-from-declaration': => @createGoBackView().toggle()

    atom.workspace.observeTextEditors (editor) =>
      editorView = atom.views.getView(editor)
      {$} = require 'atom-space-pen-views' unless $
      $(editorView).on 'mousedown', (event) =>
        return unless event.altKey and event.which is 1
        @createFileView().goto()

    if not atom.packages.isPackageDisabled("symbols-view")
      atom.packages.disablePackage("symbols-view")
      alert "Warning from atom-ctags:
              atom-ctags replaces and enhances the symbols-view package.
              Therefore, symbols-view has been disabled."

    initExtraTagsTime = null
    atom.config.observe 'atom-ctags.extraTagFiles', =>
      clearTimeout initExtraTagsTime if initExtraTagsTime
      initExtraTagsTime = setTimeout((=>
        @ctagsCache.initExtraTags(atom.config.get('atom-ctags.extraTagFiles').split(" "))
        initExtraTagsTime = null
      ), 1000)

  deactivate: ->
    if @disposable?
      @disposable.dispose()
      @disposable = null

    if @fileView?
      @fileView.destroy()
      @fileView = null

    if @projectView?
      @projectView.destroy()
      @projectView = null

    if @goToView?
      @goToView.destroy()
      @goToView = null

    if @goBackView?
      @goBackView.destroy()
      @goBackView = null

    @ctagsCache.deactivate()

  createFileView: ->
    unless @fileView?
      FileView  = require './file-view'
      @fileView = new FileView(@stack)
      @fileView.ctagsCache = @ctagsCache
    @fileView

  createGoBackView: ->
    unless @goBackView?
      GoBackView = require './go-back-view'
      @goBackView = new GoBackView(@stack)
    @goBackView

  provide: ->
    unless @provider?
      CtagsProvider = require './ctags-provider'
      @provider = new CtagsProvider()
      @provider.ctagsCache = @ctagsCache
    @provider
