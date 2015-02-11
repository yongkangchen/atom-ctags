{CompositeDisposable} = require 'atom'

module.exports =
  disposables: new CompositeDisposable

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

    if atom.config.get('atom-ctags.autoBuildTagsWhenActive')
      @createFileView().rebuild() if atom.project.getPath()
      @disposables.add atom.project.onDidChangePaths (paths)=>
        @createFileView().rebuild()

    atom.workspaceView.command 'atom-ctags:rebuild', (e, cmdArgs)=>
      @ctagsCache.cmdArgs = cmdArgs if Array.isArray(cmdArgs)
      @createFileView().rebuild()
      if t
        clearTimeout(t)
        t = null

    atom.workspaceView.command 'atom-ctags:toggle-file-symbols', =>
      @createFileView().toggle()

    atom.workspaceView.command 'atom-ctags:toggle-project-symbols', =>
      @createFileView().toggleAll()

    atom.workspaceView.command 'atom-ctags:go-to-declaration', =>
      @createFileView().goto()

    atom.workspaceView.command 'atom-ctags:return-from-declaration', =>
      @createGoBackView().toggle()

    atom.workspaceView.eachEditorView (editorView)->
      editorView.on 'mousedown', (event) ->
        return unless event.altKey and event.which is 1
        atom.workspaceView.trigger 'atom-ctags:go-to-declaration'

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
    @disposables.dispose()

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

  getProvider: ->
    return @provider if @provider?
    CtagsProvider = require './ctags-provider'
    @provider = new CtagsProvider()
    @provider.ctagsCache = @ctagsCache
    return @provider

  provide: ->
    return {provider: @getProvider()}
