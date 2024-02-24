#`{{
Combobox widget to display the categories of puzzles. The widget is shown on
the main window. The actions to change the list are triggered from the
'category' menu. All changes are directly visible in the combobox on the main
page.
}}

use v6.d;

use PuzzleTable::Config;
use PuzzleTable::Gui::Statusbar;
use PuzzleTable::Gui::DialogLabel;

use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::PasswordEntry:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Tooltip:api<2>;
use Gnome::Gtk4::CheckButton:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::ComboBoxText:api<2>;
use Gnome::Gtk4::Dialog:api<2>;
use Gnome::Gtk4::T-Dialog:api<2>;
use Gnome::Gtk4::T-Enums:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Category:auth<github:MARTIMM>;
also is Gnome::Gtk4::ScrolledWindow;

has $!main is required;
has PuzzleTable::Config $!config;
has PuzzleTable::Gui::Statusbar $!statusbar;
has Gnome::Gtk4::Grid $!cat-grid;
has Str $!current-category;

#-------------------------------------------------------------------------------
# Initialize from main page
submethod BUILD ( :$!main ) {
  $!config = $!main.config;

  self.set-halign(GTK_ALIGN_FILL);
  self.set-valign(GTK_ALIGN_FILL);
  self.set-vexpand(True);
  self.set-propagate-natural-width(True);

  self.set-min-content-width(0);
  self.set-max-content-width(450);

  self.fill-sidebar(:init);
}

#-------------------------------------------------------------------------------
# Select from menu to add a category
method categories-add-category ( N-Object $parameter ) {

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
        self.fill-sidebar;
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

  my DialogLabel $ul-label .= new( 'Lock or unlock category', :$!config);
#  my DialogLabel $pw-label .= new( 'Type password to change', :$!config);
  my Gnome::Gtk4::CheckButton $check-button .= new-with-label(
    'Lock or unlock category'
  );
#  my Gnome::Gtk4::PasswordEntry $pw-entry .= new-passwordentry;
  $check-button.set-active(False);

  my Gnome::Gtk4::ComboBoxText $combobox .= new-comboboxtext;
  $combobox.register-signal(
    self, 'set-cat-lock-info', 'changed', :$check-button
  );

  $!statusbar .= new-statusbar(:context<category>);

  # Fill the combobox in the dialog. Using this filter, it isn't necessary to
  # check passwords. One is already authenticated or not.
  for $!config.get-categories(:filter<lockable>) -> $category {
    # skip 'default'
    next if $category eq 'Default';
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
#    .append($ul-label);
    .append($check-button);
    
    # Only ask for password if puzzletable is locked
#    if $!config.is-locked {
#      .append($pw-label);
#      .append($pw-entry);
#    }
    .append($!statusbar);
  }

  with $dialog {
    .set-size-request( 400, 100);
    .register-signal(
       self, 'do-category-lock', 'response', #, :$pw-entry,
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
#  Gnome::Gtk4::PasswordEntry :$pw-entry,
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
#`{{
      if $!config.is-locked {
        my Str $pw-text = $pw-entry.get-text.tc;
        if ! $!config.check-password($pw-text) {
          $!statusbar.set-status('Wrong password');
        }

        # Modify lockable category
        elsif $!config.set-category-lockable(
          $combobox.get-active-text, $check-button.get-active.Bool, $pw-text
        ) {
          self.fill-sidebar;
          $sts-ok = True;
        }

        else {
          $!statusbar.set-status('Empty password while one is needed?');
        }
      }

      else {
}}
        $!config.set-category-lockable(
          $combobox.get-active-text, $check-button.get-active.Bool
        );

        # Sidebar changes when a category is set lockable and table is locked
        self.fill-sidebar
          if $check-button.get-active.Bool and $!config.is-locked;
        $sts-ok = True;
#      }
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
  for $!config.get-categories(:filter<lockable>) -> $category {
    next if $category eq 'Default';
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
        self.fill-sidebar;
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

#`{{
#-------------------------------------------------------------------------------
method renew ( ) {
  self.fill-sidebar;

#`{{
  # Get current setting first
  my Str $current-cat = self.get-current-category;

  # Empty list and then refill
  self.remove-all;

  my Int ( $idx, $idx-default, $idx-current ) = ( 0, 0, -1);
  my Bool $not-locked = !$!config.is-locked;

  # Add to combobox unless locking is on and category is lockable
  for $!config.get-categories(:filter<lockable>) -> $category {
    self.append-text($category);
    $idx-default = $idx if $category eq 'Default';
    $idx-current = $idx if $category eq $current-cat;
    $idx++;
  }

  self.set-active($idx-current == -1 ?? $idx-default !! $idx-current);
}}
}
}}

#-------------------------------------------------------------------------------
method get-current-category ( --> Str ) {
  $!current-category // '';
}
#`{{
}}

#`{{
#-------------------------------------------------------------------------------
method set-current-category ( Str $category-select ) {
  my Int ( $idx, $idx-select) = ( 0, -1);
  for $!config.get-categories(:filter<lockable>) -> $category {
    $idx-select = $idx if $category eq $category-select;
    $idx++;
  }

  self.set-active($idx-select);
}
}}

#-------------------------------------------------------------------------------
method set-cat-lock-info (
  Gnome::Gtk4::ComboBoxText :_widget($combobox),
  Gnome::Gtk4::CheckButton :$check-button
) {
  $check-button.set-active(
    $!config.is-category-lockable($combobox.get-active-text)
  );
}

#-------------------------------------------------------------------------------
method fill-sidebar ( Bool :$init = False ) {

  if ?$!cat-grid and $!cat-grid.is-valid {
    $!cat-grid.clear-object;
  }

  
  my $row-count = 0;
  with $!cat-grid .= new-grid {      #new-box( GTK_ORIENTATION_VERTICAL, 0) {
    .set-name('sidebar');
    .set-size-request( 200, 100);

    my Gnome::Gtk4::Label $l;

    for $!config.get-categories(:filter<lockable>) -> $category {
      with my Gnome::Gtk4::Button $cat-button .= new-button {
        $!config.set-css( .get-style-context, :css-class<sidebar-label>);

        given $l .= new-label {
          .set-text($category);
          .set-hexpand(True);
          .set-halign(GTK_ALIGN_START);
        }
        .set-child($l);

#        .set-label($category);
        .set-hexpand(True);
        .set-halign(GTK_ALIGN_FILL);
        .set-has-tooltip(True);
        .register-signal( self, 'show-tooltip', 'query-tooltip', :$category);
        .register-signal( self, 'select-category', 'clicked', :$category);
      }

      .attach( $cat-button, 0, $row-count, 1, 1);
      #.append($cat-button);

      my Array $cat-status = $!config.get-category-status($category);
#note "$?LINE $cat-status.gist(), $cat-status[0].fmt('%3d')";
      $l .= new-label; $l.set-text($cat-status[0].fmt('%3d'));
      .attach( $l, 1, $row-count, 1, 1);

      $l .= new-label; $l.set-text($cat-status[1].fmt('%3d'));
      .attach( $l, 2, $row-count, 1, 1);

      $l .= new-label; $l.set-text($cat-status[2].fmt('%3d'));
      .attach( $l, 3, $row-count, 1, 1);

      $l .= new-label; $l.set-text($cat-status[3].fmt('%3d'));
      $l.set-margin-end(10);
      .attach( $l, 4, $row-count, 1, 1);

      $row-count++;
    }
  }

  self.set-child($!cat-grid);
  self.select-category(:category<Default>) if $init;
}

#-------------------------------------------------------------------------------
method show-tooltip (
  Int $x, Int $y, gboolean $kb-mode, Gnome::Gtk4::Tooltip() $tooltip,
  Str :$category
  --> gboolean
) {
  my Gnome::Gtk4::Picture $p .= new-picture;
  $p.set-filename($!config.get-puzzle-image($category));
  $tooltip.set-custom($p);
  True
}

#-------------------------------------------------------------------------------
# Method to handle a category selection
method select-category ( Str :$category ) {

  $!current-category = $category;
  $!main.application-window.set-title("Puzzle Table Display - $category")
    if ?$!main.application-window;

  # Clear the puzzletable before showing the puzzles of this category
  $!main.table.clear-table;

  # Get the puzzles and send them to the table
  my Seq $puzzles = $!config.get-puzzles($category).sort(
    -> $item1, $item2 { 
      if $item1<PieceCount> < $item2<PieceCount> { Order::Less }
      elsif $item1<PieceCount> == $item2<PieceCount> { Order::Same }
      else { Order::More }
    }
  );

  $!main.table.add-puzzles-to-table($puzzles);
}

#-------------------------------------------------------------------------------
# Method to handle a category selection
method set-category ( Str $category ) {

  # Fill the sidebar in case there is a new entry
  self.fill-sidebar;
  self.select-category(:$category);
}
