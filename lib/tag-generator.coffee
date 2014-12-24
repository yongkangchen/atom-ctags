{BufferedProcess, Point} = require 'atom'
Q = require 'q'
path = require 'path'

fs = null

module.exports =
class TagGenerator
  constructor: (@path, @scopeName, @cmdArgs) ->

  parseTagLine: (line) ->
    matches = line.match(/\t\/\^(.*)\$\/;"/)
    if not matches
      matches = line.match(/\t\/\^(.*)\/;"/)
    return unless matches

    pattern = matches[1]
    patternStr = matches[0]

    idx = line.indexOf(patternStr)

    start = line.substr(0, idx)
    end = line.substr(idx + patternStr.length)

    row = 0
    row = end.match(/line:(\d+)/)?[1]
    --row

    sections = start.split(/\t+/)
    file = sections.pop()
    name = sections.join("\t")
    return unless name

    file: file
    position: new Point(row, pattern.indexOf(name))
    pattern: pattern
    name: name


  getLanguage: ->
    return 'Cson' if path.extname(@path) in ['.cson', '.gyp']

    switch @scopeName
      # For backwards compatibility
      when 'source.c++'      then 'C++'
      when 'source.objc++'   then 'C++'

      when 'source.c'        then 'C'
      when 'source.cpp'      then 'C++'
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
      when 'source.objcpp'   then 'C++'
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
          line = JSON.stringify(line)
          err.push "failed to parseTagLine: @#{line}@"
      error "please create a new issue:<br> command: @#{command} #{args.join(' ')}@" + err.join("<br>") if err.length > 0
    stderr = (lines) ->
      lines = JSON.stringify(lines)
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
      Stopped: Build more than #{timeout/1000} seconds, check if #{@path} contain too many file.<br>
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
