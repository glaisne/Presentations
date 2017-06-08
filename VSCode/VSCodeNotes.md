Extensions
========================================================================
* There is a huge market place for extensions of all kinds.
* If you don't see something you like, you can write one.

The extensions I use:
* PowerShell by Microosft 
* Settings Sync by Shan Khan
* DevSkim by Microsoft DevLabs

Search Extensions from within VSCode


Command Palette
========================================================================
The Command Palette makes VSCode much more powerful than the ISE.
Gain access to all kinds of different commands within the editor

* Access the command palette by Ctrl+Shift+P or F1
* Search all commands by tying in what you want
* Keybindings are listed.

Some favorites:
* Run Selection (F8) (Same as ISE)
* Debug (F5) (More on this later)
* Add Line Comment (Ctrl+K Ctrl+C)
* File: Compare Active File With...
* Files: Copy Path Of Active File

There are lots of commands, so look around

```powershell
get-process
write-host 'Hello World'

Write-Output 'test'
```
Working with folders
========================================================================
Open an entier folder and work on a collection of files at once.

If the folder has a .git file (GitHub repository) VSCode will keep
you updated on what has been commited and what is staged.
You can look at diffs

"ADTools"


Panels
========================================================================
Problems - Identifies probelsm with your code (Script analyzer)
Output - Output from various sources. Ex: git calls vscode makes.
Debug Console - Uses the Integrated console (left panel)
Terminal - PowerShell window, just like ISE (Terminal emulator). Can run
           any shell. (HTML based)

PowerShell script analyzer
========================================================================
F1: PowerShell:Select Script Analyzer Rules


Debugging
========================================================================
* F5 runs the debugger
* Debug shows you alll your variables
* Can have "Watched" variables
 - No more printing variables to see what they are.
* Don't use the 'Debug Console'

 ```powershell
$var = 'x'
$var += 'a'
get-process 
$var = $var.Insert(1, 'q')
write-host "test"
```

Configuration
========================================================================
* Configurations are in json
* Changes are augmentations to the original.
* Settings are searchable
 - Ctrl+, (shortcut key)
 - F1, 'settings', select 'Preferences: Open User Settings'
 - File -> Preferences -> Settings
* Use the pencil for quick editing
* User vs. Workspace settings
 - User settings are specific to you.
 - Workspace settings are specific to the folder you've opened.
  - (I'll be looking into this for presentations)
* Preferences:Open Keyboard Shortcuts 
 - for updating keyboard shortcuts. 


Git Integration
========================================================================
* https://code.visualstudio.com/Docs/editor/versioncontrol
* Leverages the GIT you have installed (and configured)
* Will show you the status of files.
* Commit
* Clone (F1 Git:Clone)
* Brancing (F1 Git:Create Branch)



Cool stuff
========================================================================
* Multi cursor selection
```powershell
$HerVariable = 'test'
Write-host "This is a $HerVariable"
$newVar = $HerVariable * 3

# Hint: Ctrl+Alt+down
$object = new-object -TypeName PSObject -property @{
    top    = 100
    bottom = 200
    left   = 100
    right  = 150
}
```
* Move a line up or down (Shift+Alt+down or Shift+Alt+up)
* Copy a line up or down (Alt+down or Alt+up)

