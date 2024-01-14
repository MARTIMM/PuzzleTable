use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Config;

use Gnome::Gtk4::GridView:api<2>;
use Gnome::Gtk4::MultiSelection:api<2>;
use Gnome::Gtk4::SignalListItemFactory:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::ListItem:api<2>;
use Gnome::Gtk4::StringList:api<2>;
use Gnome::Gtk4::StringObject:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::T-Enums:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Table:auth<github:MARTIMM>;
also is Gnome::Gtk4::ScrolledWindow;

has PuzzleTable::Config $!config;

has Gnome::Gtk4::StringList $!puzzle-objects;
has Gnome::Gtk4::MultiSelection $!multi-select;
#has Gnome::Gtk4::SingleSelection $!single-select;
has Gnome::Gtk4::SignalListItemFactory $!signal-factory;
has Gnome::Gtk4::GridView $!puzzle-grid;
has Gnome::Gtk4::StringList $!string-list;

#| The objects from the current selected category
has Hash $!current-table-objects;

#-------------------------------------------------------------------------------
submethod BUILD ( PuzzleTable::Config :$!config ) {

  $!current-table-objects = %();

  $!puzzle-objects .= new-stringlist(CArray[Str].new(Str));

  $!multi-select .= new-multiselection($!puzzle-objects);

  with $!signal-factory .= new-signallistitemfactory {
    .register-signal( self, 'setup-object', 'setup');
    .register-signal( self, 'bind-object', 'bind');
    .register-signal( self, 'unbind-object', 'unbind');
    .register-signal( self, 'destroy-object', 'teardown');
  }

  with $!puzzle-grid .= new-gridview( N-Object, N-Object) {
    .set-max-columns(8);
    .set-enable-rubberband(True);
    .set-model($!multi-select);
    .set-factory($!signal-factory);

    $!config.set-css( .get-style-context, :css-class<puzzle-grid>);
  }

  self.set-child($!puzzle-grid);
  self.set-hexpand(True);
  self.set-vexpand(True);
  $!config.set-css( self.get-style-context, :css-class<puzzle-table>);
}

#-------------------------------------------------------------------------------
method add-object-to-table ( Hash $object ) {

  # Save the index and drop some other field to save memory
  my Str $index = $object<Puzzle-index>:delete;
  $object<Name>:delete;
  $object<SourceFile>:delete;
  $object<Progess> = 0;
  $!current-table-objects{$index} = $object;
  $!puzzle-objects.append($index);
}

#-------------------------------------------------------------------------------
method clear-table ( ) {
#note "$?LINE add $object-path";
  while $!puzzle-objects.get-string(0).defined {
    $!puzzle-objects.remove(0);
  }

  $!current-table-objects = %();
}

#-------------------------------------------------------------------------------
method setup-object ( Gnome::Gtk4::ListItem() $list-item ) {
#method setup-object ( N-Object $n-list-item ) {
#say 'setup-object';
#  my Gnome::Gtk4::ListItem $list-item .= new(:native-object($n-list-item));

  with my Gnome::Gtk4::Picture $image .= new-picture {
    .set-size-request( 300, 300);
    .set-margin-top(3);
    .set-margin-bottom(3);
    .set-margin-start(3);
    .set-margin-end(3);
  }

  with my Gnome::Gtk4::Label $label-comment .= new-label(Str) {
    .set-hexpand(True);
#    .set-halign(GTK_ALIGN_START);

    $!config.set-css( .get-style-context, :css-class<puzzle-object-comment>);
  }

  with my Gnome::Gtk4::Label $label-npieces .= new-label(Str) {
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_START);
  }

  with my Gnome::Gtk4::Label $label-size .= new-label(Str) {
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_START);
  }

  with my Gnome::Gtk4::Label $label-source .= new-label(Str) {
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_START);
  }

  with my Gnome::Gtk4::Label $label-progress .= new-label(Str) {
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_START);
  }

  with my Gnome::Gtk4::Box $box .= new-box( GTK_ORIENTATION_VERTICAL, 0) {
    .append($image);
    .append($label-comment);
    .append($label-size);
    .append($label-npieces);
    .append($label-source);
    .append($label-progress);

    $!config.set-css( .get-style-context, :css-class<puzzle-object>);
  }

  $list-item.set-child($box);
}

#-------------------------------------------------------------------------------
method bind-object ( Gnome::Gtk4::ListItem() $list-item ) {

  my Gnome::Gtk4::StringObject $string-object .= new(
    :native-object($list-item.get-item)
  );

  my Gnome::Gtk4::Box() $box = $list-item.get-child;
  my Gnome::Gtk4::Picture() $image = $box.get-first-child;
  my Gnome::Gtk4::Label() $label-comment = $image.get-next-sibling;
  my Gnome::Gtk4::Label() $label-size = $label-comment.get-next-sibling;
  my Gnome::Gtk4::Label() $label-npieces = $label-size.get-next-sibling;
  my Gnome::Gtk4::Label() $label-source = $label-npieces.get-next-sibling;
  my Gnome::Gtk4::Label() $label-progress = $label-source.get-next-sibling;

  my Hash $object = $!current-table-objects{$string-object.get-string};
  $image.set-filename($object<Image>);
  $label-comment.set-text($object<Comment>);
  $label-size.set-text(
    [~] 'Picture size: ', $object<Width>, ' x ', $object<Height>
  );
  $label-npieces.set-text('Nbr pieces: ' ~ $object<PieceCount>);
  $label-source.set-text('Source: ' ~ $object<Source>);
  $label-progress.set-text('Progress: ' ~ $object<Progess> ~ ' %');

  $string-object.clear-object;
}

#-------------------------------------------------------------------------------
method unbind-object ( Gnome::Gtk4::ListItem() $list-item ) {
}

#-------------------------------------------------------------------------------
method destroy-object ( Gnome::Gtk4::ListItem() $list-item ) {
  my Gnome::Gtk4::Box() $box = $list-item.get-child;
  $box.clear-object;
}
