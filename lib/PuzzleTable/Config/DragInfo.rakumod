use v6.d;

use Gnome::Gtk4::N-Bitset:api<2>;
use Gnome::Gdk4::ContentProvider:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::T-types:api<2>;

use Gnome::Gdk4::Drag:api<2>;
#use Gnome::Gdk4::Drop:api<2>;

use Gnome::GObject::T-type:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use PuzzleTable::Types;
use PuzzleTable::Config;

use GnomeTools::Gtk::DND;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::DragInfo;

has PuzzleTable::Config $!config;

has GnomeTools::Gtk::DND $!dnd;
has Str $!drag-content;
#has Str $!puzzles;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!config .= instance;
  $!drag-content = '';
  $!dnd .= new;
}

#-------------------------------------------------------------------------------
my PuzzleTable::Config::DragInfo $instance;
method instance ( ) {
  $instance //= self.bless();

  $instance
}

#-------------------------------------------------------------------------------
method setup-drag ( ) {
  my Str $path = DATA_DIR ~ 'images/icons8-drag-64.png';
  with my Gnome::Gtk4::Picture $image .= new-for-filename($path) {
    .set-content-fit(GTK_CONTENT_FIT_SCALE_DOWN);
    .set-can-shrink(True);
    .set-size-request( 64, 64);
  }

  $*main-window.toolbar.append($image);

  $!dnd.set-dragsource( self, $image, '');
}

#`{{
#-----------------------------------------------------------------------------
method set-root ( Str $!root ) { }

#-----------------------------------------------------------------------------
method set-container ( $!container ) { }

#-----------------------------------------------------------------------------
method set-puzzles ( Str $!puzzles ) {
  note "select $!puzzles";
}
}}

#-----------------------------------------------------------------------------
method drag-prepare (
  Rat() $x, Rat() $y,
  Gnome::Gtk4::DragSource() :_native-object($source),
  --> N-Object
) {
note "\ndrag-begin: $x, $y";
  my Gnome::Gtk4::N-Bitset $bitset .=
    new(:native-object($*main-window.table.multi-select.get-selection));

  my Array $puzzles = [];
  my Int $n = $bitset.get-size;
  for ^$n -> $i {
    $puzzles.push: $bitset.get-nth($i);
  }

  my Str $root = $!config.get-current-root;
  my Str $container = $!config.get-current-container;
  my Str $category = $!config.get-current-category;
  $!drag-content =
    ( $root, $container, $category, $puzzles.join(' ') ).join('_||_')
    if ?$puzzles;

  # Set content. Can use multiple strings. Interface has variable list solved
  # by providing pairs of type/value. In this case gchar-ptr/$!drag-content
  my Gnome::Gdk4::ContentProvider $cp .= new-typed(
    G_TYPE_STRING, gchar-ptr, $!drag-content
  );

  # Must return native content provider object
  $cp.get-native-object-no-reffing
}

#-----------------------------------------------------------------------------
method drag-begin (
  Gnome::Gdk4::Drag() $drag,
  Gnome::Gtk4::DragSource() :_native-object($source),
  Gnome::Gtk4::Picture :$pic,
) {
  note "\ndrag-begin";
#    $ds.set-icon( $pic.get-paintable, -20, 20);

  # Set content. Can use multiple strings. Interface has variable list solved
  # by providing pairs of type/value. In this case gchar-ptr/$!drag-content
  my Gnome::Gdk4::ContentProvider $cp .= new-typed(
    G_TYPE_STRING, gchar-ptr, 'root', gchar-ptr, 'container', gchar-ptr, 'puzzles'
  );
  $source.set-content($cp);
}

#`{{
#-----------------------------------------------------------------------------
method drag-end ( Gnome::Gdk4::Drag() $drag, Bool() $delete-data ) {
  note "drag-end: delete data $delete-data";
}

#-----------------------------------------------------------------------------
method drag-cancel ( Gnome::Gdk4::Drag() $drag, UInt $reason --> Bool ) {
  note "drag-cancel: $reason";
}
}}


