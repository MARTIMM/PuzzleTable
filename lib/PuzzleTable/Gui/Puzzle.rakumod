use v6.d;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Config::Category;
use PuzzleTable::Gui::MessageDialog;
use PuzzleTable::Gui::Dialog;
use PuzzleTable::Gui::DropDown;

#use Gnome::Gtk4::MultiSelection:api<2>;
#use Gnome::Gtk4::ComboBoxText:api<2>;
use Gnome::Gtk4::CheckButton:api<2>;
#use Gnome::Gtk4::T-dialog:api<2>;
#use Gnome::Gtk4::T-enums:api<2>;
#use Gnome::Gtk4::MessageDialog:api<2>;
#use Gnome::Gtk4::T-messagedialog:api<2>;
use Gnome::Gtk4::N-Bitset:api<2>;
use Gnome::Gtk4::T-types:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Puzzle:auth<github:MARTIMM>;

has $!main is required;
has PuzzleTable::Config $!config;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!config .= instance;
}

#-------------------------------------------------------------------------------
method puzzle-move ( N-Object $parameter ) {
#  my Gnome::Gtk4::MultiSelection $multi-select = $!main.table.multi-select;
  my Gnome::Gtk4::N-Bitset $bitset .=
    new(:native-object($!main.table.multi-select.get-selection));

  my Int $n = $bitset.get-size;
  unless ?$n {
    my PuzzleTable::Gui::MessageDialog $message .= new(
      :message("There are no puzzles selected"), :no-statusbar
    );

    return
  }

  # A dropdown to list categories. The current category is preselected.
  my Str $select-category = $!config.get-current-category;
  my Str $select-container = $!config.get-current-container;
  my Str $select-root = $!config.get-current-root;

  my PuzzleTable::Config::Category $from-category .= new(
    :category-name($select-category),
    :container($select-container),
    :root-dir($select-root)
  );

  my PuzzleTable::Gui::DropDown $category-dd .= new;
  $category-dd.fill-categories(
    $select-category, $select-container, $select-root
  );

  # Find the container of the current category and use it in the container
  # list to preselect it.
  with my PuzzleTable::Gui::DropDown $container-dd .= new {
    .fill-containers( $!config.get-current-container, $select-root);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    .trap-container-changes( $category-dd, :!skip-default);
  }

  my PuzzleTable::Gui::DropDown $roots-dd;
  if $*multiple-roots {
    $roots-dd .= new;
    $roots-dd.fill-roots($select-root);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    $roots-dd.trap-root-changes( $container-dd, :categories($category-dd));
  }

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :dialog-header('Move Puzzles Dialog')
  ) {
    .add-content( 'Select a root to move to', $roots-dd) if $*multiple-roots;
    .add-content( 'Specify the container to move to', $container-dd);
    .add-content( 'Specify the category to move puzzles to', $category-dd);

    .add-button(
      self, 'do-move-puzzles', 'Move',
      :$roots-dd, :$category-dd, :$container-dd,
      :$bitset, :$dialog, :$from-category
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-move-puzzles ( 
  PuzzleTable::Gui::Dialog :$dialog,
  PuzzleTable::Gui::DropDown :$category-dd,
  PuzzleTable::Gui::DropDown :$container-dd,
  PuzzleTable::Gui::DropDown :$roots-dd,
  PuzzleTable::Config::Category :$from-category,
  Gnome::Gtk4::N-Bitset :$bitset
) {
#  note "do move";
  my Bool $sts-ok = False;

  my Str $current-cat = $!config.get-current-category;
  my Str $dest-cat = $category-dd.get-dropdown-text;
  my Str $dest-cont = $container-dd.get-dropdown-text;
  my Str $dest-root = $roots-dd.get-dropdown-text;

  if $current-cat eq $dest-cat and
     $!config.get-current-container eq $dest-cont and
     $!config.get-current-root eq $dest-root
  {
    $dialog.set-status(
      'Selected container and category is same as current one'
    );
  }

  else {
    # Get the selected puzzles from the bitset and move them
    my Int $n = $bitset.get-size;
    for ^$n -> $i {
      my Int $item-pos = $bitset.get-nth($i);
#note "$?LINE $i, $item-pos, $!main.table.puzzle-objects.get-string($item-pos)";

      $!config.move-puzzle(
        $from-category, $dest-cat, $dest-cont, $dest-root, $!main.table.puzzle-objects.get-string($item-pos)
      );
    }

#note "$?LINE";

    # Update status bar to show number of puzzles
    $!main.statusbar.set-status(
      "Number of puzzles: " ~ $!main.table.puzzle-objects.get-n-items
    );

    # Selecting the category again will redraw the puzzle table
    $!main.sidebar.select-category(
      :category($dest-cat),
      :container($dest-cont),
      :root-dir($dest-root)
    );

    $!main.sidebar.fill-sidebar;

    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method puzzle-archive ( N-Object $parameter ) {

  my Gnome::Gtk4::N-Bitset $bitset .=
    new(:native-object($!main.table.multi-select.get-selection));

  my Int $n = $bitset.get-size;
  unless ?$n {
    my PuzzleTable::Gui::MessageDialog $message .= new(
      :message("There are no puzzles selected"), :no-statusbar
    );

    return
  }

  my Gnome::Gtk4::CheckButton $check-button .= new-with-label(
    'Check to make sure you really want it'
  );
  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :dialog-header('Remove Puzzle Dialog')
  ) {
    .add-content( '', $check-button);

    .add-button(
      self, 'do-archive-puzzles', 'Archive Puzzle in Trash',
      :$check-button, :$dialog, :$bitset
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-archive-puzzles (
  PuzzleTable::Gui::Dialog :$dialog, Gnome::Gtk4::CheckButton :$check-button,
  Gnome::Gtk4::N-Bitset :$bitset
) {
  my Bool $sts-ok = False;

  if $check-button.get-active.Bool {
    my Str $current-cat = $!config.get-current-category;
    my Str $current-cont = $!config.get-current-container;
    my Str $current-root = $!config.get-current-root;
    $!config.select-category( $current-cat, $current-cont, $current-root);

    # Get the selected puzzles from the bitset and move them
    my Array $puzzle-ids = [];
    my Int $n = $bitset.get-size;
    for ^$n -> $i {
      my Int $item-pos = $bitset.get-nth($i);
      $puzzle-ids.push: $!main.table.puzzle-objects.get-string($item-pos);
    }

    # Archive the puzzles and remove from configuration
    $!config.archive-puzzles($puzzle-ids);

    # Update puzzle table
    $!main.sidebar.select-category(
      :category($current-cat), :container($current-cont),
      :root-dir($current-root)
    );

    # Update status bar to show number of puzzles
    $!main.statusbar.set-status(
      "Number of puzzles: " ~ $!main.table.puzzle-objects.get-n-items
    );

    $sts-ok = True;
  }

  else {
    $dialog.set-status('Please check to give your consent');
  }

  $dialog.destroy-dialog if $sts-ok;
}
