#`{{
Combobox widget to display the categories of puzzles. The widget is shown on
the main window. The actions to change the list are triggered from the
'category' menu. All changes are directly visible in the combobox on the main
page.
}}

use v6.d;

use PuzzleTable::Config;
use PuzzleTable::Gui::Dialog;

use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::PasswordEntry:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Tooltip:api<2>;
use Gnome::Gtk4::CheckButton:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Expander:api<2>;
use Gnome::Gtk4::ComboBoxText:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::DropDown:api<2>;
use Gnome::Gtk4::StringList:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Sidebar:auth<github:MARTIMM>;
also is Gnome::Gtk4::ScrolledWindow;

has $!main is required;
has PuzzleTable::Config $!config;
#has Gnome::Gtk4::Grid $!cat-grid;
#has Str $!current-category;

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
method categories-add-container ( N-Object $parameter ) {

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Add Category Dialog')
  ) {
    # Show entry for input
    .add-content(
      'Specify a new container', my Gnome::Gtk4::Entry $entry .= new-entry
    );

    # Buttons to add the container or cancel
    .add-button( self, 'do-container-add', 'Add', :$entry, :$dialog);
    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-container-add (
  PuzzleTable::Gui::Dialog :$dialog, Gnome::Gtk4::Entry :$entry
) {
  my Bool $sts-ok = False;
  my Str $container-text = $entry.get-text.tc;
  if ! $container-text {
    $dialog.set-status('No category name specified');
  }

  elsif not $!config.add-container($container-text) {
    $dialog.set-status('Container already exists');
  }

  else {
    self.fill-sidebar;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method categories-delete-container ( N-Object $parameter ) {

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Add Category Dialog')
  ) {
    # Make a string list to be used in a combobox (dropdown)
    my Gnome::Gtk4::DropDown() $dropdown = self.fill-containers(:no-enpty);

    # Buttons to delete the container or cancel
    .add-button( self, 'do-container-delete', 'Delete', :$dropdown, :$dialog);
    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-container-delete (
  PuzzleTable::Gui::Dialog :$dialog, Gnome::Gtk4::DropDown() :$dropdown
) {
  my Bool $sts-ok = False;
  my Str $container = self.get-dropdown-text($dropdown);
  
  if not $!config.delete-container($container) {
    $dialog.set-status("Container $container not empty");
  }

  else {
    self.fill-sidebar;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
# Select from menu to add a category
method categories-add-category ( N-Object $parameter ) {

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Add Category Dialog')
  ) {
    # Make a string list to be used in a combobox (dropdown)
    my Gnome::Gtk4::DropDown() $dropdown = self.fill-containers;

    # Show dropdown
    .add-content( 'Select a container', $dropdown);

    # Show entry for input
    .add-content(
      'Specify a new category', my Gnome::Gtk4::Entry $entry .= new-entry
    );

    # Show checkbutton to make the category locakbel
    .add-content(
      '', my Gnome::Gtk4::CheckButton $check-button .= new-with-label(
        'Lockable Category'
      )
    );

    # Buttons to add the category or cancel
    .add-button(
      self, 'do-category-add', 'Add', :$entry, :$check-button,
      :$dialog, :$dropdown
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-category-add (
  PuzzleTable::Gui::Dialog :$dialog,
  Gnome::Gtk4::Entry :$entry, Gnome::Gtk4::CheckButton :$check-button,
  Gnome::Gtk4::DropDown :$dropdown
) {
  my Bool $sts-ok = False;
  my Str $cat-text = $entry.get-text.tc;

  if !$cat-text {
    $dialog.set-status('No category name specified');
  }

  elsif $cat-text.lc eq 'default' {
    $dialog.set-status(
      'Category \'default\' is fixed in any form of text-case'
    );
  }

  else {
    my Str $category-container = self.get-dropdown-text($dropdown);
    $category-container = '' if $category-container eq '--';

    # Add category to list. Message gets defined if something is wrong.
    my Str $msg = $!main.config.add-category(
      $cat-text, :lockable($check-button.get-active), :$category-container
    );

    if ?$msg {
      $dialog.set-status($msg);
    }

    else {
      self.fill-sidebar;
      $sts-ok = True;
    }
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
# Select from menu to lock or unlock a category
method categories-lock-category ( N-Object $parameter ) {

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('(Un)Lock Dialog')
  ) {
    my Gnome::Gtk4::CheckButton $check-button .=
      new-with-label('Lock or unlock category');
    $check-button.set-active(False);

    my Gnome::Gtk4::DropDown $dropdown = self.fill-categories(:skip-default);

#`{{
    my Gnome::Gtk4::ComboBoxText $combobox .= new-comboboxtext;
    $combobox.register-signal(
      self, 'set-cat-lock-info', 'changed', :$check-button
    );

    # Fill the combobox in the dialog. Using this filter, it isn't necessary to
    # check passwords. One is already authenticated or not.
    for $!config.get-categories -> $category {
      # skip 'default'
      next if $category eq 'Default';
      if $category ~~ m/ '_EX_' $/ {
        for $!config.get-categories(:category-container($category)) -> $subcat {
          $combobox.append-text($subcat);
        }
      }

      else {
        $combobox.append-text($category);
      }
    }
    $combobox.set-active(0);
}}

    .add-content( 'Category to (un)lock', $dropdown);
    .add-content( '', $check-button);

    .add-button(
      self, 'do-category-lock', 'Lock / Unlock', :$dropdown, :$dialog, :$check-button
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-category-lock (
  PuzzleTable::Gui::Dialog :$dialog, Gnome::Gtk4::CheckButton :$check-button,
  Gnome::Gtk4::DropDown :$dropdown
) {
  my Bool $sts-ok = False;

  $!config.set-category-lockable(
    self.get-dropdown-text($dropdown), $check-button.get-active.Bool
  );

  # Sidebar changes when a category is set lockable and table is locked
  self.fill-sidebar if $check-button.get-active.Bool and $!config.is-locked;
  $sts-ok = True;

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
# Select from menu to rename a category
method categories-rename-category ( N-Object $parameter ) {
#  say 'category rename';

  my Gnome::Gtk4::Entry $entry .= new-entry;
  my Gnome::Gtk4::DropDown $dropdown-cat = self.fill-categories(:skip-default);
  my Gnome::Gtk4::DropDown $dropdown-cont = self.fill-containers;
#`{{
  my Gnome::Gtk4::ComboBoxText $combobox.= new-comboboxtext;

  # Fill the combobox in the dialog
  for $!config.get-categories -> $category {
    next if $category eq 'Default';
    if $category ~~ m/ '_EX_' $/ {
      for $!config.get-categories(:category-container($category)) -> $subcat {
        $combobox.append-text($subcat);
      }
    }

    else {
      $combobox.append-text($category);
    }
  }
  $combobox.set-active(0);
}}

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Rename Category dialog')
  ) {
#    .add-content( 'Specify the category to rename', $combobox);
    .add-content( 'Specify the category to rename', $dropdown-cat);
    .add-content( 'Select container', $dropdown-cont);
    .add-content( 'New category name', $entry);

    .add-button(
      self, 'do-category-rename', 'Rename',
      :$entry, :$dropdown-cat, :$dropdown-cont, :$dialog
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-category-rename (
  PuzzleTable::Gui::Dialog :$dialog,
  Gnome::Gtk4::Entry :$entry, Gnome::Gtk4::DropDown :$dropdown-cat,
  Gnome::Gtk4::DropDown :$dropdown-cont,
) {
  my Bool $sts-ok = False;
  my Str $old-category = self.get-dropdown-text($dropdown-cat);
  my Str $new-category = $entry.get-text.tc;

  if ! $new-category {
    $dialog.set-status('No category name specified');
  }

  elsif $new-category.lc eq 'default' {
    $dialog.set-status('Category \'default\' cannot be renamed');
  }

  elsif $new-category.tc eq $old-category {
    $dialog.set-status('Category text same as selected');
  }

  else {
    # Move members to other category and container
    my Str $container = self.get-dropdown-text($dropdown-cont);
    $container = '' if $container eq '--';
    $!config.move-category(
      $old-category, $new-category.tc, :category-container($container)
    );
    self.fill-sidebar;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#`{{
#-------------------------------------------------------------------------------
# Select from menu to remove a category
method categories-remove-category ( N-Object $parameter ) {
  say 'category remove';
}

#-------------------------------------------------------------------------------
method do-category-remove (
  PuzzleTable::Gui::Dialog :$dialog,
  Gnome::Gtk4::Entry :$entry, Gnome::Gtk4::ComboBoxText :$combobox,
) {
}
}}

#-------------------------------------------------------------------------------
method fill-categories (
  Bool :$skip-default = False --> Gnome::Gtk4::DropDown
) {
  my Gnome::Gtk4::StringList $category-list .= new-stringlist([]);
  my Gnome::Gtk4::DropDown $dropdown .= new-dropdown($category-list);

  for $!config.get-categories -> $category {
    next if $skip-default and $category eq 'Default';

    if $category ~~ m/ '_EX_' $/ {
      for $!config.get-categories(:category-container($category)) -> $subcat {
        $category-list.append($subcat);
      }
    }

    else {
      $category-list.append($category);
    }
  }

  $dropdown
}

#-------------------------------------------------------------------------------
method fill-containers ( Bool :$no-enpty = False --> Gnome::Gtk4::DropDown ) {
  my Gnome::Gtk4::StringList $category-list .= new-stringlist([]);
  my Gnome::Gtk4::DropDown $dropdown .= new-dropdown($category-list);

  # Add an entry to be able to select a category at toplevel
  $category-list.append('--') unless $no-enpty;

  # Add the container strings
  for $!config.get-containers -> $container {
    $category-list.append($container);
  }

  $dropdown
}

#-------------------------------------------------------------------------------
method get-dropdown-text ( Gnome::Gtk4::DropDown $dropdown --> Str ) {
  my Gnome::Gtk4::StringList() $string-list = $dropdown.get-model;
  $string-list.get-string($dropdown.get-selected)
}

#-------------------------------------------------------------------------------
# Select from menu to refresh the sidebar
method categories-refresh-sidebar ( N-Object $parameter ) {
  self.fill-sidebar;
}

#`{{
#-------------------------------------------------------------------------------
method get-current-category ( --> Str ) {
  $!current-category // '';
}
}}

#-------------------------------------------------------------------------------
method set-cat-lock-info (
  Gnome::Gtk4::ComboBoxText() :_native-object($combobox),
  Gnome::Gtk4::CheckButton :$check-button
) {
#TODO container name
  $check-button.set-active(
    $!config.is-category-lockable($combobox.get-active-text)
  );
}

#-------------------------------------------------------------------------------
method fill-sidebar ( Bool :$init = False ) {
  my Gnome::Gtk4::Grid() $cat-grid = self.get-child;
  $cat-grid.clear-object;

  # Remove all buttons and info from sidebar
#  if ?$!cat-grid and $!cat-grid.is-valid {
#    $!cat-grid.clear-object;
#  }

  # Create new sidebar
  my $row-count = 0;
  #with $!cat-grid .= new-grid {
    $cat-grid .= new-grid;
    $cat-grid.set-name('sidebar');
    $cat-grid.set-size-request( 200, 100);
    $!config.set-css(
      $cat-grid.get-style-context, :css-class<pt-sidebar>
    );

    my Gnome::Gtk4::Label $l;

    my Array $totals = [ 0, 0, 0, 0];
    for $!config.get-categories -> $category {
#note "$?LINE $category";
      if $category ~~ m/ '_EX_' $/ {
        my Str $category-container = $category;
        $category-container ~~ s/ '_EX_' $//;
        my Int $subcat-row-count = 0;
        my Gnome::Gtk4::Grid $subcat-grid .= new-grid;
        for $!config.get-categories(:$category-container) -> $sub-category {
          my Gnome::Gtk4::Button $subcat-button =
             self.sidebar-button( $sub-category, $category-container);

          $subcat-grid.attach( $subcat-button, 0, $subcat-row-count, 1, 1);

          # Get information of each subcategory
          self.sidebar-status(
            $sub-category, $subcat-grid, $subcat-row-count, $totals,
            :$category-container
          );

          $subcat-row-count++;
        }

        # Only show container if there are any categories visible
        if $subcat-row-count {
          my Gnome::Gtk4::Expander $expander =
            self.sidebar-expander($category-container);
          $expander.set-child($subcat-grid);
          $cat-grid.attach( $expander, 0, $row-count, 5, 1);
        }
      }

      else {
        my Gnome::Gtk4::Button $cat-button = self.sidebar-button($category);
        $cat-grid.attach( $cat-button, 0, $row-count, 1, 1);

        # Get information of each category
        self.sidebar-status( $category, $cat-grid, $row-count, $totals);
      }

      $row-count++;
    }

    # Display gathered information in a tooltip
    $cat-grid.set-tooltip-text(Q:qq:to/EOTT/);
      Number of puzzles
      Untouched puzzles
      Unfinished puzzles
      Finished puzzles

      Totals
      [ $totals.join(', ') ]
      EOTT
  #}

  self.set-child($cat-grid);
  self.select-category(:category<Default>) if $init;
}

#-------------------------------------------------------------------------------
method sidebar-button (
  Str $category, Str $category-container = '' --> Gnome::Gtk4::Button
) {
  with my Gnome::Gtk4::Button $cat-button .= new-button {
    $!config.set-css(
      .get-style-context,
      :css-class( ? $category-container
                  ?? 'pt-sidebar-container-button'
                  !! 'pt-sidebar-category-button'
                )
    );

    my Str $catname = ?$category-container ?? $category-container !! $category;

    given my Gnome::Gtk4::Label $l .= new-label {
      .set-text($category);
      .set-hexpand(True);
      .set-halign(GTK_ALIGN_START);
#      .set-max-width-chars(? $category-container ?? 23 !! 25 );
#      .set-ellipsize(True);

      $!config.set-css(
        .get-style-context,
        :css-class(
          ? $category-container
            ?? 'pt-sidebar-container-label'
            !! 'pt-sidebar-category-label'
        )
      );
    }

    .set-child($l);
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_FILL);
    .set-has-tooltip(True);

    .register-signal(
      self, 'show-tooltip', 'query-tooltip', :$category
    );
    .register-signal(
      self, 'select-category', 'clicked', :$category, :$category-container
    );
  }
  
  $cat-button
}

#-------------------------------------------------------------------------------
method sidebar-expander ( Str $category --> Gnome::Gtk4::Expander ) {
  with my Gnome::Gtk4::Expander $cat-expander .= new-expander(Str) {
    $!config.set-css( .get-style-context, :css-class<pt-sidebar-expander>);

    given my Gnome::Gtk4::Label $l .= new-label {
      .set-text($category);
      .set-hexpand(True);
      .set-halign(GTK_ALIGN_START);
      $!config.set-css(
        .get-style-context, :css-class('sidebar-expander-label')
      );
    }

    .set-label-widget($l);
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_FILL);
  }
  
  $cat-expander
}

#-------------------------------------------------------------------------------
method sidebar-status (
  Str $category,
  Gnome::Gtk4::Grid $grid, Int $row-count, Array $totals,
  Str :$category-container = ''
) {
  my Gnome::Gtk4::Label $l;

  my Array $cat-status =
     $!config.get-category-status( $category, :$category-container);

  $l .= new-label; $l.set-text($cat-status[0].fmt('%3d'));
  $grid.attach( $l, 1, $row-count, 1, 1);
  $totals[0] += $cat-status[0];

  $l .= new-label; $l.set-text($cat-status[1].fmt('%3d'));
  $grid.attach( $l, 2, $row-count, 1, 1);
  $totals[1] += $cat-status[1];

  $l .= new-label; $l.set-text($cat-status[2].fmt('%3d'));
  $grid.attach( $l, 3, $row-count, 1, 1);
  $totals[2] += $cat-status[2];

  $l .= new-label; $l.set-text($cat-status[3].fmt('%3d'));
  $l.set-margin-end(10);
  $grid.attach( $l, 4, $row-count, 1, 1);
  $totals[3] += $cat-status[3];
}

#-------------------------------------------------------------------------------
method show-tooltip (
  Int $x, Int $y, gboolean $kb-mode, Gnome::Gtk4::Tooltip() $tooltip,
  Str :$category
  --> gboolean
) {
  my Str $puzzle-image-name = $!config.get-puzzle-image($category);
  if ?$puzzle-image-name {
    my Gnome::Gtk4::Picture $p .= new-picture;
    $p.set-filename($puzzle-image-name);
    $tooltip.set-custom($p);
  }

  True
}

#-------------------------------------------------------------------------------
# Method to handle a category selection
method select-category ( Str :$category, Str :$category-container = '' ) {
#  $!current-category = $category;
  $!main.application-window.set-title("Puzzle Table Display - $category")
    if ?$!main.application-window;

  # Clear the puzzle table before showing the puzzles of this category
  $!main.table.clear-table;

  # Get the puzzles and send them to the table
  $!config.select-category( $category, :$category-container);
  my Seq $puzzles = $!config.get-puzzles;

  # Fill the puzzle table with new puzzles
  $!main.table.add-puzzles-to-table($puzzles);
}

#-------------------------------------------------------------------------------
# Method to handle a category selection
method set-category ( Str $category ) {

  # Fill the sidebar in case there is a new entry
  self.fill-sidebar;
  self.select-category(:$category);
}
