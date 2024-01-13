use v6.d;

use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::T-Enums:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::DialogLabel:auth<github:MARTIMM>;
also is Gnome::Gtk4::Label;

submethod BUILD ( Str :$lbl ) {
  self.set-text($lbl);
  self.set-hexpand(True);
  self.set-halign(GTK_ALIGN_START);
  self.set-name('dialog-label');
}

