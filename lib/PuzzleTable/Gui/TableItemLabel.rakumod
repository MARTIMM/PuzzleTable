use v6.d;

use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::TableItemLabel:auth<github:MARTIMM>;
also is Gnome::Gtk4::Label;

constant \TableItemLabel is export = PuzzleTable::Gui::TableItemLabel;

#-------------------------------------------------------------------------------
method new ( |c ) {
  self.new-label( Str, |c);
}

#-------------------------------------------------------------------------------
submethod BUILD ( Bool :$align = True, Str :$css, :$config ) {
  self.set-hexpand(True);
  self.set-halign(GTK_ALIGN_START) if $align;
  if ?$css {
#    self.set-name('table-item-' ~ $css);
    $config.set-css( self.get-style-context, :css-class('table-item-' ~ $css));
  }

  else {
#    self.set-name('table-item-label');
    $config.set-css( self.get-style-context, :css-class('table-item-label'));
  }
}

