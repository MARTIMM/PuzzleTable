
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

