
### TODO
* [ ] container delete, only when empty
* [ ] category delete, only when empty
* [x] archive selected puzzles
* [x] restore archived puzzles
* [ ] move category without renaming the category
* [ ] rename and move archiving operations into one module
* [ ] drag and drop. On wayland a lot is going wrong!
* [ ] remember state of an opened container
* [x] need to add key `<categories>` in containers to add other keys
* [ ] add state info to containers to sum up states of contained categories
* [ ] importing puzzles should be shown in table and counts updated
* [ ] generating palapeli puzzles from commandline -> C++
* [x] add `--restore=<name>` option to restore an archive.
* [ ] add `--palapeli=<type>` option to select preferred program.
* [ ] add `--puzzle-table-root=<path>` option to specify a preferred data location. The program will use and store data in the following locations using this path;
  * `<path>`: data such as css files.
  * `<path>/images`: images for buttons.
  * `<path/puzzle-table-data`: data for puzzles.
  * `<path/puzzle-trash`: archiving of removed puzzles.

* 2024-07-04 0.5.3
  * Archiving is done for multiple puzzles in one archive instead of one per archive. Also the name now holds the category and container where it came from.
  * Restoring an archive.

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

