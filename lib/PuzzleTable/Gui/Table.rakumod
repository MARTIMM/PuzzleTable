use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::TableItemLabel;
use PuzzleTable::Gui::Statusbar;

use Gnome::Gtk4::GridView:api<2>;
use Gnome::Gtk4::MultiSelection:api<2>;
use Gnome::Gtk4::SignalListItemFactory:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::ListItem:api<2>;
use Gnome::Gtk4::StringList:api<2>;
use Gnome::Gtk4::StringObject:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::T-Enums:api<2>;
use Gnome::Gtk4::Tooltip:api<2>;
use Gnome::Gtk4::N-Bitset:api<2>;
use Gnome::Gtk4::ProgressBar:api<2>;
use Gnome::Gtk4::Adjustment:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#`{{
A note from https://developer-old.gnome.org/gtk4/stable/ListContainers.html;

Another important requirement for views is that they need to know which items are not visible so they can be recycled. Views achieve that by implementing the GtkScrollable interface and expecting to be placed directly into a GtkScrolledWindow. 
}}

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Table:auth<github:MARTIMM>;
also is Gnome::Gtk4::ScrolledWindow;

has PuzzleTable::Config $!config;

has Gnome::Gtk4::StringList $.puzzle-objects;
has Gnome::Gtk4::MultiSelection $.multi-select;
#has Gnome::Gtk4::SingleSelection $!single-select;
has Gnome::Gtk4::SignalListItemFactory $!signal-factory;
has Gnome::Gtk4::GridView $!puzzle-grid;
has PuzzleTable::Gui::Statusbar $!statusbar;

# The objects from the current selected category
has Hash $!current-table-objects;

#-------------------------------------------------------------------------------
submethod BUILD (
  PuzzleTable::Config :$!config, PuzzleTable::Gui::Statusbar :$!statusbar
) {
  self.clear-table(:init);
}

#-------------------------------------------------------------------------------
# Add puzzle to the table
method add-puzzle-to-table ( Hash $object ) {

  # Save the index and drop some other fields to save memory
  my Str $index = $object<Puzzle-index>;
  $object<Name>:delete;
  $object<SourceFile>:delete;

  $!current-table-objects{$index} = $object;
  $!puzzle-objects.append($index);

  $!statusbar.remove-message;
  $!statusbar.set-status("Number of puzzles: " ~ $!puzzle-objects.get-n-items);
}

#-------------------------------------------------------------------------------
# Add puzzles to the table
method add-puzzles-to-table ( Seq $objects ) {

  my Array $indices = [];
  for @$objects -> $object {
    # Save the index and drop some other fields to save memory
    my Str $index = $object<Puzzle-index>;
    $object<Name>:delete;
    $object<SourceFile>:delete;

    $!current-table-objects{$index} = $object;
    $indices.push: $index;
  }

  my $is = CArray[Str].new( |$indices, Str);
  $!puzzle-objects.splice( 0, 0, $is);

  $!statusbar.remove-message;
  $!statusbar.set-status("Number of puzzles: " ~ $!puzzle-objects.get-n-items);
}

#-------------------------------------------------------------------------------
method clear-table ( Bool :$init = False ) {
#note "$?LINE clear-table";
  $!current-table-objects = %();

  unless $init {
    $!puzzle-objects.clear-object;
    $!multi-select.clear-object;
    $!signal-factory.clear-object;
  }

  $!puzzle-objects .= new-stringlist(CArray[Str].new(Str));
  $!multi-select .= new-multiselection($!puzzle-objects);
#  $!puzzle-objects.register-signal( self, 'items-changed', 'items-changed');
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

  self.set-halign(GTK_ALIGN_FILL);
  self.set-hexpand(True);
  self.set-vexpand(True);
  self.set-child($!puzzle-grid);
}

#-------------------------------------------------------------------------------
method setup-object ( Gnome::Gtk4::ListItem() $list-item ) {
#say 'setup-object';

  my Str $png-file = DATA_DIR ~ 'icons8-run-64.png';
  with my Gnome::Gtk4::Button $run-palapeli .= new-button {
    my Gnome::Gtk4::Picture $p .= new-picture;
    $p.set-filename($png-file);
    .set-child($p);

    .set-valign(GTK_ALIGN_START);
    .set-size-request( 64, 64);

    .set-has-tooltip(True);
    .register-signal(
      self, 'show-tooltip', 'query-tooltip',
      :tip(
        'Run the ' ~ $!config.get-palapeli-preference ~ ' version of palapeli'
      )
    );
  }

  with my Gnome::Gtk4::Box $button-box .= new-box(
    GTK_ORIENTATION_VERTICAL, 2
  ) {
    .append($run-palapeli);
  }

  with my Gnome::Gtk4::Picture $image .= new-picture {
    .set-size-request(| $!config.get-palapeli-image-size);
    .set-name('puzzle-image');
    .set-margin-top(3);
    .set-margin-bottom(3);
    .set-margin-start(3);
    .set-margin-end(3);
    .set-hexpand(True);
  }

  my Gnome::Gtk4::ProgressBar $progress-bar .= new-progressbar;
#  $progress-bar.set-show-text(True);
  $!config.set-css( $progress-bar.get-style-context, :css-class<progressbar>);

#    $!config.set-css( .get-style-context, :css-class<puzzle-object-comment>);
  my TableItemLabel $label-comment .= new( :!align, :css<comment>, :$!config);
  my TableItemLabel $label-size .= new(:$!config);
  my TableItemLabel $label-npieces .= new(:$!config);
  my TableItemLabel $label-source .= new(:$!config);
  my TableItemLabel $label-progress .= new(:$!config);

  with my Gnome::Gtk4::Grid $grid .= new-grid {
    .attach( $image, 0, 0, 1, 1);
    .attach( $label-comment, 0, 1, 2, 1);
    .attach( $label-size, 0, 2, 2, 1);
    .attach( $label-npieces, 0, 3, 2, 1);
    .attach( $label-source, 0, 4, 2, 1);
    .attach( $progress-bar, 0, 5, 2, 1);
    .attach( $label-progress, 0, 6, 2, 1);
    
    .attach( $button-box, 1, 0, 1, 1);

    $!config.set-css( .get-style-context, :css-class<puzzle-object>);
  }

  $list-item.set-child($grid);
}

#-------------------------------------------------------------------------------
method bind-object ( Gnome::Gtk4::ListItem() $list-item ) {
#say 'bind-object';

  my Gnome::Gtk4::StringObject $string-object .= new(
    :native-object($list-item.get-item)
  );
  my Hash $object = $!current-table-objects{$string-object.get-string};

  with my Gnome::Gtk4::Grid() $grid = $list-item.get-child {
    my Gnome::Gtk4::Box() $button-box = .get-child-at( 1, 0);

    my Gnome::Gtk4::Picture() $image = .get-child-at( 0, 0);
    my Gnome::Gtk4::Label() $label-comment = .get-child-at( 0, 1);
    my Gnome::Gtk4::Label() $label-size = .get-child-at( 0, 2);
    my Gnome::Gtk4::Label() $label-npieces = .get-child-at( 0, 3);
    my Gnome::Gtk4::Label() $label-source = .get-child-at( 0, 4);
    my Gnome::Gtk4::ProgressBar() $progress-bar = .get-child-at( 0, 5);
    my Gnome::Gtk4::Label() $label-progress = .get-child-at( 0, 6);

#Gnome::N::debug(:on);
#note "register click";
    my Gnome::Gtk4::Button() $run-palapeli = $button-box.get-first-child;
    $run-palapeli.register-signal(
      self, 'run-palapeli', 'clicked', :$object, :$label-progress,
      :$progress-bar
    );
#Gnome::N::debug(:off);

    $image.set-filename($object<Image>);
    $label-comment.set-text($object<Comment>);
    $label-size.set-text(
      [~] 'Picture size: ', $object<Width>, ' x ', $object<Height>
    );
    $label-npieces.set-text('Nbr pieces: ' ~ $object<PieceCount>);
    $label-source.set-text('Source: ' ~ $object<Source>);

    # Init if the values aren't there
    my Str $preference = $!config.get-palapeli-preference;
    $object<Progress> = %() unless $object<Progress>:exists;
    $object<Progress>{$preference} //= '0';
    my Str $progress = $object<Progress>{$preference}.Str;
    $label-progress.set-text("Progress: $progress \%");
    $progress-bar.set-text("Progress: $progress \%");
    $progress-bar.set-fraction($progress.Num / 100e0);
  }

  $string-object.clear-object;
}

#-------------------------------------------------------------------------------
method unbind-object ( Gnome::Gtk4::ListItem() $list-item ) {
#say 'unbind-object';
  my Gnome::Gtk4::Grid() $grid = $list-item.get-child;
  my Gnome::Gtk4::Box() $button-box = $grid.get-child-at( 1, 0);
  my Gnome::Gtk4::Button() $button = $button-box.get-first-child;
#note "unref button";
  $button.clear-object;
#  $button-box.destroy;
  $button-box.clear-object;
}

#-------------------------------------------------------------------------------
method destroy-object ( Gnome::Gtk4::ListItem() $list-item ) {
#say 'destroy-object';
  my Gnome::Gtk4::Grid() $grid = $list-item.get-child;
  $grid.clear-object;
}

#-------------------------------------------------------------------------------
method run-palapeli (
  Hash :$object, Gnome::Gtk4::Label :$label-progress,
  Gnome::Gtk4::ProgressBar :$progress-bar
) {
#Gnome::N::debug(:on);
  note "run palapeli with $object<Filename>";

  my $exec = $!config.get-pala-executable;

  my Str $puzzle-path = [~] PUZZLE_TABLE_DATA, $object<Category>,
         '/', $object<Puzzle-index>, '/',  $object<Filename>;
#note "\n$?LINE $puzzle-path\n$exec";

  $!statusbar.remove-message;
  $!statusbar.set-status("$exec '$puzzle-path'");

  # Start playing the puzzle
  shell "$exec '$puzzle-path'";

  # Returning from puzzle
  # Calculate progress
  my Str $progress = $!config.calculate-progress($object);
  $label-progress.set-text("Progress: $progress \%");
#  $progress-bar.set-text("Progress: $progress \%");
  $progress-bar.set-fraction($progress.Num / 100e0);
#Gnome::N::debug(:off);
}

#-------------------------------------------------------------------------------
method show-tooltip (
  Int $x, Int $y, gboolean $kb-mode, Gnome::Gtk4::Tooltip() $tooltip, Str :$tip
  --> gboolean
) {
  $tooltip.set-markup($tip);
  True
}

#`{{
#-------------------------------------------------------------------------------
method item-clicked ( guint $position ) {
note "$?LINE $position";
  my Gnome::Gtk4::N-Bitset $bitset .= new(
    :native-object($!multi-select.get-selection)
  );

#  $bitset.add($position);
  my Int $n = $bitset.get-size;
note "$?LINE n $n";
  for ^$n -> $i {
    print " ", $bitset.get-nth;
  }
print "\n";

#  $!multi-select.set-selection( $bitset, $bitset);
#  $!multi-select.set-select-item($position);
#  $!multi-select.selection-changed( 1, 1);
}
}}

#-------------------------------------------------------------------------------
method selection-changed ( guint $position, guint $n-items ) {
#note "$?LINE $position, $n-items";
  my Gnome::Gtk4::N-Bitset $bitset .= new(
    :native-object($!multi-select.get-selection)
  );

  my Int $n = $bitset.get-size;
  my Str $msg = "$n puzzles selected. Items set:";
  for ^$n -> $i {
    $msg ~= " $bitset.get-nth($i)";
  }

  $!statusbar.remove-message;
  $!statusbar.set-status($msg);
}


=finish
#-------------------------------------------------------------------------------
method items-changed ( guint $position, guint $n-removed, guint $n-added ) {
#note "$?LINE $position, $n-removed, $n-added";
#  $!multi-select.selection-changed( $position, $n-added);
}
