
use v6.d;

use PuzzleTable::Gui::Dialog;

use Gnome::Gtk4::Label:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::MessageDialog:auth<github:MARTIMM>;
also is PuzzleTable::Gui::Dialog;

has $!main is required;

#-------------------------------------------------------------------------------
submethod BUILD ( Str :$message, :$!main ) {
  self.add-content( $message, Gnome::Gtk4::Label.new-label);
  self.set-title('Message Dialog');

  self.add-button( self, 'destroy-dialog', 'Ok');
  self.show-dialog;
}

