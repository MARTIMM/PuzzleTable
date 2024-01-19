use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::TableItemLabel;

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
# Add puzzle to the table
method add-puzzle-to-table ( Hash $object ) {

  # Save the index and drop some other fields to save memory
  my Str $index = $object<Puzzle-index>;
  $object<Name>:delete;
  $object<SourceFile>:delete;

#  $object<Progress> = %();
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
say 'setup-object';

  with my Gnome::Gtk4::Picture $image .= new-picture {
    .set-size-request( 300, 300);
    .set-name('puzzle-image');
    .set-margin-top(3);
    .set-margin-bottom(3);
    .set-margin-start(3);
    .set-margin-end(3);
  }

#    $!config.set-css( .get-style-context, :css-class<puzzle-object-comment>);
  my TableItemLabel $label-comment .= new( :!align, :css<comment>);
  my TableItemLabel $label-size .= new;
  my TableItemLabel $label-npieces .= new;
  my TableItemLabel $label-source .= new;
  my TableItemLabel $label-progress .= new;

  with my Gnome::Gtk4::Grid $grid .= new-grid {
    .attach( $image, 0, 0, 1, 1);
    .attach( $label-comment, 0, 1, 1, 1);
    .attach( $label-size, 0, 2, 1, 1);
    .attach( $label-npieces, 0, 3, 1, 1);
    .attach( $label-source, 0, 4, 1, 1);
    .attach( $label-progress, 0, 5, 1, 1);

    $!config.set-css( .get-style-context, :css-class<puzzle-object>);
  }

  $list-item.set-child($grid);
}

#-------------------------------------------------------------------------------
method bind-object ( Gnome::Gtk4::ListItem() $list-item ) {
say 'bind-object';

  my Gnome::Gtk4::StringObject $string-object .= new(
    :native-object($list-item.get-item)
  );
  my Hash $object = $!current-table-objects{$string-object.get-string};

  my Str $png-file = DATA_DIR ~ 'icons8-run-64.png';
  with my Gnome::Gtk4::Button $run-snap .= new-button {
    # A large enough picture on the button
    my Gnome::Gtk4::Picture $p .= new-picture;
    $p.set-filename($png-file);
    .set-child($p);

    .set-valign(GTK_ALIGN_START);
#    .set-size-request( 32, 32);

    # Set the tooltip
    .set-has-tooltip(True);
    .register-signal(
      self, 'show-tooltip', 'query-tooltip',
      :tip('Run the snap version of palapeli')
    );
  }

  with my Gnome::Gtk4::Button $run-standard .= new-button {
    my Gnome::Gtk4::Picture $p .= new-picture;
    $p.set-filename($png-file);
    .set-child($p);

    .set-valign(GTK_ALIGN_START);
#    .set-size-request( 32, 32);

    .set-has-tooltip(True);
    .register-signal(
      self, 'show-tooltip', 'query-tooltip',
      :tip('Run the standard version of palapeli')
    );
  }

  with my Gnome::Gtk4::Box $button-box .= new-box(
    GTK_ORIENTATION_VERTICAL, 2
  ) {
    .append($run-snap);
    .append($run-standard);
  }

  with my Gnome::Gtk4::Grid() $grid = $list-item.get-child {
    .attach( $button-box, 1, 0, 1, 5);

    my Gnome::Gtk4::Picture() $image = .get-child-at( 0, 0);
    my Gnome::Gtk4::Label() $label-comment = .get-child-at( 0, 1);
    my Gnome::Gtk4::Label() $label-size = .get-child-at( 0, 2);
    my Gnome::Gtk4::Label() $label-npieces = .get-child-at( 0, 3);
    my Gnome::Gtk4::Label() $label-source = .get-child-at( 0, 4);
    my Gnome::Gtk4::Label() $label-progress = .get-child-at( 0, 5);
    $run-snap.register-signal(
      self, 'run-snap', 'clicked', :$object, :$label-progress
    );
    $run-standard.register-signal(
      self, 'run-standard', 'clicked', :$object, :$label-progress
    );

    $image.set-filename($object<Image>);
    $label-comment.set-text($object<Comment>);
    $label-size.set-text(
      [~] 'Picture size: ', $object<Width>, ' x ', $object<Height>
    );
    $label-npieces.set-text('Nbr pieces: ' ~ $object<PieceCount>);
    $label-source.set-text('Source: ' ~ $object<Source>);

    # Init if the values aren't there
    $object<Progress> = %() unless $object<Progress>:exists;
    $object<Progress><Snap> //= '0';
    $object<Progress><Standard> //= '0';
    my Str $p-snap = $object<Progress><Snap>.Str;
    my Str $p-standard = $object<Progress><Standard>.Str;
    $label-progress.set-text(
      [~] 'Progress: ', $p-snap, ' % / ', $p-standard, ' %'
    );
  }

  $string-object.clear-object;
}

#-------------------------------------------------------------------------------
method unbind-object ( Gnome::Gtk4::ListItem() $list-item ) {
note 'unbind';
  my Gnome::Gtk4::Grid() $grid = $list-item.get-child;
  my Gnome::Gtk4::Box() $button-box = $grid.get-child-at( 1, 0);
  $button-box.clear-object;
}

#-------------------------------------------------------------------------------
method destroy-object ( Gnome::Gtk4::ListItem() $list-item ) {
note 'destroy';
  my Gnome::Gtk4::Grid() $grid = $list-item.get-child;
  $grid.clear-object;
}

#-------------------------------------------------------------------------------
method run-snap ( Hash :$object, Gnome::Gtk4::Label :$label-progress ) {
  note "run snap with $object<Filename>";
  my Str $puzzle-path = [~] PUZZLE_TABLE_DATA, $object<Category>,
         '/', $object<Puzzle-index>, '/',  $object<Filename>;
  my $exec = $!config.get-pala-executable(Snap);

#note "$exec $puzzle-path";
  
  # Start playing the puzzle
  shell "$exec $puzzle-path";

  # Returning from puzzle
  # Calculate progress
  my Str $progress = $!config.calculate-progress( $object, Snap);

  $label-progress.set-text(
    [~] 'Progress: ', $progress, ' % / ', $object<Progress><Standard>, ' %'
  )
}

#-------------------------------------------------------------------------------
method run-standard ( Hash :$object, Gnome::Gtk4::Label :$label-progress ) {
  note "run standard with $object<Filename>";
  my Str $puzzle-path = [~] PUZZLE_TABLE_DATA, $object<Category>,
         '/', $object<Puzzle-index>, '/',  $object<Filename>;
  my $exec = $!config.get-pala-executable(Standard);

#note "$exec $puzzle-path";

  shell "$exec $puzzle-path";

  # Returning from puzzle
  # Calculate progress
  my Str $progress = $!config.calculate-progress( $object, Standard);

  $label-progress.set-text(
    [~] 'Progress: ', $object<Progress><Snap>, ' % / ', $progress, ' %'
  );
}

#-------------------------------------------------------------------------------
method show-tooltip (
  Int $x, Int $y, gboolean $kb-mode,
  Gnome::Gtk4::Tooltip() $tooltip, Str :$tip
  --> gboolean
) {
  $tooltip.set-markup($tip);
  True
}
