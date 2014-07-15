ChildProcess = require('child_process')
Path = require('path')

module.exports =
class ScriptRunnerProcess
  @run: (view, cmd, editor) ->
    scriptRunnerProcess = new ScriptRunnerProcess(view)
    
    scriptRunnerProcess.execute(cmd, editor)
    
    return scriptRunnerProcess
  
  constructor: (view) ->
    @view = view
    @child = null
  
  detach: ->
    @view = null
  
  stop: (signal = 'SIGINT') ->
    if @child
      #console.log("Sending", signal, "to child", @child, "pid", @child.pid)
      process.kill(-@child.pid, signal)
      if @view and signal == 'SIGINT'
        @view.append('^C', 'stdin')
  
  execute: (cmd, editor) ->
    cwd = atom.project.path

    # Save the file if it has been modified:
    if editor.getPath()
      editor.save()
      cwd = Path.dirname(editor.getPath())
    
    # If the editor refers to a buffer on disk which has not been modified, we can use it directly:
    if editor.getPath() and !editor.buffer.isModified()
      cmd = cmd + ' ' + editor.getPath()
      appendBuffer = false
    else
      appendBuffer = true
    
    # PTY emulation:
    args = ["script", "-qfec", cmd, "/dev/null"]
    
    #console.log("args", args, "cwd", cwd, process.pid)
    
    # Spawn the child process:
    @child = ChildProcess.spawn(args[0], args.slice(1), cwd: cwd, detached: true)
    
    # Handle various events relating to the child process:
    @child.stderr.on 'data', (data) =>
      if @view?
        @view.append(data, 'stderr')
        @view.scrollToBottom()
    
    @child.stdout.on 'data', (data) =>
      if @view?
        @view.append(data, 'stdout')
        @view.scrollToBottom()
    
    @child.on 'exit', (code, signal) =>
      #console.log("process", args, "exit", code, signal)
      @child = null
      if @view
        duration = ' after ' + ((new Date - startTime) / 1000) + ' seconds'
        if code
          @view.footer('Exited with status ' + code + duration)
        else
          @view.footer('Interupted with signal ' + signal + duration)

    startTime = new Date
    
    # Could not supply file name:
    if appendBuffer
      @child.stdin.write(editor.getText())
    
    @view.header('Running: ' + cmd + ' (pgid ' + @child.pid + ')')
    # @child.stdin.end()