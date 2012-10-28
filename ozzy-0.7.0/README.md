# Ozzy.vim

**v0.7.0**


Ozzy allows you to open almost any file from anywhere. Just give a file name
and (if the file has been accessed at leat once in the past) the most
frequently used file or the most recently accessed one is picked for you, no
more entire paths to digit or folder to cd into!


## Requirements

* vim 7.3+
* vim compiled with python 2.6+


## Usage

Ozzy is very straightforward to use. Once installed, you can start editing your
favourite files as always. Once you open a file Ozzy registers it and from then
you can open that file with the following command:

```
:Ozzy <file name>
```

If Ozzy has in its database only one file that match the given `<file name>`, 
then that file is opened. If Ozzy find more that one match in its database, 
it has to decide what is the right file to open. By default Ozzy opens the most
frquently used file but you can change this behaviour to open the most recently 
used file, or even the file closest to the current working directory (context mode).
See |ozzy-modes| for more informations.    
If you want to open a file regardless its frequency, access time or the current context,
you can specify a partial path:

```
:Ozzy <partial path>/<file name>
```

But what if you want to open a bunch of files at the same time? Well, if you
end the `<file name>` with a forward slash `/`, Ozzy will interpret it as
a directory and it will open all files contained into that directory (only 
those files that Ozzy has in its database).


If the filename is long or you don't remember part of it you can use command
line completion using the &lt;TAB&gt; key to cycle through possible matches.


<a name="ozzy-modes" />
## Modes
 
A mode determines how Ozzy chooses the right file to open when it is faced with
a buch of file in its database that match the file the user want to 
open. There are three modes available: 

* `most frequent`: the most frequently used file is opened.

* `most recent`: the most recently used file is opened.

* `context`: the file closest to the current working directory is opened.

The default mode is 'most frequent' but you can toggle between the three modes 
during a vim session with the [OzzyToggleMode](#ozzy-toggle-mode) command or set the default mode 
by setting the [g:ozzy_mode](#ozzy_mode) option.


## Freeze ozzy
 
When Ozzy is frozen it does not update its database every time you open a file.
Though, you can still use all the Ozzy commands. If you want to freeze Ozzy
for a long period of time you can set the [g:ozzy_freeze](#ozzy_freeze) option in your .vimrc
file. If you want to freeze Ozzy for a brief period you can toggle on and off 
this option using the [OzzyToggleFreeze](#ozzy-toggle-freeze) command during a vim session.     


<a name="ozzy-inspector" />
## Inspector

The Inspector is the place where you can do tricky things. Here, besides some
information about the current Ozzy status, you can inspect the whole content of
the database where are stored all the files you have opened until now.
The database is presented as a list of records where each records represent
a single file with some additional information: the file path, the frequency
usage and a last access date attribute.
But you can do more than simply inspect the content of the database. 
Below are listed all the keyboard keys you can use during an Inspector session
and their relative actions:

```
    key   meaning
    ---   --------------------------------------------
    q     to quit inspector
    ?     to toggle help
    p     to toggle between absolute and relative to home paths
    f     to order records by frequency
    a     to order records by date and time
    r     to reverse the current records order
    o     to open the file on the current line
    +     to increase the frequency of the file on the current line
    *     as above but increases the frequency by 5
    -     to decrease the frequency of the file on the current line
    _     (underscore) as above but decreases the frequency by 5
    t     to touch the file on the current line (set its last access attribute to now)
    dd    to remove from the list the record under the cursor (or an entire selection)

    Note: The current line is the line where the cursor is positioned.
          To move up and down the records list use the classic hjkl keys.
```

## Commands

<a name="ozzy-command" />     
**Ozzy &lt;file name&gt;**  
shortcut: O

If Ozzy has in its database a file that match the given `<file name>`, then it
is opened. If you ends <file name> with a forward slash `/` Ozzy will interpret
the argument as a directory and it will open all the files in that direcory
according to the [g:ozzy_max_num_of_files_to_open](#max_num_of_files_to_open)
option. In fact, if there more files, only the most recently or frequently
accessed (according to g:ozzy_mode) will be opened. Note however that Ozzy does
not really inspect the real directory on the file system to scan for files, but
instead, it will search exclusively in its database for matches.  You have to
open files at leat once 'manually' before Ozzy can open them for you.

See [Modes](#ozzy-modes) to find out how to change the behaviour of this
command when there are two or more files that match the given `<file name>`.



-------------------------------------------------------------------------------
<a name="ozzyinspect-command" />     
**OzzyInspect**            
shortcut: Oi

Open the database inspector.    
See also [Inspector](#ozzy-inspector).


-------------------------------------------------------------------------------
<a name="ozzyadd-command" />     
**OzzyAddDirectory <directory> [options]**                     
shortcut: OAdd

To add all files contained into the given `directory` (except those contained
into hidden directories). The `directory` argument must be an absolute path
but if you want to add all files contained into the current working directory
you can use the `.` shortcut instead. To add the current parent directory use
the `..` argument. Use the `...` argument to add the project root directory. 
By default *Ozzy* assumes it is the one that contains a `.git`, `.hg` or a `.svn` 
folder along the current working directory path. You can override this behavior
setting the `g:ozzy_what_in_project_root` option).

You can customize the default behavior of this command with the following options:


* `-h`: to add files contained into hidden directories.

* `-a <comma separated list>`: use this option to add only specific files.
   See below for all the allowed patterns.

* `-i <comma separated list>`: use this option to ignore specific files.
   See below for all the allowed patterns.

Below are listed all the patterns you can use:

* `*.<ext>`     
all files with extension `<ext>`.     
*examples*: `*.py`, `*.cpp`

* `<file name>.*`   
all files named `<file name>` regardless the extension (note that the files
that exactly match `<file name>` will be considered too).    
*examples*: `doc.*`, `log.*`, `README.*`

* `<file name>`    
all file names that exactly match `<file name>`.     
*examples*: `test.py`, `junk.txt`, `LICENSE` 

* `<path>/`   
all file paths that contains `<path>/`.    
*examples*: `doc/` (every file in a folder called 'doc') 


-------------------------------------------------------------------------------
<a name="ozzyremove-command" />     
**OzzyRemove &lt;pattern&gt;**       
shortcut: Orm

To remove from the database all the files that match the given pattern. Below
the accepted patterns:

* `*.<ext>`     
all files with extension `<ext>`.     
*examples*: `*.py`, `*.cpp`

* `<file name>.*`   
all files named `<file name>` regardless the extension (note that the files
that exactly match `<file name>` will be removed too).    
*examples*: `doc.*`, `log.*`, `README.*`

* `<file name>`    
all file names that exactly match `<file name>`.     
*examples*: `test.py`, `junk.txt`, `LICENSE` 

* `<file path>`   
all file paths that ends with '<file path>'.    
*examples*: `/doc/file.txt` (every 'file.txt' in a folder called 'doc'), `/Users/donald/file.txt` (a specific file.txt)

* `<path>/`   
all file paths that contains `<path>/`.    
*examples*: `doc/` (every file in a folder called 'doc')    


-------------------------------------------------------------------------------
<a name="ozzykeeplast-command" />     
**OzzyKeepLast &lt;time period&gt;**       
shortcut: Okeep

Where <time period> is an argument composed of two parts: a number n > 0 and
a string, separated by a space. This two parts together represent a period of
time. See the examples below:

* OzzyKeepLast 15 minutes
* OzzyKeepLast 2 hours
* OzzyKeepLast 1 day
* OzzyKeepLast 3 weeks

When you give such a command, then all the database entries (files) that have
not been accessed at least once in the last n (minutes, hours, days or weeks) 
will be removed. This options may helps to keep the database ordinated. 
There are shortcuts for specifying minutes, hours, days, and weeks:

* *minutes*: m, min, minute, minutes
* *hours*: h, hour, hours
* *days*: d, day, days
* *weeks*: w, week, weeks

See also the [g:ozzy_keep](#ozzy_keep) option.


-------------------------------------------------------------------------------
<a name="ozzyreset-command" />     
**OzzyReset**                   

To remove all files entries from the database.


-------------------------------------------------------------------------------
<a name="ozzy-toggle-mode" />
**OzzyToggleMode**            

To toggle between `most frequent` and `most recent` modes.   
See also [Modes](#ozzy-modes) and the [g:ozzy_mode](#ozzy_mode) option. 


-------------------------------------------------------------------------------
<a name="ozzy-toggle-freeze" />
**OzzyToggleFreeze**                                        

To toggle between `freeze on` and `freeze off` modes.    
See also [Ozzy freeze](#ozzy-freeze) and the [g:ozzy_freeze](#ozzy_freeze) option. 


-------------------------------------------------------------------------------
**OzzyToggleExtension**                                   

To toggle between `consider extension` and `ignore extensions` mode.    
See also the [g:ozzy_ignore_ext](#ozzy_ignore_ext) option.     


## Basic settings


<a name="ozzy_mode" />
**g:ozzy_mode**                 

Set this variable to define the default behaviour for opening files. 
Below all the available modes:

* `most_frequent`: the most used file with the given name is opened.
* `most_recent`: the most recently accessed file is opened.
* `context`: the file closest to the current working directory is opened.

*default:* 'most_frequent'

-------------------------------------------------------------------------------
<a name="ozzy_ignore_ext" />
**g:ozzy_ignore_ext**         

Set this option to 1 and Ozzy will ignore extension when serching in its
database for the file to open. Suppose that Ozzy has two entries in its
database: */file1.rb* and */file1.py*. If this option is set to 0 you must specify
the file name and the extension in order to open one of these two files,
otherwise no file will be opened. If you set this option to 0 there is no more
need to specify the extension and Ozzy will open the file that has been most
frequently (or recently, according to the current mode), though, you can still 
specify the extnsion if you want.

*default:* 1

-------------------------------------------------------------------------------
<a name="ozzy_ignore" />
**g:ozzy_ignore**        

This is a list containing naive patterns that tell Ozzy what to ignore. That is, 
any file that match any of these patterns will not be added to the database or
updated if already exists in the database. Below all the accepted patterns:

* `*.<ext>`    
all files with extension `<ext>`.    
*examples*: `*.py`, `*.cpp`

* `<file name>.*`   
all files named `<file name>` regardless the extension (note that the files
that exactly match `<file name>` will be ignored too).   
*examples*: `doc.*`, `log.*`, `README.*`

* `<file name>`    
all file names that exactly match `<file name>`.   
*examples*: `test.py`, `junk.txt`, `LICENSE` 

* `<file path>`  
all file paths that ends with '<file path>'.   
*examples*: `/doc/file.txt` (every 'file.txt' in a folder called 'doc'), `/Users/donald/file.txt` (a specific file.txt)

* `<path>/`  
all file paths that contains `<path>/`.   
*examples*: `doc/` (every file in a folder called 'doc')  

*default:* []

-------------------------------------------------------------------------------
<a name="ozzy_keep" />
**g:ozzy_keep**           

This option can be set to a number n >= 0 where n represent a number of days.
If set to 0 (default) this options simply do nothing. If set to a number n > 0,
then all the database entries (files) that have not been accessed in the
last n days  at least once will be automatically removed. This options may
helps to keep fresh and clean the database.

example: 
* let g:ozzy_keep = 30 (if a file registered in the database is not accessed for 30 days, it is removed)

*default:* 0

-------------------------------------------------------------------------------
<a name="ozzy_freeze" />
**g:ozzy_freeze**                                              

Set to 1 this variable and Ozzy will not add any new file to its database nor
will update any existent file. If you want to freeze Ozzy only for a brief
period of time during a vim session, you can toggle this option on and off 
with the *OzzyToggleFreeze* command.

*default:* 0    
