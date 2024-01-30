use v6.d;

# Dialog seems to be deprecated since 4.10 so here we have our own

use PuzzleTable::Config;
use PuzzleTable::Gui::DialogLabel;
use PuzzleTable::Gui::Statusbar;
use PuzzleTable::Gui::Category;

use Gnome::Gtk4::Window:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Enums:api<2>;
use Gnome::Gtk4::Window:api<2>;


#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Dialog:auth<github:MARTIMM>;
also is Gnome::Gtk4::Window;

has $!main is required;
has PuzzleTable::Config $!config;
has Gnome::Gtk4::Grid $!content;
has Gnome::Gtk4::Box $!button-row;

has PuzzleTable::Gui::Category $!cat;
has PuzzleTable::Gui::Statusbar $!statusbar;

#-------------------------------------------------------------------------------
method new ( |c ) {
#note "$?LINE ", c.gist;
  self.new-window(|c);
}

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main, Str :$dialog-header? ) {
  $!config = $!main.config;
  $!cat = $!main.category;

  my Gnome::Gtk4::Label $header .= new-label($!dialog-header);
  $!content .= new-grid;

  $!button-row .= new-box( GTK_ORIENTATION_HORIZONTAL, 4);
  with my Gnome::Gtk4::Label $!button-row-strut .= new-label('') {
    self.set-halign(GTK_ALIGN_FILL);
    self.set-hexpand(True);
  }
  $!button-row.append($!button-row-strut);

  $!statusbar .= new-statusbar(:context<dialog>);

  with my $grid .= new-grid {
    .attach( $header,      0, 0, 1, 1);
    .attach( $!content,    0, 1, 1, 1);
    .attach( $!button-row, 0, 2, 1, 1);
    .attach( $!statusbar,  0, 3, 1, 1);
  }

  self.register-signal( self, 'close-dialog', 'destroy');
  self.set-request-size( 300, 100);
  self.set-title($!dialog-header);
  self.set-child($grid);
}

#-------------------------------------------------------------------------------
method add-content ( Mu $widget, Int $row, Int $col, Int $width, Int $height ) {
  $!content( $widget, $row, $col, $width, $height);
}

#-------------------------------------------------------------------------------
method add-button ( $object, Str $method, Str $label, *%options ) {
  my Gnome::Gtk4::Button $button .= new-button;
  $button.set-label($label);
  $button.register-signal( $object, $method, 'clicked', *%options);
  $!button-row.append($button);
}

#-------------------------------------------------------------------------------
method clear-status ( ) {
  $!statusbar.remove-message;
}

#-------------------------------------------------------------------------------
method set-status ( Str $message ) {
  $!statusbar.remove-message;
  $!statusbar.set-status($message);
}

#`{{
#-------------------------------------------------------------------------------
method get-content ( Int $row, Int $col, Int $width, Int $height --> N-Object) {
  $!content.get-child-at( $row, $col, $width, $height);
}
}}

#-------------------------------------------------------------------------------
method close-dialog ( ) {
  self.clear-object;
}
