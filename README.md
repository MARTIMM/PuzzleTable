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

* [x] Gather the previously created puzzles from the several Palapeli collection directories and copy them elsewhere.
* [x] Use the Palapeli program of different install types, os standard, Snap or Flatpak.
* [x] Be able to make categories. Selecting a category shows the puzzles in that category thus displaying a smaller table.
* [x] Be able to rename categories.
* [ ] Show a larger picture of the puzzle. Also make a more puzzle like display e.g. ![](doc/puzzle-example.jpg) At the moment its just a larger image.
* [x] Show on the same picture how much is finished.
* [x] Add newly created and exported puzzles.
* [x] Remove a puzzle. It is stored in an archive.
* [x] Restore a puzzle.
* [x] Move puzzles to other categories.
* [x] Categories are shown in a sidebar
* [ ] Grouping categories in an expandable widget to narrow a long list.


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
* Gtk4 (having also Gdk4, Gsk4, Graphene,, Gio, GObject, Glib, Cairo, Pango libraries
* Icon themes from Gnome, Breeze and Adwaita

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
  * ['Freepik - Icon by judanna](https://www.freepik.com/icon/add_10110024#fromView=keyword&page=1&position=14&uuid=d07d88e3-b3e7-48da-9f3b-f1fc0703d53c)


<!--
* Icon from set ['Run icons created by Smashicons'](https://www.flaticon.com/free-icons/run).

* Icon from [Icons8](https://icons8.com/icon/ddoMPxn5moeM/girl-running).
-->