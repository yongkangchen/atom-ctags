{BufferedProcess, Point} = require 'atom'
Q = require 'q'
path = require 'path'

fs = null

module.exports =
class TagGenerator
  constructor: (@path, @scopeName, @cmdArgs) ->

  parseTagLine: (line) ->
    pattern = line.match(/\/\^(.*)\$\/;"/)?[1]
    if not pattern
      pattern = line.match(/\/\^(.*)\/;"/)?[1]
    return unless pattern

    idx = line.indexOf(pattern)

    start = line.substr(0, idx)
    end = line.substr(idx + pattern.length)

    row = 0
    row = end.match(/line:(\d+)/)?[1]
    --row

    sections = start.split(/\t+/)
    name = sections[sections.length-3]

    file: sections[sections.length-2]
    position: new Point(row, pattern.indexOf(name))
    pattern: pattern
    name: name


  getLanguage: ->
    return 'Cson' if path.extname(@path) in ['.cson', '.gyp']

    switch @scopeName
      when 'source.c'        then 'C'
      when 'source.c++'      then 'C++'
      when 'source.clojure'  then 'Lisp'
      when 'source.coffee'   then 'CoffeeScript'
      when 'source.css'      then 'Css'
      when 'source.css.less' then 'Css'
      when 'source.css.scss' then 'Css'
      when 'source.gfm'      then 'Markdown'
      when 'source.go'       then 'Go'
      when 'source.java'     then 'Java'
      when 'source.js'       then 'JavaScript'
      when 'source.json'     then 'Json'
      when 'source.makefile' then 'Make'
      when 'source.objc'     then 'C'
      when 'source.objc++'   then 'C++'
      when 'source.python'   then 'Python'
      when 'source.ruby'     then 'Ruby'
      when 'source.sass'     then 'Sass'
      when 'source.yaml'     then 'Yaml'
      when 'text.html'       then 'Html'
      when 'text.html.php'   then 'Php'

  read: ->
    deferred = Q.defer()
    tags = []

    fs = require "fs" if not fs
    fs.readFile @path, 'utf-8', (err, lines) =>
      if not err
        lines = lines.replace(/\\\\/g, "\\")
        lines = lines.replace(/\\\//g, "/")
        lines = lines.split('\n')
        if lines[lines.length-1] == ""
          lines.pop()

        err = []
        for line in lines
          continue if line.indexOf('!_TAG_') == 0
          tag = @parseTagLine(line)
          if tag
            tags.push(tag)
          else
            err.push "failed to parseTagLine: @#{line}@"

        error "please create a new issue:<br> path: #{@path} <br>" + err.join("<br>") if err.length > 0
      else
        error err

      deferred.resolve(tags)

    deferred.promise

  generate: ->
    deferred = Q.defer()
    tags = []
    command = atom.config.get("atom-ctags.cmd").trim()
    if command == ""
        command = path.resolve(__dirname, '..', 'vendor', "ctags-#{process.platform}")
    defaultCtagsFile = require.resolve('./.ctags')

    args = []
    args.push @cmdArgs... if @cmdArgs

    args.push("--options=#{defaultCtagsFile}", '--fields=+KSn', '--excmd=p')
    args.push('-R', '-f', '-', @path)

    stdout = (lines) =>
      lines = lines.replace(/\\\\/g, "\\")
      lines = lines.replace(/\\\//g, "/")

      lines = lines.split('\n')
      if lines[lines.length-1] == ""
        lines.pop()

      err = []
      for line in lines
        tag = @parseTagLine(line)
        if tag
          tags.push(tag)
        else
          err.push "failed to parseTagLine: @#{line}@"
      error "please create a new issue:<br> command: @#{command} #{args.join(' ')}@" + err.join("<br>") if err.length > 0
    stderr = (lines) ->
      console.warn  """command: @#{command} #{args.join(' ')}@
      err: @#{lines}@"""

    exit = ->
      clearTimeout(t)
      deferred.resolve(tags)

    childProcess = new BufferedProcess({command, args, stdout, stderr, exit})

    timeout = atom.config.get('atom-ctags.buildTimeout')
    t = setTimeout =>
      childProcess.kill()
      error """
      stoped: Build more than #{timeout} seconds, check if #{@path} contain too many file.<br>
              Suggest that add CmdArgs at atom-ctags package setting, example:<br>
                  --exclude=some/path --exclude=some/other"""
    ,timeout

    deferred.promise

PlainMessageView = null
panel = null
error= (message, className) ->
    if not panel
      {MessagePanelView, PlainMessageView} = require "atom-message-panel"
      panel = new MessagePanelView title: "Atom Ctags"

    panel.attach()
    panel.add new PlainMessageView
      message: message
      className: className || "text-error"
      raw: true
