# Ozzy.vim

**v3.0**

Open your files from wherever you are. If you have edited a file at least once
then you can open that file using just its name.

![Screenshot](/extra/screenshot.png "A view of the launcher")   


## Requirements

* vim 7.3+
* vim compiled with python 2.6+
* Unix, Mac OS


## Installation

Extract the content of the folder into the `$HOME/.vim` directory or use your favourite
package manager.                          


## Side Effects

Note that Ozzy will create a small persistent database file on your pc for storing file names 
and statistics about their usage.
On Mac platforms this will be placed into the `$HOME/Library/Application Support/Ozzy` folder,
whereas on Linux platform it will reside into the `$HOME/.ozzy` folder. You
have to remove this folder manually the day you'll want to uninstall the plugin.


## Commands


### Ozzy

This is the most important command. Use this command and a small window will popup
at the bottom of the Vim window with a special command line. Start typing the file you want to open and you'll see the list
updating as you type. Below there is list of all the mappings you can use to interact with the 
window:

* `UP`, `TAB`, `CTRL+K`: move up in the list.
* `DOWN`, `CTRL+J`: move down in the list.
* `RETURN`, `CTRL+O`, `CTRL+E`: open the selected file.
* `ESC`, `CTRL+C`: close the list.
* `CTRL+D`: delete the selected file (it won't show up anymore in the list until
you'll edit that file again).


### OzzyReset 

To remove all the entries from the database.

## Calculator on the fly

Ozzy integrates a tiny calculator. Just type some arithmetic expressions in the command line 
and you'll see the result. The expressions must follow the `python` notation, so you'll have to use 
th `**` operator in order to compute the power of a number. All functions from the python `math` module
are also available.


## Settings


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
*examples*: `doc/` (every file in a folder called 'doc') 

* `/<full path>`   
all files contained in `<full path>`.   
*examples*: `/Users/you/misc`

```
e.g. let g:ozzy_ignore = ['*.txt', '/Users/you/misc', 'doc/', 'LICENSE']
```
         

default: []


### g:ozzy_track_only

With this setting you can specify the directories you want to track:
Only files under any of these directories will be tracked.

```
e.g. let g:ozzy_track_only = ['/Users/you/dropbox', 'Users/you/dev']
```

default: []


### g:ozzy_max_entries

With this setting you can set the maximum number of entries displayed by
the `Ozzy` command.

default: 15


### g:ozzy_prompt

With this setting you can customize the look of the prompt used by the
`Ozzy` command.

default: ' ❯ '
