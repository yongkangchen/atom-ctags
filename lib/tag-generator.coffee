{BufferedProcess} = require 'atom'
path = require 'path'
fs = require "fs"
exec = require('child_process').exec

PlainMessageView = null
panel = null
error = (message, className) ->
  if not panel
    {MessagePanelView, PlainMessageView} = require "atom-message-panel"
    panel = new MessagePanelView title: "Atom Ctags"

  panel.attach()
  panel.add new PlainMessageView
    message: message
    className: className || "text-error"
    raw: true

simpleExec = (command, exit)->
  exec command, (error, stdout, stderr)->
    console.log('stdout: ' + stdout) if stdout
    console.log('stderr: ' + stderr) if stderr
    console.log('exec error: ' + error) if error

getProjectPath = (codepath) ->
  for directory in atom.project.getDirectories()
    dirPath = directory.getPath()
    return dirPath if dirPath is codepath or directory.contains(codepath)

module.exports = (codepath, isAppend, cmdArgs, callback)->
  tags = []
  command = atom.config.get("atom-ctags.cmd").trim()
  if command == ""
    command = path.resolve(__dirname, '..', 'vendor', "ctags-#{process.platform}")
  ctagsFile = require.resolve('./.ctags')

  projectPath = getProjectPath(codepath)
  projectCtagsFile = path.join(projectPath, ".ctags")
  if fs.existsSync(projectCtagsFile)
    ctagsFile = projectCtagsFile

  tagsPath = path.join(projectPath, ".tags")
  if isAppend
    genPath = path.join(projectPath, ".tags1")
  else
    genPath = tagsPath

  args = []
  args.push cmdArgs... if cmdArgs

  args.push("--options=#{ctagsFile}", '--fields=+KSn', '--excmd=p')
  args.push('-u', '-R', '-f', genPath, codepath)

  stderr = (data)->
    console.error("atom-ctags: command error, " + data, genPath)

  exit = ->
    clearTimeout(t)

    if isAppend
      if process.platform in 'win32'
        simpleExec "type '#{tagsPath}' | findstr /V /C:'#{codepath}' > '#{tagsPath}2' & ren '#{tagsPath}2' '#{tagsPath}' & more +6 '#{genPath}' >> '#{tagsPath}'"
      else
        simpleExec "grep -v '#{codepath}' '#{tagsPath}' > '#{tagsPath}2'; mv '#{tagsPath}2' '#{tagsPath}'; tail -n +7 '#{genPath}' >> '#{tagsPath}'"

    callback(genPath)

  childProcess = new BufferedProcess({command, args, stderr, exit})

  timeout = atom.config.get('atom-ctags.buildTimeout')
  t = setTimeout ->
    childProcess.kill()
    error """
    Stopped: Build more than #{timeout/1000} seconds, check if #{codepath} contain too many files.<br>
            Suggest that add CmdArgs at atom-ctags package setting, example:<br>
                --exclude=some/path --exclude=some/other"""
  , timeout
