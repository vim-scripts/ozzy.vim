# ozzy.vim

**v3.3**

Ozzy is an useful companion for opening files from all over the file system.
You just have to open the launcher (via the `Ozzy` command), start typing something, 
and a list of files matches will appear.

Note, however, that Ozzy does not perform a runtime file search as you type.
Instead, it keeps track of all files you open over time into an external database, so 
that you have to open a file at least once as you usually do (eg. via the :e
command) before Ozzy can do it for you.

![Screenshot](/extra/screenshot.jpg "A view of the launcher")   


## Requirements

* Vim 7.3+
* Vim compiled with python 2.6+
* Unix, Mac OS X


## Installation

You can either extract the content of the folder into the `$HOME/.vim`
directory or use your favorite plugin manager such as Vundle or Pathogen.                         


## Side Effects

Note that Ozzy will create a small persistent database file on your pc for
storing file names and statistics about their usage.  On Mac platforms this
will be placed into the `$HOME/Library/Application Support/Ozzy` folder,
whereas on Linux platform it will reside into the `$HOME/.ozzy` folder.  You
have to remove this folder manually the day you'll want to uninstall the
plugin.


## Commands


### Ozzy

This is the most important command. Use this command and a small window will
popup at the bottom of the Vim window with a special command line. Start typing
the file you want to open and you'll see the list updating as you type. Below
there is list of all the mappings you can use to interact with the window:

* `UP`, `TAB`, `CTRL+K`: move up in the list.
* `DOWN`, `CTRL+J`: move down in the list.
* `RETURN`, `CTRL+O`, `CTRL+E`: open the selected file.
* `ESC`, `CTRL+C`: close the list.
* `CTRL+D`: delete the selected file (it won't show up anymore in the list until you'll edit that file again).
* `CTRL+U`: clear the current search.


### OzzyToggleMode

To toggle between `project` and `global` mode. When `project` mode is on, the
search is limited to the current project directory and files outside the
project directory won't be listed among matches. Ozzy locates the project the
current project by looking for special markers in the directories up the
directory tree.  By default Ozzy use the following markers to determine the
project root: `.git`, `.hg`, `.svn`, `AndroidManifest.xml`.  You can override
this behavior via the `g:ozzy_root_markers` setting.  When `global` mode is on,
the search won't be limited to the current project directory and you can search
through all files tracked so far.

The default mode is `global` but you can change this behavior via the
`g:ozzy_default_mode` setting.


**NOTE**: whether or not the `autochdir` vim option is set, Ozzy will
always use the path of the currently open file to determine the current working
directory.


### OzzyReset 

To remove all the entries from the database.


## Hidden calculator

Ozzy integrates a tiny calculator. Just type some arithmetic expressions in the
command line and you'll see the result. The expressions must follow the python
notation, so you'll have to use the `**` operator in order to compute the power
of a number. All functions from the python `math` module are also available.


## Settings

### g:ozzy_default_mode

With this setting you can specify the mode that will be active when Vim starts.
You can use either `global` or `project` as values for this setting.

default: "global"


### g:ozzy_root_markers

With this setting you can specify you own root markers so that Ozzy can locate
the project root even if your project root does not include any of the default
markers.

default: [".git", ".hg", ".svn", "AndroidManifest.xml"]


### g:ozzy_ignore_case

Set this setting to 0 to enable case sensitive search.

default: 1


### g:ozzy_show_file_names

If this setting is equal to 1, only the container directory is displayed to the 
right of the file name in the launcher window.

default: 0   


### g:ozzy_ignore  

With this setting you can tell Ozzy what to ignore. File that match any of
these patterns won't be indexed (you won't be able to open them with Ozzy).
Below the allowed patterns:

* `*.<ext>`     
all file names with extension `<ext>`.     
*examples*: `*.py`, `*.cpp`

* `<file name>.*`   
all files named `<file name>` regardless the extension (file names that exactly match `<file name>` will be considered too).    
*examples*: `doc.*`, `log.*`, `README.*`

* `<file name>`    
all file names that exactly match `<file name>` (extension included).     
*examples*: `test.py`, `junk.txt`, `LICENSE` 

* `<partial path>/`   
all files that contain `<partial path>` in their paths.    
*examples*: `doc/` (every file in a folder called "doc") 

* `/<full path>`   
all files contained in `<full path>`.   
*examples*: `/Users/you/misc`

```
e.g. let g:ozzy_ignore = ["*.txt", "/Users/you/misc", "doc/", "LICENSE"]
```
         

default: []


### g:ozzy_track_only

With this setting you can specify the directories you want to track:
Only files under any of these directories will be tracked.

```
e.g. let g:ozzy_track_only = ["/U""rs/you/dropbox", "Users/you/dev"]
```

default: []


### g:ozzy_max_entries

With this setting you can set the maximum number of entries displayed by
the `Ozzy` command.

default: 15


### g:ozzy_prompt

With this setting you can customize the look of the prompt used by the
`Ozzy` command.

default: " >> "


### g:ozzy_project_mode_flag & g:ozzy_global_mode_flag

If you want to know which mode you are in when you open the launcher you can
set this variables to strings that let you distinguish between the two modes.

default: ""
