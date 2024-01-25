#`{{
Combobox widget to display the categories of puzzles. The widget is shown on
the main window. The actions to change the list are triggered from the
'category' menu. All changes are directly visible in the combobox on the main
page.
}}

use v6.d;

use PuzzleTable::Config;
use PuzzleTable::Gui::Statusbar;
use PuzzleTable::Gui::Table;
use PuzzleTable::Gui::DialogLabel;

use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::PasswordEntry:api<2>;
use Gnome::Gtk4::CheckButton:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::ComboBoxText:api<2>;
use Gnome::Gtk4::Dialog:api<2>;
use Gnome::Gtk4::T-Dialog:api<2>;
use Gnome::Gtk4::T-Enums:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Category:auth<github:MARTIMM>;
also is Gnome::Gtk4::ComboBoxText;

has $!main is required;
has PuzzleTable::Config $!config;
has PuzzleTable::Gui::Table $!table;
has PuzzleTable::Gui::Statusbar $!statusbar;

#-------------------------------------------------------------------------------
# Initialize from main page
submethod BUILD ( :$!main ) {
  $!config = $!main.config;
  $!table = $!main.table;
  self.set-active(0);

  self.register-signal( self, 'cat-selected', 'changed');
}

#-------------------------------------------------------------------------------
# Select from menu to add a category
method categories-add-category ( N-Object $parameter ) {
#  say 'category add';

  my DialogLabel $label .= new( 'Specify a new category', :$!config);
  my Gnome::Gtk4::Entry $entry .= new-entry;
  my Gnome::Gtk4::CheckButton $check-button .= new-with-label('Locked');
  $check-button.set-active(False);
  $!statusbar .= new-statusbar(:context<category>);

  my Gnome::Gtk4::Dialog $dialog .= new-with-buttons(
    'Add Category Dialog', $!main.application-window,
    GTK_DIALOG_MODAL +| GTK_DIALOG_DESTROY_WITH_PARENT,
         'Add', GEnum, GTK_RESPONSE_ACCEPT,
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
    .append($entry);
    .append($check-button);
    .append($!statusbar);
  }

  with $dialog {
    .set-size-request( 400, 100);
    .register-signal(
       self, 'do-category-add', 'response', :$entry, :$check-button
    );
    .register-signal( self, 'destroy-dialog', 'destroy');
    $!config.set-css( .get-style-context, :css-class<dialog>);
    .set-name('category-dialog');
    my $r = .show;
  }
}

#-------------------------------------------------------------------------------
method do-category-add (
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::Entry :$entry, Gnome::Gtk4::CheckButton :$check-button
) {
  my Bool $sts-ok = False;
  $!statusbar.remove-message;

  my GtkResponseType() $response-type = $response-id;  
  given $response-type {
    when GTK_RESPONSE_DELETE_EVENT {
      #ignore
      $sts-ok = True;
    }

    when GTK_RESPONSE_ACCEPT {
      my Str $cat-text = $entry.get-text.tc;

      if !$cat-text {
        $!statusbar.set-status('No category name specified');
      }

      elsif $cat-text.lc eq 'default' {
        $!statusbar.set-status(
          'Category \'default\' is fixed in any form of text-case'
        );
      }

      elsif $!config.check-category($cat-text.tc) {
        $!statusbar.set-status('Category already defined');
      }

      else {
        # Add category to list
        $!main.config.add-category( $cat-text.tc, $check-button.get-active);
        self.renew;
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
# Select from menu to lock or unlock a category
method categories-lock-category ( N-Object $parameter ) {
#  say 'category add';

  my DialogLabel $ul-label .= new( 'Lock or unlock category', :$!config);
  my DialogLabel $pw-label .= new( 'Type password to change', :$!config);
  my Gnome::Gtk4::CheckButton $check-button .= new-with-label('Locked');
  my Gnome::Gtk4::PasswordEntry $pw-entry .= new-passwordentry;
  $check-button.set-active(False);
  my Gnome::Gtk4::ComboBoxText $combobox.= new-comboboxtext;
  $!statusbar .= new-statusbar(:context<category>);

  # Fill the combobox in the dialog
  for $!config.get-categories -> $category {
    # Don't let default be changed
    next if $category.lc eq 'default';
    $combobox.append-text($category);
  }
  $combobox.set-active(0);

  my Gnome::Gtk4::Dialog $dialog .= new-with-buttons(
    'Add Category Dialog', $!main.application-window,
    GTK_DIALOG_MODAL +| GTK_DIALOG_DESTROY_WITH_PARENT,
         'Change', GEnum, GTK_RESPONSE_ACCEPT,
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
    .append($combobox);
    .append($ul-label);
    .append($check-button);
    .append($pw-label);
    .append($pw-entry);
    .append($!statusbar);
  }

  with $dialog {
    .set-size-request( 400, 100);
    .register-signal(
       self, 'do-category-lock', 'response', :$pw-entry,
       :$check-button, :$combobox
    );
    .register-signal( self, 'destroy-dialog', 'destroy');
    $!config.set-css( .get-style-context, :css-class<dialog>);
    .set-name('category-dialog');
    .show;
  }
}

#-------------------------------------------------------------------------------
method do-category-lock (
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::PasswordEntry :$pw-entry,
  Gnome::Gtk4::CheckButton :$check-button,
  Gnome::Gtk4::ComboBox :$combobox
) {
  my Bool $sts-ok = False;
  $!statusbar.remove-message;

  my GtkResponseType() $response-type = $response-id;  
  given $response-type {
    when GTK_RESPONSE_DELETE_EVENT {
      #ignore
      $sts-ok = True;
    }

    when GTK_RESPONSE_ACCEPT {
      my Str $pw-text = $pw-entry.get-text.tc;
      if ! $!config.check-password($pw-text) {
        $!statusbar.set-status('Wrong password');
      }

      # Modify lockable category
      elsif $!main.config.set-category-lockable(
        $combobox.get-active-text, $check-button.get-active.Bool, $pw-text
      ) {
        self.renew;
        $sts-ok = True;
      }

      else {
        $!statusbar.set-status('Empty password while one is needed?');
      }
    }

    when GTK_RESPONSE_CANCEL {
      $sts-ok = True;
    }
  }

  $dialog.destroy if $sts-ok;
}

#-------------------------------------------------------------------------------
# Select from menu to rename a category
method categories-rename-category ( N-Object $parameter ) {
#  say 'category rename';

  my DialogLabel $label1 .= new( 'Select category from list', :$!config);
  my DialogLabel $label2 .= new( 'Text to rename category', :$!config);
  my Gnome::Gtk4::Entry $entry .= new-entry;
  my Gnome::Gtk4::ComboBoxText $combobox.= new-comboboxtext;
  $!statusbar .= new-statusbar(:context<categories>);

  # Fill the combobox in the dialog
  for $!config.get-categories -> $category {
    # Don't let default be changed
    next if $category.lc eq 'default';
    $combobox.append-text($category);
  }
  $combobox.set-active(0);

  my Gnome::Gtk4::Dialog $dialog .= new-with-buttons(
    'Add Category dialog', $!main.application-window,
    GTK_DIALOG_MODAL +| GTK_DIALOG_DESTROY_WITH_PARENT,
         'Rename', GEnum, GTK_RESPONSE_ACCEPT,
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
    .append($label1);
    .append($combobox);
    .append($label2);
    .append($entry);
    .append($!statusbar);
  }

  with $dialog {
    .set-size-request( 400, 100);
    .register-signal(
      self, 'do-category-rename', 'response', :$entry, :$combobox
    );
    .register-signal( self, 'destroy-dialog', 'destroy');
    $!config.set-css( .get-style-context, :css-class<dialog>);
    .set-name('category-dialog');
    .show;
  }
}

#-------------------------------------------------------------------------------
method do-category-rename (
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::Entry :$entry, Gnome::Gtk4::ComboBoxText :$combobox,
) {
  my Bool $sts-ok = False;
  $!statusbar.remove-message;

  my GtkResponseType() $response-type = $response-id;

  given $response-type {
    when GTK_RESPONSE_DELETE_EVENT {
      note 'deleted';
      #ignore
      $sts-ok = True;
    }

    when GTK_RESPONSE_ACCEPT {
      my Str $cat-text = $entry.get-text.tc;

      if !$cat-text {
        $!statusbar.set-status('No category name specified');
      }

      elsif $cat-text.lc eq 'default' {
        $!statusbar.set-status(
          'Category \'default\' is fixed in any form of text-case'
        );
      }

      elsif $!config.check-category($cat-text.tc) {
        $!statusbar.set-status('Category already defined');
      }

      elsif $cat-text.tc eq $combobox.get-active-text {
        $!statusbar.set-status('Category text same as selected');
      }

      else {
        # Move members to other category
        $!config.move-category( $combobox.get-active-text, $cat-text.tc);
        self.renew;
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
# Select from menu to remove a category
method categories-remove-category ( N-Object $parameter ) {
  say 'category remove';
}

#-------------------------------------------------------------------------------
method do-category-remove (
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::Entry :$entry, Gnome::Gtk4::ComboBoxText :$combobox,
) {
}

#-------------------------------------------------------------------------------
method destroy-dialog ( Gnome::Gtk4::Dialog :_widget($dialog) ) {
#  say 'destroy cat dialog';
  $dialog.destroy;
}

#-------------------------------------------------------------------------------
method renew ( ) {
  # Get current setting first
  my Str $current-cat = self.get-current-category;

  # Empty list and then refill
  self.remove-all;

  my Int ( $idx, $idx-default, $idx-current ) = ( 0, 0, -1);
  my Bool $not-locked = !$!config.is-locked;
  for $!config.get-categories -> $key {
    # Add to combobox unless locking is on and category is lockable
    if $not-locked or !$!config.is-category-lockable($key) {
      self.append-text($key);
      $idx-default = $idx if $key eq 'Default';
      $idx-current = $idx if $key eq $current-cat;
      $idx++;
    }
  }

  self.set-active($idx-current == -1 ?? $idx-default !! $idx-current);
}

#-------------------------------------------------------------------------------
method get-current-category ( --> Str ) {
  self.get-active-text // '';
}

#-------------------------------------------------------------------------------
# Callback to handle selection of a combobox entry.
method cat-selected ( ) {

  # Get the selected category
  my Str $cat = self.get-current-category;
  return unless ?$cat;

  # Clear the puzzletable before showing the puzzles of this category
  $!table.clear-table;

  # Get the puzzles and send them to the table
  my Seq $puzzles = $!config.get-puzzles($cat).sort(
    -> $item1, $item2 { 
      if $item1<PieceCount> < $item2<PieceCount> { Order::Less }
      elsif $item1<PieceCount> == $item2<PieceCount> { Order::Same }
      else { Order::More }
    }
  );

  for @$puzzles -> $p {
    $!table.add-puzzle-to-table($p);
  }
}
