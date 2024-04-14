
use v6.d;

# Setup temporary paths to Gtk4 development area
use lib
  "/home/marcel/Languages/Raku/Projects/gnome-source-skim-tool/gnome-api2/gnome-native/lib",
  "/home/marcel/Languages/Raku/Projects/gnome-source-skim-tool/gnome-api2/gnome-glib/lib",
  "/home/marcel/Languages/Raku/Projects/gnome-source-skim-tool/gnome-api2/gnome-gobject/lib",
  "/home/marcel/Languages/Raku/Projects/gnome-source-skim-tool/gnome-api2/gnome-gio/lib",
  "/home/marcel/Languages/Raku/Projects/gnome-source-skim-tool/gnome-api2/gnome-gdkpixbuf/lib",
  "/home/marcel/Languages/Raku/Projects/gnome-source-skim-tool/gnome-api2/gnome-pango/lib",
#  "/gnome-cairo/lib",
#  "/gnome-atk/lib",
  "/home/marcel/Languages/Raku/Projects/gnome-source-skim-tool/gnome-api2/gnome-gtk4/lib",
  "/home/marcel/Languages/Raku/Projects/gnome-source-skim-tool/gnome-api2/gnome-gdk4/lib",
#  "/gnome-gsk4/lib"
  ;

use Gnome::Gtk4::Label:api<2>;
use PuzzleTable::Gui::DialogLabel;
use Gnome::Gtk4::T-enums:api<2>;

use Gnome::N::X:api<2>;
Gnome::N::debug(:on);




my Gnome::Gtk4::Label $l .= new-label('abc');
note "$?LINE ", $l.get-label;

my DialogLabel $dl .= new-label('def');
note "$?LINE ", $dl.get-label;

class ML {
  also is Gnome::Gtk4::Label;

  submethod BUILD (  ) {
    self.set-hexpand(True);
    self.set-halign(GTK_ALIGN_START);
    self.set-name('dialog-label');
  }
}


my ML $ml .= new-label('pqr');
note "$?LINE ", $ml.get-label;
