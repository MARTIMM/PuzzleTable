use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Init;
use PuzzleTable::ExtractDataFromPuzzle;

use Gnome::Gtk4::GridView:api<2>;
#use Gnome::Gtk4::MultiSelection:api<2>;
use Gnome::Gtk4::SingleSelection:api<2>;
use Gnome::Gtk4::SignalListItemFactory:api<2>;
use Gnome::Gtk4::Frame:api<2>;
#use Gnome::Gtk4::CssProvider:api<2>;
#use Gnome::Gtk4::StyleContext:api<2>;
#use Gnome::Gtk4::T-StyleProvider:api<2>;

use Gnome::Gtk4::Image:api<2>;

use Gnome::Gio::ListStore:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Table:auth<github:MARTIMM>;
also is Gnome::Gtk4::Frame;

has PuzzleTable::Init $!table-init;

has Gnome::Gio::ListStore $!puzzle-objects;
#has Gnome::Gtk4::MultiSelection $!multi-select;
has Gnome::Gtk4::SingleSelection $!single-select;
has Gnome::Gtk4::SignalListItemFactory $!signal-factory;
has Gnome::Gtk4::GridView $!puzzle-grid;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

  # Set gtype for image
  my Gnome::Gtk4::Image $image .= new-image;
  $!puzzle-objects .= new-liststore($image.get-class-gtype);
  $image.clear-object;

#  $!multi-select .= new-multiselection($!puzzle-objects);
  $!single-select .= new-singleselection($!puzzle-objects);
  $!signal-factory .= new-signallistitemfactory;
#  with $!puzzle-grid .= new-gridview( $!multi-select, $!signal-factory) {
  with $!puzzle-grid .= new-gridview( $!single-select, $!signal-factory) {
    .set-max-columns(10);
    $!table-init.set-css( .get-style-context, :css-class<puzzle-grid>);
  }

  self.set-label-align(0.03);
  self.set-child($!puzzle-grid);
  self.set-hexpand(True);
  self.set-vexpand(True);
  $!table-init.set-css( self.get-style-context, :css-class<puzzle-table-frame>);
}

#-------------------------------------------------------------------------------
method add-object-to-table ( Str $object-path ) {
  with my Gnome::Gtk4::Image $image .= new-from-file($object-path) {
    .set-size-request( 300, 300);
#    $!table-init.set-css( .get-style-context, :css-class<puzzle-object>);
  }

  $!puzzle-objects.append($image);
}