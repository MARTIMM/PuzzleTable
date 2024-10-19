
---

### TODO
* menu and toolbox for some menu entries
  * file
    * [ ] quit, add dialog in between
    * [ ] refresh sidebar
  * container
    * [x] add
    * [x] delete, only when empty
  * category
    * [x] add
    * [x] rename
    * [x] delete, only when empty
    * [ ] move a category
    * [x] lock
  * puzzle
    * [x] move selected puzzles
    * [x] archive selected puzzles
  * help
    * [x] about
    * [x] shortcut keys overview
    * [ ] user defined shortcuts

* command line
  * [x] add `--restore=<name>` option to restore an archive.
  * [ ] add `--palapeli=<type>` option to select preferred program.
  * [ ] add `--config=<path>[,<path>, …]` option to specify a preferred data location. This will be `~/.config/io.github.martimm.puzzle-table` by default. The program will use and store data in the following locations using this path. Note however that the css and images are still used from its default location and that puzzle-table-data and puzzle-trash are only looked for with this option.
    * `<path>`: data such as css files.
    * `<path>/images`: images for buttons.
    * `<path/puzzle-table-data`: data for puzzles.
    * `<path/puzzle-trash`: archiving of removed puzzles.
  * [ ] generating palapeli puzzles from commandline -> C++.

* shortcut keys
  * [x] `<CTRL>Q` to quit program

* program methods
  * [x] rename and move archiving operations into one module
  * [ ] drag and drop.
  * [x] remember state of an opened (expanded) container
  * [x] need to add key `<categories>` in containers to add other keys
  * [ ] add state info to containers to sum up states of contained categories
  * [x] importing puzzles should be shown in table and counts updated
  * update dialogs
    * [ ] work with focus and return chars in entries.
    * [x] show more space in a dialog. css font size.
    * [x] filled in values if possible on entries and drop down lists.
    * [x] extra dialogs to delete empty containers and categories
  * [x] puzzle table display update
  * [ ] fix needed; sometimes quit does not end program

* storage
  * [ ] When growing too large, configurations should be divided over several locations. Current default location is at `/home/marcel/.config/io.github.martimm.puzzle-table/` and has following files and directories
    * `images`. Not duplicated.
    * `puzzle-data.css`. Not duplicated.
    * `puzzle-table-data`. Here is the puzzle data stored, so it must be duplicated.
    * `puzzle-trash`. Here is the puzzle trash stored, so it must also be duplicated.
    The module **PuzzleTable::Config::Categories** gets the root already from an argument to BUILD() so we can maintain several instances of different roots. Also, the config file `categories.yaml` must be split because only the _containers_ key is different for the several roots.
    * [x] Split fixed portion in `categories.yaml` into `<root>/global-config.yaml`.
    * [ ] Because of this, the top level key in `categories.yaml` can be removed because we have moved the other toplevel keys to the `global-config.yaml`.
    * [ ] The instance of **PuzzleTable::Config::Categories** is saved in **PuzzleTable::Config**. Because of using handles on the class we cannot have an array to store several **::Categories** classes. So the solution to this is to maintain it in the **::Categories** class.
    * The program is fixed to a location in `~/.config`. This must now be controlled by new options. When options are absent the program defaults to the default location. The statement `has Hash $.categories-config;` found the module, can be extended holding a root path in its top level key while the the second level becomes the container name keys. The paths are unique. where the 
      * [ ] --root-global=\<path>. Option to set the location for all global data like the `<root>/config.yaml` and images. By default in the `~/.config` directory. This can be set only once when the first instance of the program starts.
      * [ ] --root-table=\<path>,\<path>,…. This points to the directory where the table data and trash archive is stored. This can be set multiple times and defaults to the path set by the --root-global option.

---
* 2924-- 0.8.0

* 2024-08-25 0.7.0
  * Moved code from **PuzzleTable::Gui::Table** to **PuzzleTable::Gui::TableItem**.

* 2024-08-20 0.6.0
  * DropDown widget and manipulations moved to **PuzzleTable::Gui::DropDown**.

* 2024-08-06 0.5.4
  * After playing with palapeli the sidebar statistics must be updated.

* 2024-07-04 0.5.3
  * Archiving is done for multiple puzzles in one archive instead of one per archive. Also the name now holds the category and container where it came from.
  * Restoring an archive.
  * Delete an empty container.
  * Delete an empty category.
  * State of an opened expander is saved as flag on the `containers` field.
  * Showing imported puzzles while in process of importing works again.

* 2024-06-27 0.5.2
  * Bugfix; Assignment of Hash in `get-puzzle()` in **PuzzleTable::Config::Category** changed to make a clone. Changes made elsewhere to the puzzle data were visible in original caused by assigning a scalar (=container) Hash.
  * Changed progress calculation using type **SetHash** instead of **Hash**.
  * Rename **PuzzleTable::ExtractDataFromPuzzle** to **PuzzleTable::Archive** and use it to handle all tasks to get puzzles and categories in and out of the puzzle table program.

* 2024-06-10 0.5.1
  * Implemented some prolonged details
    * Status overview in sidebar. It is stored together with categories config.
    * Update status of category when stopping puzzle game
    * Display Image in a tooltip hovering over sidebar

* 2024-05-24 0.5.0
  * Saving the config Hash costs about 7 to 10 secs. It is getting too slow, even that the config is only saved once every 5 changes or at shutdown. So, the config will be tored apart and saved per category on disk and only loaded and saved when some category is selected or switched.
  * The **PuzzleTable::Config** module is also getting too large with too many functions. So, this will be split up into smaller parts.
  * Add program `convert-puzzle-data` to split up the configuration file `puzzle-data.yaml` into smaller files. One file for categories `categories.yaml` and one for each category, `puzzles.yaml` in the category directory.
  * Merging the new modules in the application; overall merge completed and program works again. Some details have to be added stil.

* 2024-05-20 0.4.7
  * Lost a lot of progress files because I found it neccesary to reinstall the snap version of Palapeli, -sic-. So, a backup of the progresfile is needed. It will be placed in the directory where the puzzle resides after returning from the Palapeli program.

* 2024-05-19 0.4.6
  * Fixed a bug introduced with a newer version of Gio library.

* 2024-04-07 0.4.5
  * Adding an about dialog in a new module **PuzzleTable::Gui::Help**.

* 2024-04-01 0.4.4
  * Speeding up actions by not saving the admin at every change. Also changes are save in a thread.

* 2024-02-24 0.4.3
  * Added information to each category button
  * Changed css by taking a complete dark gtk.css theme from version 4. It is much more complete. E.g. selections are properly visible.

* 2024-02-22 0.4.2
  * Puzzle table changes are made visible by processing events while modifications take place/
  * Table is shown to build up when new puzzles are added.

* 2024-02-08 0.4.1
  * Use sha256 instead of sha1.
  * Original puzzle path is extended with a unique DateTime value before applying sha256.

* 2024-02-06 0.4.0
  * Use selections to remove puzzles. The puzzle data is archived in a trash directory in a bzipped tar file.
  * Calculation of progress is improved.

* 2024-01-18 0.3.3
  * Calculation of progress after stopping puzzle. Not ok yet for puzzles which are imported from directories or collections.
  * Selections are possible but it isn't visible using css.
  * Use selections to move puzzles into another category.

* 2024-01-13 0.3.2
  * Add password handling
  * Add category locking

* 2024-01-08 0.3.1
  * Add commandline options
    * **--version**. Show current version of distribution.
    * **--puzzles \<user puzzle>**. Import exported puzzles.
    * **--category \<name>**. By default `Default`. Created if not available. When `--puzzle` is used, the imported puzzles are placed in that category.
    * **--pala-export \<path to palapeli collection>**. Export puzzles from a Palapeli collection into a category.

* 2024-01-07 0.3.0
  * Got the puzzle table working using a StringList. Found an important [tutorial link](https://github.com/ToshioCP/Gtk4-tutorial/blob/main/gfm/sec29.md).
  * Modules Table added to manage the puzzletable.

* 2024-01-05 0.2.0
  * New modules for many and category manipulations and a statusbar
  * Actions to add and rename a category.

* 2024-01-03 0.1.1
  * Test program to unpack tar file with **Archive::Libarchive**.

* 2024-01-02 0.1.0
  * Setup
  * Basic windowing using **Gnome::Gtk4::Application**

