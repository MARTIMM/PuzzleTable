use v6.d;

use PuzzleTable::Config;
use PuzzleTable::Gui::DialogLabel;
use PuzzleTable::Gui::Statusbar;
use PuzzleTable::Gui::Dialog;

use Gnome::Gtk4::StringList:api<2>;
use Gnome::Gtk4::N-Bitset:api<2>;
use Gnome::Gtk4::MultiSelection:api<2>;
use Gnome::Gtk4::ComboBoxText:api<2>;
use Gnome::Gtk4::CheckButton:api<2>;
use Gnome::Gtk4::Dialog:api<2>;
use Gnome::Gtk4::T-Dialog:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::MessageDialog:api<2>;
use Gnome::Gtk4::T-MessageDialog:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::PuzzleHandling:auth<github:MARTIMM>;

has $!main is required;
has PuzzleTable::Config $!config;
has PuzzleTable::Gui::Statusbar $!statusbar;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!config = $!main.config;
}

#-------------------------------------------------------------------------------
method puzzles-move-puzzles ( N-Object $parameter ) {
  my Gnome::Gtk4::MultiSelection $multi-select = $!main.table.multi-select;
  my Gnome::Gtk4::N-Bitset $bitset .= new(
    :native-object($multi-select.get-selection)
  );

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

  my DialogLabel $label .= new( 'Specify the category to move to', :$!config);
  $!statusbar .= new-statusbar(:context<category>);

  # Fill the combobox in the dialog
  my Gnome::Gtk4::ComboBoxText $combobox.= new-comboboxtext;
  for $!config.get-categories(:filter<lockable>) -> $category {
    $combobox.append-text($category);
  }
  $combobox.set-active(0);

  my Gnome::Gtk4::Dialog $dialog .= new-with-buttons(
    'Add Category Dialog', $!main.application-window,
    GTK_DIALOG_MODAL +| GTK_DIALOG_DESTROY_WITH_PARENT,
         'Move', GEnum, GTK_RESPONSE_ACCEPT,
    Str, 'Cancel', GEnum, GTK_RESPONSE_CANCEL
  );

  with my Gnome::Gtk4::Box $box .= new(
    :native-object($dialog.get-content-area)
  ) {
    .set-orientation(GTK_ORIENTATION_VERTICAL);
    .set-margin-top(10);
    .set-margin-bottom(10);
    .set-margin-start(10);
    .set-margin-end(10);
    .append($label);
    .append($combobox);
    .append($!statusbar);
  }

  with $dialog {
    .set-size-request( 400, 100);
    .register-signal(
       self, 'do-move-puzzles', 'response', :$combobox, :$bitset
    );
    .register-signal( self, 'destroy-dialog', 'destroy');
    $!config.set-css( .get-style-context, :css-class<dialog>);
    .set-name('category-dialog');
    .show;
  }
}

#-------------------------------------------------------------------------------
method do-move-puzzles ( 
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::ComboBox :$combobox, Gnome::Gtk4::N-Bitset :$bitset
 ) {
  note "do move";
#  my Gnome::Gtk4::MultiSelection $multi-select = $!main.table.multi-select;
  my Gnome::Gtk4::StringList $puzzle-objects = $!main.table.puzzle-objects;
  my Bool $sts-ok = False;

  $!statusbar.remove-message;

  my GtkResponseType() $response-type = $response-id;  

  given $response-type {
    when GTK_RESPONSE_DELETE_EVENT {
      #ignore
      $sts-ok = True;
    }

    when GTK_RESPONSE_ACCEPT {
      my Str $current-cat = $!main.category.get-current-category;
      my Str $dest-cat = $combobox.get-active-text;
      if $current-cat eq $dest-cat {
        $!statusbar.set-status('Selected category is same as current');
      }

      else {
#        my Gnome::Gtk4::N-Bitset $bitset .= new(
#          :native-object($multi-select.get-selection)
#        );

        # Get the selected puzzles from the bitset and move them
        my Int $n = $bitset.get-size;
        for ^$n -> $i {
          my Int $item-pos = $bitset.get-nth($i);
          $!config.move-puzzle(
            $current-cat, $dest-cat, $puzzle-objects.get-string($item-pos)
          );
        }
#`{{
        # Remove puzzles from current display. First get all items, then
        # remove the item beginning with the highest to prevent that
        # items are picked from the wrong spot because the display renumbers
        # after removal.
        my @items = ();
        for ^$n -> $i { @items.push: $bitset.get-nth($i); }
        for @items.sort.reverse -> $item-pos {
          $puzzle-objects.remove($item-pos);
        }
}}

        # Save admin and update puzzle table
        $!config.save-puzzle-admin;
        $!main.category.select-category(:category($current-cat));

        # Update status bar to show number of puzzles
        $puzzle-objects = $!main.table.puzzle-objects;
        $!main.statusbar.set-status(
          "Number of puzzles: " ~ $puzzle-objects.get-n-items
        );

        $sts-ok = True;
      }
    }

    when GTK_RESPONSE_CANCEL {
      $sts-ok = True;
    }
  }

  $dialog.destroy if $sts-ok;
}

#-------------------------------------------------------------------------------
method puzzles-remove-puzzles ( N-Object $parameter ) {
note "remove";

  my Gnome::Gtk4::MultiSelection $multi-select = $!main.table.multi-select;
  my Gnome::Gtk4::N-Bitset $bitset .= new(
    :native-object($multi-select.get-selection)
  );

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

#`{{
  # Fill the combobox for the dialog
  my Gnome::Gtk4::ComboBoxText $combobox.= new-comboboxtext;
  for $!config.get-categories(:filter<lockable>) -> $category {
    $combobox.append-text($category);
  }
  $combobox.set-active(0);
}}
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
note "do remove";

#  my Gnome::Gtk4::MultiSelection $multi-select = $!main.table.multi-select;
  my Gnome::Gtk4::StringList $puzzle-objects = $!main.table.puzzle-objects;
  my Bool $sts-ok = False;
  #my Str $category = $!config

  if $check-button.get-active.Bool {
    my Str $current-cat = $!main.category.get-current-category;

    # Get the selected puzzles from the bitset and move them
    my Int $n = $bitset.get-size;
    for ^$n -> $i {
      my Int $item-pos = $bitset.get-nth($i);
      $!config.remove-puzzle(
        $current-cat, $puzzle-objects.get-string($item-pos)
      );
    }

    # Save admin and update puzzle table
    $!config.save-puzzle-admin;
    $!main.category.select-category(:category($current-cat));

    # Update status bar to show number of puzzles
    $puzzle-objects = $!main.table.puzzle-objects;
    $!main.statusbar.set-status(
      "Number of puzzles: " ~ $puzzle-objects.get-n-items
    );

    $sts-ok = True;
  }

  else {
    $dialog.set-status('Please check to give your consent');
  }

  $dialog.destroy if $sts-ok;
}

#-------------------------------------------------------------------------------
method move-message-dialog (
  Int $response-id, Gnome::Gtk4::MessageDialog :_widget($message)
) {
  $message.destroy;
}