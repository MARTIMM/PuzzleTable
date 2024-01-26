use v6.d;

# Dialog seems to be deprecated since 4.10 so here we have our own

use Gnome::Gtk4::Window:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Dialog:auth<github:MARTIMM>;
also is Gnome::Gtk4::Window;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main, PuzzleTable::Gui::Category :$!cat ) {
  $!config = $!main.config;
}


