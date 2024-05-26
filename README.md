# Puzzle table display

## Purpose

Display a table of puzzles made by Palapeli, a linux puzzle game.

The Palapeli puzzle program is a great program to play with. However, the display of the puzzles I would like to change it a bit. There are issues posted at the repository but the developer has many other things to do and therefore there is slow progress in the development of Palapeli.

I am also working on a language binding between Raku and the Gnome libraries to create all sorts of graphical interfaces. To test the modules out I thought that this project would be a nice start to see if the Raku modules work properly.


### What to implement

Nothing which works fine with Palapeli;

* Create new puzzles and export them.
* Playing a puzzle.
* Starting a puzzle from commandline.

And a small list of things to change in the puzzle table program;

* The puzzle table of Palapeli has a large field of all puzzles in it. You can order it by name or by the number of pieces.
* The picture of the puzzle is small.
* There is no information about the progress of a puzzle. The only way to get this info is by starting the puzzle.

What the new program should do

* Gather the previously created puzzles from the installation collections and copy them elsewhere.
* Be able to rename puzzles.
* Be able to make categories from names or otherwise. Selecting a category shows the puzzles in that category thus displaying a smaller table.
* Show a larger picture of the puzzle. Also make a more puzzle like display e.g.
  ![](doc/puzzle-example.jpg)
* Show on the same picture how much is finished.
* Add newly created and exported puzzles.


## Description
<!--

When the program is started for the first time, there will be nothing to show. From the menu you will be able to select a Palapeli collection. To give an idea where to find the collections of several types of installations;
* the snap installation at: `$*HOME/snap/palapeli/current/.local/share/palapeli/collection`;
* the flatpack installation at: `$*HOME/.var/app/org.kde.palapeli/data/palapeli/collection`
* the standard installation at: `$*HOME/.local/share/palapeli/collection/`

These are paths at my Fedora OS but you may get a hint where to find them on your computer.

You can point to directories where you have stored exported puzzles.
-->

## Dependencies

Working on the Linux OS the use of the programs and libraries are oriented to that OS. Most libraries and programs might be available on Windows or Apple systems but I do not have any experience on the locations of the software or any way to install them.

### Programs and libraries

* Palapeli
* ImageMagick
* Gtk4, Gio, GObject, Glib, Pango libraries

### Raku modules

* Gnome::Gtk4:api<2>
* Archive::Libarchive
* Getopt::Long
* Digest::SHA256::Native

<!--
* Gnome::Cairo:api<2>
* Gnome::Gsk4:api<2>
* Gnome::Atk:api<2>
-->

# Attribution
## Icons
* Ions from
  * ['FlatIcon - bayu015'](https://www.flaticon.com/free-icons/category)
  * ['FlatIcon - twentyfour'](https://www.flaticon.com/free-icons/grid)
  * ['FlatIcon - Anggara'](https://www.flaticon.com/free-icons/categories)
  * ['FlatIcon - mynamepong'](https://www.flaticon.com/free-icons/puzzle)
  * ['FlatIcon - paonkz'](https://www.flaticon.com/free-icons/files-and-folders)

<!--
* Icon from set ['Run icons created by Smashicons'](https://www.flaticon.com/free-icons/run).

* Icon from [Icons8](https://icons8.com/icon/ddoMPxn5moeM/girl-running).
-->