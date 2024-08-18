use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::TableItemLabel;
use PuzzleTable::Gui::Dialog;

use Gnome::Gtk4::GridView:api<2>;
use Gnome::Gtk4::MultiSelection:api<2>;
use Gnome::Gtk4::SignalListItemFactory:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Tooltip:api<2>;
use Gnome::Gtk4::N-Bitset:api<2>;
use Gnome::Gtk4::ProgressBar:api<2>;
use Gnome::Gtk4::Adjustment:api<2>;
use Gnome::Gtk4::StringList:api<2>;
use Gnome::Gtk4::ListItem:api<2>;
use Gnome::Gtk4::StringObject:api<2>;

use Gnome::Glib::N-MainLoop:api<2>;
use Gnome::Glib::N-MainContext:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#use Semaphore::ReadersWriters;

#`{{
A note from https://developer-old.gnome.org/gtk4/stable/ListContainers.html;

Another important requirement for views is that they need to know which items are not visible so they can be recycled. Views achieve that by implementing the GtkScrollable interface and expecting to be placed directly into a GtkScrolledWindow. 
}}

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Table:auth<github:MARTIMM>;
also is Gnome::Gtk4::ScrolledWindow;

has $!main is required;
has PuzzleTable::Config $!config;
#has PuzzleTable::Gui::Statusbar $!statusbar;

has Gnome::Gtk4::StringList $.puzzle-objects;
has Gnome::Gtk4::MultiSelection $.multi-select;
#has Gnome::Gtk4::SingleSelection $!single-select;
has Gnome::Gtk4::SignalListItemFactory $!signal-factory;
has Gnome::Gtk4::GridView $!puzzle-grid;

# The objects from the current selected category
has Hash $!current-table-objects;
has Gnome::Glib::N-MainContext $!main-context;

#has Semaphore::ReadersWriters $!semaphore;
has Hash $!puzzles-playing = %();

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
#Gnome::N::debug(:on);
  $!main-context .= new-maincontext(
    :native-object(
      Gnome::Glib::N-MainLoop.new-mainloop( N-Object, True).get-context()
    )
  );
#Gnome::N::debug(:off);

#  $!semaphore .= new;
#  $!semaphore.add-mutex-names('puzzles-playing');

  $!config .= instance;

  self.set-halign(GTK_ALIGN_FILL);
#  self.set-hexpand(True);
#  self.set-hexpand-set(True);
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

    # The puzzle is started from outside the Palapeli. This is only a saved file
    # to keep track of progress of puzzle. Ends always in '.save'. Must be
    # checked when --puzzles option is used.
    #next if $collection-file.Str ~~ m/^ __FSC_ /;

    # *.save files are matched later using a *.puzzle file
    #next if $collection-file.Str ~~ m/ \. save $/;

    # Skip any other file
    next if $collection-file.Str !~~ m/ \. puzzle $/;

    my Str $puzzle-id = $!config.add-puzzle(
      $category, $collection-file.Str, :from-collection, :$filter
    );
#    my Hash $puzzle = $*puzzle-data<categories>{$category}<members>{$puzzle-id};
    self.add-puzzle-to-table( $category, $puzzle-id);

#last;
  }

#  $!config.save-categories-config;
}

#-------------------------------------------------------------------------------
# Add puzzles to the table
method add-puzzles-to-table ( Seq $puzzles ) {

  my Array $indices = [];
  for @$puzzles -> $puzzle {
    my Str $category = $puzzle<Category>;
    my Str $puzzle-id = $puzzle<PuzzleID>;

#    $!semaphore.writer( 'puzzles-playing', {
      $!puzzles-playing{$category} = %()
        unless $!puzzles-playing{$category}:exists;
      $!puzzles-playing{$category}{$puzzle-id} //= False;
#    });

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
#  my @puzzles = $puzzle,;
#  self.add-puzzles-to-table(@puzzles);

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
#say 'setup-object';

  my Str $png-file = DATA_DIR ~ 'images/start-puzzle-64.png';
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

  $png-file = DATA_DIR ~ 'images/edit-puzzle-64.png';
  with my Gnome::Gtk4::Button $edit-palapeli .= new-button {
    my Gnome::Gtk4::Picture $p .= new-picture;
    $p.set-filename($png-file);
    .set-child($p);

    .set-valign(GTK_ALIGN_START);
    .set-size-request( 64, 64);

    .set-has-tooltip(True);
    .register-signal(
      self, 'show-tooltip', 'query-tooltip',
      :tip('Edit some texts of this puzzle')
    );
  }

  my Gnome::Gtk4::Label $pid .= new-label();

  with my Gnome::Gtk4::Box $button-box .= new-box(
    GTK_ORIENTATION_VERTICAL, 2
  ) {
    .append($run-palapeli);
    .append($edit-palapeli);
    .append($pid);

#    $!config.set-css( .get-style-context, :css-class<puzzle-grid-puzzle>);
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

  with my Gnome::Gtk4::ProgressBar $progress-bar .= new-progressbar {
    $!config.set-css( .get-style-context, :css-class<puzzle-progress>);
    .set-size-request( 1, 10);
#    .set-show-text(True);
    .set-vexpand(True);
    .set-valign(GTK_ALIGN_FILL);
  }

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
  my Gnome::Gtk4::StringObject $string-object .= 
    new(:native-object($list-item.get-item));

  my Hash $puzzle = $!current-table-objects{$string-object.get-string};

  with my Gnome::Gtk4::Grid() $grid = $list-item.get-child {
    my Gnome::Gtk4::Box() $button-box = .get-child-at( 1, 0);

    my Gnome::Gtk4::Picture() $image = .get-child-at( 0, 0);
    my Gnome::Gtk4::Label() $label-comment = .get-child-at( 0, 1);
    my Gnome::Gtk4::Label() $label-size = .get-child-at( 0, 2);
    my Gnome::Gtk4::Label() $label-npieces = .get-child-at( 0, 3);
    my Gnome::Gtk4::Label() $label-source = .get-child-at( 0, 4);
    my Gnome::Gtk4::ProgressBar() $progress-bar = .get-child-at( 0, 5);
    my Gnome::Gtk4::Label() $label-progress = .get-child-at( 0, 6);

    my Gnome::Gtk4::Button() $run-palapeli = $button-box.get-first-child;
    $run-palapeli.register-signal(
      self, 'run-palapeli', 'clicked', :$puzzle, :$label-progress,
      :$progress-bar
      #, :$label-comment
    );

    my Gnome::Gtk4::Button() $edit-palapeli = $run-palapeli.get-next-sibling;
    $edit-palapeli.register-signal(
      self, 'edit-palapeli', 'clicked', :$puzzle,
      :$label-comment, :$label-source
    );

    my Gnome::Gtk4::Label() $pid = $edit-palapeli.get-next-sibling;
    $pid.set-text($puzzle<PuzzleID>);

    $image.set-filename($puzzle<Image>);
    $label-comment.set-text($puzzle<Comment>);
    $label-size.set-text('Picture size: ' ~ $puzzle<ImageSize>);
    $label-npieces.set-text(
      'Nbr pieces: ' ~ $puzzle<PieceCount> ~ ($puzzle<SlicerMode>//'')
    );
    $label-source.set-text('Source: ' ~ $puzzle<Source>);

    # Init if the values aren't there
#    my Str $preference = $!config.get-palapeli-preference;
#    $puzzle<Progress> = %() unless $puzzle<Progress>:exists;
    $puzzle<Progress> //= '0';
    
    # Test for old version data
    my Str $progress;
    if $puzzle<Progress> ~~ Hash {
      $progress = $puzzle<Progress>{$puzzle<Progress>.keys[0]}.Str;
    }

    else {
      $progress = $puzzle<Progress>.Str;
    }

    $label-progress.set-text("Progress: $progress \%");
    $progress-bar.set-text("Progress: $progress \%");
    $progress-bar.set-fraction($progress.Num / 100e0);

    .show;
  }

  $string-object.clear-object;
}

#-------------------------------------------------------------------------------
method unbind-object ( Gnome::Gtk4::ListItem() $list-item ) {
#say 'unbind-object';
  my Gnome::Gtk4::Grid() $grid = $list-item.get-child;
  my Gnome::Gtk4::Box() $button-box = $grid.get-child-at( 1, 0);
  my Gnome::Gtk4::Button() $button = $button-box.get-first-child;

  $button.clear-object;
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
  Hash :$puzzle, Gnome::Gtk4::Label :$label-progress,
  Gnome::Gtk4::ProgressBar :$progress-bar
) {
  my Str $progress = $!config.run-palapeli($puzzle);
  $label-progress.set-text("Progress: $progress \%");
  $progress-bar.set-fraction($progress.Num / 100e0);
  $!main.sidebar.fill-sidebar;
}

#-------------------------------------------------------------------------------
method show-tooltip (
  Int $x, Int $y, gboolean $kb-mode, Gnome::Gtk4::Tooltip() $tooltip, Str :$tip
  --> gboolean
) {
  $tooltip.set-markup($tip);
  True
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

#-------------------------------------------------------------------------------
method edit-palapeli (
  Hash :$puzzle,
  Gnome::Gtk4::Label :$label-comment, Gnome::Gtk4::Label :$label-source
) {
  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Edit Puzzle Info Dialog')
  ) {
    .add-content( 'Title', my Gnome::Gtk4::Entry $comment .= new-entry);
    $comment.set-text($puzzle<Comment>);
    .add-content( 'Source', my Gnome::Gtk4::Entry $source .= new-entry);
    $source.set-text($puzzle<Source>);

    .add-button(
      self, 'do-update-puzzle', 'Change Text',
      :$comment, :$source, :$dialog, :$puzzle,
      :$label-comment, :$label-source
    );
    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-update-puzzle (
  PuzzleTable::Gui::Dialog :$dialog, Hash :$puzzle,
  Gnome::Gtk4::Entry :$comment, Gnome::Gtk4::Entry :$source,
  Gnome::Gtk4::Label :$label-comment, Gnome::Gtk4::Label :$label-source
) {
  $!main.config.update-puzzle(
    %(
      :PuzzleID($puzzle<PuzzleID>),
      :Comment($comment.get-text),
      :Source($source.get-text),
    )
  );
  $label-comment.set-text($comment.get-text);
  $label-source.set-text('Source: ' ~ $source.get-text);
  $dialog.destroy-dialog;
}
