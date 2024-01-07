use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Init;

use Gnome::Gtk4::GridView:api<2>;
use Gnome::Gtk4::MultiSelection:api<2>;
use Gnome::Gtk4::SignalListItemFactory:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::ListItem:api<2>;
use Gnome::Gtk4::StringList:api<2>;
use Gnome::Gtk4::StringObject:api<2>;
use Gnome::Gtk4::Picture:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Table:auth<github:MARTIMM>;
also is Gnome::Gtk4::ScrolledWindow;

has PuzzleTable::Init $!table-init;

#has Gnome::Gio::ListStore $!puzzle-objects;
has Gnome::Gtk4::StringList $!puzzle-objects;
has Gnome::Gtk4::MultiSelection $!multi-select;
#has Gnome::Gtk4::SingleSelection $!single-select;
has Gnome::Gtk4::SignalListItemFactory $!signal-factory;
has Gnome::Gtk4::GridView $!puzzle-grid;
has Gnome::Gtk4::StringList $!string-list;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

  $!puzzle-objects .= new-stringlist(CArray[Str].new(Str));

  $!multi-select .= new-multiselection($!puzzle-objects);

  with $!signal-factory .= new-signallistitemfactory {
    .register-signal( self, 'setup-object', 'setup');
    .register-signal( self, 'bind-object', 'bind');
    .register-signal( self, 'unbind-object', 'unbind');
    .register-signal( self, 'destroy-object', 'teardown');
  }

  with $!puzzle-grid .= new-gridview( N-Object, N-Object) {
    .set-max-columns(10);
    .set-enable-rubberband(True);
    .set-model($!multi-select);
    .set-factory($!signal-factory);

    $!table-init.set-css( .get-style-context, :css-class<puzzle-grid>);
  }

  self.set-child($!puzzle-grid);
  self.set-hexpand(True);
  self.set-vexpand(True);
  $!table-init.set-css( self.get-style-context, :css-class<puzzle-table>);
}

#-------------------------------------------------------------------------------
method add-object-to-table ( Str $object-path ) {
#note "$?LINE add $object-path";
  $!puzzle-objects.append($object-path);
}

#-------------------------------------------------------------------------------
method setup-object ( N-Object $n-list-item ) {
  say 'setup-object';
  my Gnome::Gtk4::ListItem $list-item .= new(:native-object($n-list-item));
  with my Gnome::Gtk4::Picture $image .= new-picture {
    .set-size-request( 300, 300);
    .set-margin-top(3);
    .set-margin-bottom(3);
    .set-margin-start(3);
    .set-margin-end(3);
  }

  $list-item.set-child($image);
}

#-------------------------------------------------------------------------------
method bind-object ( N-Object $n-list-item ) {
  say 'bind-object';
  my Gnome::Gtk4::ListItem $list-item .= new(:native-object($n-list-item));
  my Gnome::Gtk4::Picture $image .= new(:native-object($list-item.get-child));

  my Gnome::Gtk4::StringObject $string-object .= new(
    :native-object($list-item.get-item)
  );

  $image.set-filename($string-object.get-string);
  $string-object.clear-object;
}

#-------------------------------------------------------------------------------
method unbind-object ( N-Object $n-list-item ) {
  say 'unbind-object';
}

#-------------------------------------------------------------------------------
method destroy-object ( N-Object $n-list-item ) {
  say 'destroy-object';
  my Gnome::Gtk4::ListItem $list-item .= new(:native-object($n-list-item));
  my Gnome::Gtk4::Picture $image .= new(:native-object($list-item.get-child));
  $image.clear-object;
}
