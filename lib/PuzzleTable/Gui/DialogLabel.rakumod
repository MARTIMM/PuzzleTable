use v6.d;

use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::T-Enums:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::DialogLabel:auth<github:MARTIMM>;
also is Gnome::Gtk4::Label;

constant \DialogLabel is export = PuzzleTable::Gui::DialogLabel;

#-------------------------------------------------------------------------------
method new ( Str $text ) {
  self.new-label( Str, :$text);
}

#-------------------------------------------------------------------------------
submethod BUILD ( :$text ) {
  self.set-label($text);
  my $no = self.get-native-object-no-reffing;
  self.set-hexpand(True);
  self.set-halign(GTK_ALIGN_START);
  self.set-name('dialog-label');
}

