# Ozzy.vim

**v0.9.1**

Ozzy let you easily open files from the command line. It's pretty much a file
indexer that keeps track of the files you edit day by day. When you need to open
a specific file just use its name and depending on some criterion (customizable) 
the right file will be opened.


## Requirements

* vim 7.3+
* vim compiled with python 2.6+


## Installation

Use Pathogen or Vundle, no excuses.


## Basic usage

Ozzy is very straightforward to use. Once installed, you can start editing 
files as always. Once you open a file Ozzy keeps track of it and from then you
can open that file with the following command:

```
:Ozzy <file name>
```

How Ozzy knows the right file to open when there are two or more files with the
same name? Ozzy by default opens the file who has been opened more times. You
can customize this behavior setting the `g:ozzy_mode` variable to the
following values:

* `'most frequent'`: open the most frequently opened file.
* `'most recent'`: open the most recently opened file.
* `'context'`: open the closest file respect to the current working directory.

You are not limited to just file names. The `Ozzy` command accepts even partial
paths such as `:Ozzy directory/filename` and directory names such as 
`:Ozzy directory/`. In the latter case note the presence of a forward slash as
the last character: this cause Ozzy to open all the files contained in the
directory (note that only files tracked by Ozzy will be opened).

Command line `tab` completion is supported but only for file names.


## Commands

Here the list of all the available commands and their shortcuts (enabled with the
`g:ozzy_enable_shortcuts` option).


### Ozzy (O)
```
possible arguments:

* a file name
* a partial path (example: directory/filename)
* a path ending with a forward slash (example: directory/)
```

Depending to the type of the passed argument this command performs different
actions:

* if a file name is given then a file in the index that match the give name is
  opened (the right file is selected depending on the current mode: most
  frequent, most recent or context). See also the option `g:ozzy_ignore_ext`.

* if a partial path ending with a filename is given the the behavior descibed
  above is retained but there might be less potenyial conflicts.

* if a partial path ending with a forward slash is given the all files
  contained in that directory will be opened (only those files tracked by
  Ozzy). If Ozzy has in its index two or more directories with the same name, 
  the right one is selected according to the current mode:

  - `'most frequent'`: the directory that contains more frequently opened files is opened.
  - `'most recent'`: the directory that contains more recently accessed files is opened.
  - `'context'`: the closest directory is opened.
   
Note however that Ozzy does not really scan the physical directory on the file
system, but instead it will search exclusively in its database for possible
matches. You have to open files at least once manually or with the
OzzyAddDirectory command before Ozzy can open them.


### OzzyInspect (Oi)  

Opens the Inspector buffer. This place is where you can inspect the whole file
index and perform some actions on single entries like increasing the access
frequency, setting the last access time, doing various sorts, ecc.. For more
information about available actions type `?` inside the Inspector buffer.



### OzzyScope (Oscope)
```
possible arguments:

* an absolute path
* [. | .. | ...]
```   

Sets the Ozzy scope to the given path. By default the scope is global but once
you set it to a certain `path` Ozzy will be no more able to open files that
reside outside that `path`. Further, they will be no more indexed and
included command line completion. Already indexed files won't be removed:
you can still interact with them throughout the Inspector. If you want to add
all files contained into the current working directory you can use the `.`
shortcut instead. To add the current parent directory use the `..` argument.
Use the `...` argument to add the project root directory (see the
`g:ozzy_what_in_project_root` option). By default *Ozzy* assumes the project 
root directory as the one containing a `.git`, `.hg` or a `.svn` folder along 
the current working directory path.
To restore the global scope use the command with no arguments.

You can customize the default behavior with the following options:

* `-p <comma separated list>`: override the global `g:ozzy_what_in_project_root` options
  (works only with the special argument `...`)



### OzzyAddDirectory (Oadd)                   
```
possible arguments:

* an absolute path
* [. | .. | ...]
```        

To add all files contained into the given `path` (by default except those
contained into hidden directories). If you want to add all files contained into
the current working directory you can use the `.` shortcut instead. To add the
current parent directory use the `..` argument. Use the `...` argument to add
the project root directory (see the `g:ozzy_what_in_project_root` option). By
default *Ozzy* assumes the project root directory as the one containing
a `.git`, `.hg` or a `.svn` folder along the current working directory path.

You can customize the default behavior with the following options:

* `-h`: add files contained into hidden directories.

* `-a <comma separated list>`: add only specific files. See below for allowed patterns.

* `-i <comma separated list>`: ignore specific files. See below for allowed patterns. 

* `-p <comma separated list>`: override the global `g:ozzy_what_in_project_root` option
  (works only with the special argument `...`).

Allowed patterns:

* `*.<ext>`     
all file names with extension `<ext>`.     
*examples*: `*.py`, `*.cpp`

* `<file name>.*`   
all files named `<file name>` regardless the extension (file names that exactly match `<file name>` will be considered too).    
*examples*: `doc.*`, `log.*`, `README.*`

* `<file name>`    
all file names that exactly match `<file name>`.     
*examples*: `test.py`, `junk.txt`, `LICENSE` 

* `<partial path>/`   
all paths that contain `<path>`.    
*examples*: `doc/` (every file in a folder called 'doc') 



### OzzyRemove (Orm)      
```
possible arguments:

* a pattern (see below for allowed patterns)
* %
```

To remove from the index all the entries that match the given pattern. Use the
special `%` argument if you want to remove the current file.

Allowed patterns:

* `*.<ext>`     
all file names with extension `<ext>`.     
*examples*: `*.py`, `*.cpp`

* `<file name>.*`   
all files named `<file name>` regardless the extension (file names that exactly match `<file name>` will be removed too).    
*examples*: `doc.*`, `log.*`, `README.*`

* `<file name>`    
all file names that exactly match `<file name>`.     
*examples*: `test.py`, `junk.txt`, `LICENSE` 

* `<partial path>/`   
all paths that contain `<path>`.    
*examples*: `doc/` (every file in a folder called 'doc')  



### OzzyKeepLast (Okeep)
```
possible arguments:

* number [m | min | minute | minutes]  
* number [h | hour | hours]  
* number [d | day | days]  
* number [w | week | weeks]
    
where number >= 0
```

Removes all entries (files) from the index that have not been accessed at least
once in the last n (minutes, hours, days or weeks). This options might helps to
keep the index clean and ordinated.

Examples:

* `OzzyKeepLast 2 weeks`: removes all files not accessed in the last two weeks.



### OzzyReset (Orst)   

To remove all the entries from the database index.



### OzzyToggleMode (OTmode)            

To toggle between `most frequent`, `most recent` and `context` modes. See the `g:ozzy_mode` option.   



### OzzyToggleFreeze (OTfreeze)                                      

To toggle between `freeze on` and `freeze off` modes. See the `g:ozzy_freeze` option.    



### OzzyToggleExtension (OText)                                   

To toggle between `consider extension` and `ignore extensions` modes. See the
`g:ozzy_ignore_ext` option.


## Basic Settings

### g:ozzy_mode             

Set this variable to define the default behavior for opening files and command
line completion. Below all the available modes:

* `'most frequent'`: open the most frequently opened file.
* `'most recent'`: open the most recently opened file.
* `'context'`: open the closest file respect to the current working directory.

default: `'most frequent'`


### g:ozzy_db_path  

Set this variable to the path in which you want the database to be created.
By default the plugin directory is used.

default: `''` (the plugin directory is used)    


### g:ozzy_freeze  

Set this option to 1 and Ozzy will no more add or update any files in its
internal index but files already tracked will still be available for opening.

To freeze Ozzy only for a short period you can toggle this option on and off 
with the `OzzyToggleFreeze` command.

default: 0



### g:ozzy_ignore_ext     

Set this option to 1 Ozzy will ignore extension when serching in its index for
the right file to open.  Suppose that Ozzy has two entries in its database:
`/file.rb` and `/file.py` and this option is setted to 1: you can open any of
these two file just using their filename: `file`. Ozzy will open the right file
according to the current mode.

default: 1



### g:ozzy_scope

Set this option to an absolute path in order to limit the scope of the whole
Ozzy activity. That is, Ozzy will index, update and retrieve only files under
that path.  See also `OzzyScope` command.

default = ''



### g:ozzy_ignore  

This is a list containing naive patterns to tell Ozzy what to ignore. That is, 
any file that match any of these patterns will not be added to the database (or
updated if already indexed). Below the allowed patterns:

* `*.<ext>`     
all file names with extension `<ext>`.     
*examples*: `*.py`, `*.cpp`

* `<file name>.*`   
all files named `<file name>` regardless the extension (file names that exactly match `<file name>` will be considered too).    
*examples*: `doc.*`, `log.*`, `README.*`

* `<file name>`    
all file names that exactly match `<file name>`.     
*examples*: `test.py`, `junk.txt`, `LICENSE` 

* `<partial path>/`   
all paths that contain `<path>`.    
*examples*: `doc/` (every file in a folder called 'doc') 
         

default: []



### g:ozzy_keep                 

This option can be set to a number n &gt;= 0, where n represent a number of days.
If set to 0 this options simply do nothing. If set to a number n > 0,
then all the database entries (files) that have not been accessed in the
last n days at least once will be automatically removed. This options might
helps to keep clean the database.

example: 
* `let g:ozzy_keep = 30` : if an indexed file is not accessed for 30 days, it is removed.

default: 0   



### g:ozzy_what_in_project_root

This setting is a list of files or directories names used by Ozzy to determine
the current project root. That is, Ozzy assumes the project root directory
as the one containing a `.git`, `.hg` or a `.svn` folder along the current
working directory path. (option used in OzzyAddDirecory and OzzyScope commands)

default: ['.git', '.hg', '.svn']



### g:ozzy_ignore_case  

If set to 1, this option enables case insensitive command line completion and
files opening. This means you can type lowercase file names all the time  
regardless the real case.

default: 0    


## License

MIT


## Changelog

**v0.9.1**
* added new setting g:ozzy_db_path to set a custom database path.
* fixed possible conflicts with other plugins.

**v0.9.0**
* new inspector related options: 'g:ozzy_filter_inspector_by_scope',
  'g:ozzy_hide_scope_inspector', 'g:ozzy_show_env_inspector'.
* new mappings in the inspector buffer: 's', 'x', 'z', 'e'.

**v0.8.0**
* new OzzyScope command.
* backward incompatibility issue: 'most_recent' and 'most_frequent' modes renamed respectively to 'most recent' and 'most frequent'. Removed 'g:ozzy_open_files_recursively' option.

**v0.7.2** 
* fixed some behavior issues with OzzyAddDirectory, OzzyOpen commands and in the inspector buffer.

**v0.7.1**
* added useful information in the inspector buffer.
* more intelligent command line completion.
* in 'by distance' ordering files that have te same relative distance are ordered by last access time.  

**v0.7.0**
* better memory management.  
* support for filenames that contain non english characters.
* new arguments '..' and '...' for the OzzyAddDirectory command.
* new argument '%' for the OzzyRemove command.
* new 'c', '*' and '_' mappings in the Inspector buffer.
* command line completions can be ordered by relative distance to the cwd.
* minor bug fixes.
* backward incompatibility issue: the database managed by this version of Ozzy is no more compatible with databases created in previous versions. 

**v0.6.1**
* improved performances. 
* better cursor management inside the Inspector buffer.  
* fixed bug: inconsistent internal buffers management.

**v0.6.0**
* now Ozzy opens all files recursively when using the Ozzy command with a directory name as argument.   
* fixed bugs: error message using OzzyKeepLast command.  

**v0.5.0**
* added OzzyAddDirectory command to quickly add to the database all files contained into a given directory. 
* added case insensitive files opening and command line completion.
* fixed minor bugs.

**v0.4.0**
* improved command line completion.
* added new mode 'context'.
* fixed bugs: error when opening a file with spaces.

**v0.3.0**
* added ability to open multiple files at once.
* fixed bugs.

**v0.2.0**
* added command line completion.
* fixed bugs.

**v0.1.0** 
* first stable release.  