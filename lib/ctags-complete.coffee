
module.exports =

  editorSubscription: null
  autocomplete: null
  providers: []

  activate:(ctagsCache) ->
    atom.packages.activatePackage("autocomplete-plus").then (pkg) =>
      @autocomplete = pkg.mainModule

      Provider = (require './ctags-provider').ProviderClass(
        @autocomplete.Provider, @autocomplete.Suggestion, ctagsCache)

      @editorSubscription = atom.workspace.observeTextEditors (editor) =>
        editorView = atom.views.getView(editor)
        return if editorView.mini
        provider = new Provider editor
        @autocomplete.registerProviderForEditor provider, editor
        @providers.push provider

        for autocompleteManager in @autocomplete.autocompleteManagers
          continue unless autocompleteManager.editor == editor
          fuzzyProvider = autocompleteManager.providers[0]
          if fuzzyProvider.constructor.name == "FuzzyProvider"
            autocompleteManager.unregisterProvider fuzzyProvider
            fuzzyProvider.dispose()
          break

  deactivate: ->
    @editorSubscription?.dispose()
    @editorSubscription = null
    @providers.forEach (provider) =>
      @autocomplete.unregisterProvider provider

    @providers = []
