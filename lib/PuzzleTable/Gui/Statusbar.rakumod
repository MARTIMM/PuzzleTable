use v6.d;

use Gnome::Gtk4::Statusbar:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Statusbar:auth<github:MARTIMM>;
also is Gnome::Gtk4::Statusbar;

#-------------------------------------------------------------------------------
has guint $!context-id;

#-------------------------------------------------------------------------------
submethod BUILD ( Str :$context ) {
  $!context-id = self.get-context-id($context);
  self.set-halign(GTK_ALIGN_FILL);
  self.set-hexpand(True);
}

#-------------------------------------------------------------------------------
method set-status ( Str $text ) {
  self.push( $!context-id, $text);
}

#-------------------------------------------------------------------------------
method remove-message ( ) {
  self.remove-all($!context-id);
}