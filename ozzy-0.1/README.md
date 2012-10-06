# Ozzy.vim

**v0.1 beta**


Ozzy allows you to open frequently or recently used files from anywhere. Just
give a file name and (if the file has been accessed at leat once in the past)
the most frequently used file or the most recently accessed one is picked for 
you, no more entire paths to digit or folder to cd into!


## Installation

Install into `.vim/plugin/ozzy.vim` or better, use Pathogen.

requirements:

* vim 7.3 or later
* vim compiled with python 2.6 or above


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
used file. 
Suppose now Ozzy has in its database a lot of files with the same name such as `README`
files. If opening the most frequently or recently used `README` does not fit your
needs you can still specify a partial path of tha file you want to open:

```
:Ozzy <partial path>/<file name>
```


<a name="ozzy-modes" />
## Modes
 
A mode determines how Ozzy chooses the right file to open when it is faced with
a buch of file paths in its database that match the file  the user want to 
open. There are mainly two modes available: 

* `most frequent`: the most frequently used file is opened.

* `most recent`: the most recently used file is opened.

The default mode is 'most frequent' but you can toggle between the two modes 
during a vim session with the [OzzyToggleMode](#ozzy-toggle-mode) command or set the default mode 
by setting the [g:ozzy_mode](#ozzy_mode) option.


## Freeze ozzy
 
When Ozzy is frozen it does not update its database every time you open a file.
Though, you can still use all of the Ozzy commands. If you want to freeze Ozzy
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
    key   action
    ---   --------------------------------------------
    q     quit inspector
    ?     toggle help
    p     toggle between absolute and relative to home paths
    f     order records by frequency
    a     order records by date and time
    r     reverse the current records order
    o     open the file on the current line
    +     increase the frequency of the file on the current line
    -     decrease the frequency of the file on the current line
    t     touch the file on the current line (set its last access attribute to now)
    dd    remove from the list the record under the cursor (or an entire selection)

    Note: The current line is the line where the cursor is positioned.
          To move up and down the records list use the classic hjkl keys.
```

## Commands

**Ozzy &lt;file name&gt;**  
shortcut: O

If Ozzy has in its database a file that match the given `<file name>`, then it is
opened. See [Modes](#ozzy-modes) to find out how to change the behaviour of this
command when there are two or more files that match the given `<file name>`.

**OzzyInspect**                                                        
shortcut: Oi

Open the database inspector.    
See also [Inspector](#ozzy-inspector).

**OzzyRemove &lt;pattern&gt;**                                           
shortcut: Orm

To remove from the database all the files that match the given pattern. Below
the accepted patterns:

* `*.<ext>`     
all files with extension `<ext>`.
examples: `*.py`, `*.cpp`

* `<file name>.*`   
all files named `<file name>` regardless the extension (note that the files
that exactly match `<file name>` will be removed too).
examples: `doc.*`, `log.*`, `README.*`

* `<file name>`    
all file names that exactly match `<file name>`.
examples: `test.py`, `junk.txt`, `LICENSE` 

* `<file path>`   
all file paths that ends with '<file path>'.
examples: `/doc/file.txt` (every 'file.txt' in a folder called 'doc'), `/Users/donald/file.txt` (a specific file.txt)

* `<path>/`   
all file paths that contains `<path>/`.
examples: `/doc/` (every file in a folder called 'doc')    


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


**OzzyReset**                                                   

To remove all files entries from the database.


<a name="ozzy-toggle-mode" />
**OzzyToggleMode**                                            

To toggle between `most frequent` and `most recent` modes.   
See also [Modes](#ozzy-modes) and the [g:ozzy_mode+(#ozzy-mode) option. 


<a name="ozzy-toggle-freeze" />
**OzzyToggleFreeze**                                        

To toggle between `freeze on` and `freeze off` modes.    
See also [Ozzy freeze](#ozzy-freeze) and the [g:ozzy_freeze](#ozzy_freeze) option. 


**OzzyToggleExtension**                                   

To toggle between `consider extension` and `ignore extensions` mode.    
See also the [g:ozzy_ignore_ext](#ozzy_ignore_ext) option.     


## Settings

<a name="ozzy_mode" />
**g:ozzy_mode**                                                    

Set this variable to define the default behaviour for opening files. 
Below all the available modes:

* `most_frequent`: the most used file with the given name is opened.
* `most_recent`: the most recently accessed file is opened.

*default:* 'most_frequent'



<a name="ozzy_freeze" />
**g:ozzy_freeze**                                              

Set to 1 this variable and Ozzy will not add any new file to its database nor
will update any existent file. If you want to freeze Ozzy only for a brief
period of time during a vim session, you can toggle this option on and off 
with the *OzzyToggleFreeze* command.

*default:* 0


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


<a name="ozzy_ignore" />
**g:ozzy_ignore**                                             

This is a list containing naive patterns that tell Ozzy what to ignore. That is, 
any file that match any of these patterns will not be added to the database or
updated if already exists in the database. Below all the accepted patterns:

* `*.<ext>`    
all files with extension `<ext>`.    
examples: `*.py`, `*.cpp`

* `<file name>.*`   
all files named `<file name>` regardless the extension (note that the files
that exactly match `<file name>` will be ignored too).   
examples: `doc.*`, `log.*`, `README.*`

* `<file name>`    
all file names that exactly match `<file name>`.   
examples: `test.py`, `junk.txt`, `LICENSE` 

* `<file path>`  
all file paths that ends with '<file path>'.   
examples: `/doc/file.txt` (every 'file.txt' in a folder called 'doc'), `/Users/donald/file.txt` (a specific file.txt)

* `<path>/`  
all file paths that contains `<path>/`.   
examples: `/doc/` (every file in a folder called 'doc')  

*default:* []


**g:ozzy_keep**                                       

This option can be set to a number n >= 0 where n represent a number of days.
If set to 0 (default) this options simply do nothing. If set to a number n > 0,
then all the database entries (files) that have not been accessed in the
last n days  at least once will be automatically removed. This options may
helps to keep fresh and clean the database.

example: 
* let g:ozzy_keep = 30 (if a file registered in the database is not accessed for 30 days, it is removed)

*default:* 0


**g:ozzy_enable_shortcuts**                           

If set to 1, this option enables the commands shortcut. Below all the available 
commands shortcuts with their respective 'long version':

* O : Ozzy
* Oi : OzzyInspect
* Orm : OzzyRemove
* Okeep : OzzyKeepLast

*default:* 1


**g:ozzy_most_frequent_flag**                       

This option represent the flag returned by the `OzzyModeFlag()` function when the 
current mode is set to `most_frequent`. 

*default:* 'F'

**g:ozzy_most_recent_flag**                         

This option represent the flag returned by the `OzzyModeFlag()` function when the 
current mode is set to `most_recent`.

*default:* 'R'

**g:ozzy_freeze_off_flag**                          
 
This option represent the flag returned by the `OzzyFreezeFlag()` function when 
Ozzy is not frozen.

*default:* ''

**g:ozzy_freeze_on_flag**                             

This option represent the flag returned by the `OzzyFreezeFlag()` function when 
Ozzy is frozen.  

*default:* 'freeze'
                                       

## Changelog

* **v0.1**: beta release
