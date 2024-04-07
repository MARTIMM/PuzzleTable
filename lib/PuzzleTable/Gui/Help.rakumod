use v6.d;
#use NativeCall;

use PuzzleTable::Types;

use Gnome::Gtk4::AboutDialog:api<2>;
use Gnome::Gtk4::T-AboutDialog:api<2>;

use Gnome::Gdk4::Texture:api<2>;

use Gnome::Gio::File:api<2>;

use Gnome::Glib::T-error:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Help:auth<github:MARTIMM>;

has Gnome::Gtk4::AboutDialog $!about-dialog;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
}

#-------------------------------------------------------------------------------
method help-about ( N-Object $parameter ) {
#  say 'help about';
  
  $!about-dialog.clear-object if ?$!about-dialog and $!about-dialog.is-valid;

  my Str $logo-path = [~] DATA_DIR, 'images/puzzle-table-logo.png';
  %?RESOURCES<puzzle-table-logo.png>.copy($logo-path) unless $logo-path.IO.e;
  my Gnome::Gio::File $file .= new-for-path($logo-path);
  my Gnome::Gdk4::Texture $logo .= new-from-file( $file, N-Error);

  with $!about-dialog .= new-aboutdialog {
    .set-program-name('puzzle-table');
    .set-version('0.4.5');
    .set-copyright('© Marcel Timmerman - MARTIMM on github');
    .set-comments(q:to/EOC/);
        The puzzle table program is used to display a number of
        puzzles separated in several categories. The Palapeli
        program is run to play the jigsaw puzzle.
        EOC
    .set-wrap-license(True);
    .set-license-type(GTK_LICENSE_ARTISTIC);
    .set-authors(['Marcel Timmerman']);
    .set-logo($logo);

    .show;
  }
}

