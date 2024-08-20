use v6.d;

use PuzzleTable::Config;

use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::TableItemLabel:auth<github:MARTIMM>;
also is Gnome::Gtk4::Label;

constant \TableItemLabel is export = PuzzleTable::Gui::TableItemLabel;

#-------------------------------------------------------------------------------
#method new ( |c ) {
#  self.new-label( Str, |c);
#}

#-------------------------------------------------------------------------------
submethod BUILD ( Bool :$align = True, Str :$css-class ) {
  my PuzzleTable::Config $config .= instance;

  self.set-hexpand(True);
  self.set-halign(GTK_ALIGN_START) if $align;
  if ?$css-class {
#    self.set-name('table-item-' ~ $css-class);
    $config.set-css( self.get-style-context, :css-class('table-item-' ~ $css-class));
  }

  else {
#    self.set-name('table-item-label');
    $config.set-css( self.get-style-context, :css-class('table-item-label'));
  }
}

