use v6.d;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::Dialog;

#use Gnome::Gtk4::MultiSelection:api<2>;
use Gnome::Gtk4::ComboBoxText:api<2>;
use Gnome::Gtk4::CheckButton:api<2>;
use Gnome::Gtk4::T-dialog:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::MessageDialog:api<2>;
use Gnome::Gtk4::T-messagedialog:api<2>;
use Gnome::Gtk4::N-Bitset:api<2>;
use Gnome::Gtk4::T-types:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::PuzzleHandling:auth<github:MARTIMM>;

has $!main is required;
has PuzzleTable::Config $!config;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!config = $!main.config;
}

#-------------------------------------------------------------------------------
method puzzles-move-puzzles ( N-Object $parameter ) {
#  my Gnome::Gtk4::MultiSelection $multi-select = $!main.table.multi-select;
  my Gnome::Gtk4::N-Bitset $bitset .=
    new(:native-object($!main.table.multi-select.get-selection));

  my Int $n = $bitset.get-size;
  unless ?$n {
    my Gnome::Gtk4::MessageDialog $message .= new-messagedialog(
      $!main.application-window, GTK_DIALOG_MODAL, GTK_MESSAGE_INFO,
      GTK_BUTTONS_OK, "There are no puzzles selected"
    );
    $message.register-signal( self, 'move-message-dialog', 'response');
    $message.show;

    return
  }

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Move Puzzles Dialog')
  ) {
    my Gnome::Gtk4::ComboBoxText $combobox.= new-comboboxtext;
    for $!config.get-categories -> $category {
      if $category ~~ m/ '_EX_' $/ {
        for $!config.get-categories(
              :category-container($category)
            ) -> $subcategory
        {
          $combobox.append-text($subcategory);
        }
      }

      else {
        $combobox.append-text($category);
      }
    }
    $combobox.set-active(0);

    .add-content( 'Specify the category to move to', $combobox);

    .add-button(
      self, 'do-move-puzzles', 'Move', :$combobox, :$bitset, :$dialog
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-move-puzzles ( 
  PuzzleTable::Gui::Dialog :$dialog,
  Gnome::Gtk4::ComboBox :$combobox,
  Gnome::Gtk4::N-Bitset :$bitset
) {
#  note "do move";
  my Bool $sts-ok = False;

  my Str $current-cat = $!config.get-current-category;
  my Str $dest-cat = $combobox.get-active-text;
  if $current-cat eq $dest-cat {
    $dialog.set-status('Selected category is same as current');
  }

  else {
    # Get the selected puzzles from the bitset and move them
    my Int $n = $bitset.get-size;
    for ^$n -> $i {
      my Int $item-pos = $bitset.get-nth($i);
      $!config.move-puzzle(
        $dest-cat, $!main.table.puzzle-objects.get-string($item-pos)
      );
    }

    # Save admin and update puzzle table
#    $!config.save-categories-config;

    # Selecting the category again will redraw the puzzle table
    $!main.category.select-category(:category($current-cat));

    # Update status bar to show number of puzzles
    $!main.statusbar.set-status(
      "Number of puzzles: " ~ $!main.table.puzzle-objects.get-n-items
    );

    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method puzzles-remove-puzzles ( N-Object $parameter ) {
#note "remove";

#  my Gnome::Gtk4::MultiSelection $multi-select = $!main.table.multi-select;
  my Gnome::Gtk4::N-Bitset $bitset .=
    new(:native-object($!main.table.multi-select.get-selection));

  my Int $n = $bitset.get-size;
  unless ?$n {
    my Gnome::Gtk4::MessageDialog $message .= new-messagedialog(
      $!main.application-window, GTK_DIALOG_MODAL, GTK_MESSAGE_INFO,
      GTK_BUTTONS_OK, "There are no puzzles selected"
    );
    $message.register-signal( self, 'move-message-dialog', 'response');
    $message.show;

    return
  }

  my Gnome::Gtk4::CheckButton $check-button .= new-with-label;
  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Remove Puzzle Dialog')
  ) {
#    .add-content( 'Specify the category to move to', $combobox);
    .add-content( 'Check to make sure you really want it', $check-button);

    .add-button(
      self, 'do-remove-puzzles', 'Archive Puzzle in Trash',
      :$check-button, :$dialog, :$bitset
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-remove-puzzles (
  PuzzleTable::Gui::Dialog :$dialog, Gnome::Gtk4::CheckButton :$check-button,
  Gnome::Gtk4::N-Bitset :$bitset
) {
#note "do remove";

  my Bool $sts-ok = False;
  #my Str $category = $!config

  if $check-button.get-active.Bool {
    my Str $current-cat = $!config.get-current-category;
    $!config.select-category($current-cat);

    # Get the selected puzzles from the bitset and move them
    my Array $puzzle-ids = [];
    my Int $n = $bitset.get-size;
    for ^$n -> $i {
      my Int $item-pos = $bitset.get-nth($i);
      $puzzle-ids.push: $!main.table.puzzle-objects.get-string($item-pos);
    }

    # Archive the puzzles and remove from configuration
    $!config.archive-puzzles( $puzzle-ids, PUZZLE_TRASH);

    # Update puzzle table
    $!main.category.select-category(:category($current-cat));

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

#-------------------------------------------------------------------------------
method move-message-dialog (
  Int $response-id, Gnome::Gtk4::MessageDialog() :_native-object($message)
) {
  $message.destroy;
}