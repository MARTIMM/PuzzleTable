use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::TableItem;

use Gnome::Gtk4::GridView:api<2>;
use Gnome::Gtk4::MultiSelection:api<2>;
use Gnome::Gtk4::SignalListItemFactory:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::N-Bitset:api<2>;
use Gnome::Gtk4::StringList:api<2>;
use Gnome::Gtk4::ListItem:api<2>;
use Gnome::Gtk4::StringObject:api<2>;

use Gnome::Glib::N-MainLoop:api<2>;
use Gnome::Glib::N-MainContext:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
=begin pod
=head1

A note from https://developer-old.gnome.org/gtk4/stable/ListContainers.html;

Another important requirement for views is that they need to know which items are not visible so they can be recycled. Views achieve that by implementing the GtkScrollable interface and expecting to be placed directly into a GtkScrolledWindow. 

=end pod

unit class PuzzleTable::Gui::Table:auth<github:MARTIMM>;
also is Gnome::Gtk4::ScrolledWindow;



has $!main is required;
has PuzzleTable::Config $!config;

has Gnome::Gtk4::StringList $.puzzle-objects;
has Gnome::Gtk4::MultiSelection $.multi-select;
has Gnome::Gtk4::SignalListItemFactory $!signal-factory;
has Gnome::Gtk4::GridView $!puzzle-grid;

# The objects from the current selected category
has Hash $!current-table-objects;
has Gnome::Glib::N-MainContext $!main-context;

has Hash $!puzzles-playing = %();

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {

  $!main-context .= new-maincontext(
    :native-object(
      Gnome::Glib::N-MainLoop.new-mainloop( N-Object, True).get-context()
    )
  );

  $!config .= instance;

  self.set-halign(GTK_ALIGN_FILL);
  self.set-vexpand(True);
  self.set-propagate-natural-width(True);

  self.clear-table(:init);
}

#-------------------------------------------------------------------------------
method clear-table ( Bool :$init = False ) {

  $!current-table-objects = %();

  unless $init {
    $!puzzle-objects.clear-object;
    $!multi-select.clear-object;
    $!signal-factory.clear-object;
  }

  $!puzzle-objects .= new-stringlist(CArray[Str].new(Str));
  $!multi-select .= new-multiselection($!puzzle-objects);
  $!multi-select.register-signal(
    self, 'selection-changed', 'selection-changed'
  );

  with $!signal-factory .= new-signallistitemfactory {
    .register-signal( self, 'setup-object', 'setup');
    .register-signal( self, 'bind-object', 'bind');
    .register-signal( self, 'unbind-object', 'unbind');
    .register-signal( self, 'destroy-object', 'teardown');
  }

  with $!puzzle-grid .= new-gridview( N-Object, N-Object) {
    .set-model($!multi-select);
    .set-factory($!signal-factory);
    .set-min-columns(3);
    .set-max-columns(10);
    .set-enable-rubberband(True);

    $!config.set-css( .get-style-context, :css-class<puzzle-grid>);
  }

  self.set-child($!puzzle-grid);
}

#-------------------------------------------------------------------------------
method get-pala-puzzles (
  Str $category, Str $pala-collection-path, Str :$filter = ''
) {
  for $pala-collection-path.IO.dir -> $collection-file {
    next if $collection-file.d;

    # Skip any other file
    next if $collection-file.Str !~~ m/ \. puzzle $/;

    my Str $puzzle-id = $!config.add-puzzle(
      $category, $collection-file.Str, :from-collection, :$filter
    );

    self.add-puzzle-to-table( $category, $puzzle-id);
  }
}

#-------------------------------------------------------------------------------
# Add puzzles to the table
method add-puzzles-to-table ( Seq $puzzles ) {

  my Array $indices = [];
  for @$puzzles -> $puzzle {
    my Str $category = $puzzle<Category>;
    my Str $puzzle-id = $puzzle<PuzzleID>;

    $!puzzles-playing{$category} = %()
      unless $!puzzles-playing{$category}:exists;
    $!puzzles-playing{$category}{$puzzle-id} //= False;

    self.add-puzzle-to-table($puzzle);
  }
}

#-------------------------------------------------------------------------------
# Add a puzzle to the table
multi method add-puzzle-to-table ( Str $category, Str $puzzle-id ) {

  my Hash $puzzle = $!config.get-puzzle($puzzle-id);

  # Coming from MainWindow.remote-options() it needs some more fields
  if ?$puzzle {
    $puzzle<PuzzleID> = $puzzle-id;
    $puzzle<Category> = $category;
    $puzzle<Image> = PUZZLE_TABLE_DATA ~ "$category/$puzzle-id/image400.jpg";
    self.add-puzzle-to-table($puzzle);
  }
}

#-------------------------------------------------------------------------------
# Add a puzzle to the table
multi method add-puzzle-to-table ( Hash $puzzle ) {

  # Save the index and drop some other fields to save memory
  my Str $puzzle-id = $puzzle<PuzzleID>;
  $puzzle<Name>:delete;
  $puzzle<SourceFile>:delete;

  $!current-table-objects{$puzzle-id} = $puzzle;
  $!puzzle-objects.append($puzzle-id);

  $!main.statusbar.remove-message;
  $!main.statusbar.set-status(
    "Number of puzzles: " ~ $!puzzle-objects.get-n-items
  );

  while $!main-context.pending {
    $!main-context.iteration(False);
  }
}

#-------------------------------------------------------------------------------
method setup-object ( Gnome::Gtk4::ListItem() $list-item ) {
  my PuzzleTable::Gui::TableItem $table-item .= new;
  $list-item.set-child($table-item.create-grid);
}

#-------------------------------------------------------------------------------
method bind-object ( Gnome::Gtk4::ListItem() $list-item ) {
  my Gnome::Gtk4::StringObject $string-object .= 
    new(:native-object($list-item.get-item));

  my Hash $puzzle = $!current-table-objects{$string-object.get-string};
  my PuzzleTable::Gui::TableItem $table-item .= new;
  my Gnome::Gtk4::Grid() $grid = $list-item.get-child;
  $table-item.set-table-item( $grid, $puzzle);
  $string-object.clear-object;
}

#-------------------------------------------------------------------------------
method unbind-object ( Gnome::Gtk4::ListItem() $list-item ) {
  my PuzzleTable::Gui::TableItem $table-item .= new;
  my Gnome::Gtk4::Grid() $grid = $list-item.get-child;
  $table-item.unset-table-item($grid);
}

#-------------------------------------------------------------------------------
method destroy-object ( Gnome::Gtk4::ListItem() $list-item ) {
  my PuzzleTable::Gui::TableItem $table-item .= new;
  my Gnome::Gtk4::Grid() $grid = $list-item.get-child;
  $table-item.clear-table-item($grid);
}

#-------------------------------------------------------------------------------
method selection-changed ( guint $position, guint $n-items ) {
  my Gnome::Gtk4::N-Bitset $bitset .= new(
    :native-object($!multi-select.get-selection)
  );

  my Int $n = $bitset.get-size;
  my Str $msg = "$n puzzles selected. Items set:";
  for ^$n -> $i {
    $msg ~= " $bitset.get-nth($i)";
  }

  $!main.statusbar.remove-message;
  $!main.statusbar.set-status($msg);
}
