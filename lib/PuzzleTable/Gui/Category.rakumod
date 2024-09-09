=begin pod
Combobox widget to display the categories of puzzles. The widget is shown on
the main window. The actions to change the list are triggered from the
'category' menu. All changes are directly visible in the combobox on the main
page.
=end pod

use v6.d;

use PuzzleTable::Config;
use PuzzleTable::Gui::Dialog;
use PuzzleTable::Gui::DropDown;

use Gnome::Gtk4::Entry:api<2>;
#use Gnome::Gtk4::PasswordEntry:api<2>;
#use Gnome::Gtk4::Picture:api<2>;
#use Gnome::Gtk4::Tooltip:api<2>;
use Gnome::Gtk4::CheckButton:api<2>;
#use Gnome::Gtk4::Button:api<2>;
#use Gnome::Gtk4::Label:api<2>;
#use Gnome::Gtk4::Grid:api<2>;
#use Gnome::Gtk4::Box:api<2>;
#use Gnome::Gtk4::Expander:api<2>;
#use Gnome::Gtk4::ComboBoxText:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
#use Gnome::Gtk4::ScrolledWindow:api<2>;
#use Gnome::Gtk4::DropDown:api<2>;
#use Gnome::Gtk4::StringList:api<2>;

#use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Category:auth<github:MARTIMM>;
#also is Gnome::Gtk4::ScrolledWindow;

has $!main is required;
has PuzzleTable::Config $!config;
has $!sidebar;
#has Gnome::Gtk4::Grid $!cat-grid;
#has Str $!current-category;

#-------------------------------------------------------------------------------
# Initialize from main page
submethod BUILD ( :$!main ) {
  $!config .= instance;
  $!sidebar = $!main.sidebar;
}

#-------------------------------------------------------------------------------
# Select from menu to add a category
method category-add ( N-Object $parameter ) {

  my Str $select-category = $!config.get-current-category;

  # Make a string list to be used in a combobox (dropdown)
  my PuzzleTable::Gui::DropDown $dropdown .= new;
  $dropdown.fill-containers($!config.get-current-container);

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :dialog-header('Add Category Dialog')
  ) {

    # Show dropdown
    .add-content( 'Select a container', $dropdown);

    # Show entry for input
    my Gnome::Gtk4::Entry $entry .= new-entry;
    $entry.set-text($select-category);
    .add-content( 'Specify a new category', $entry);

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
  PuzzleTable::Gui::DropDown :$dropdown
) {
  my Bool $sts-ok = False;
  my Str $category = $entry.get-text;

  if !$category {
    $dialog.set-status('No category name specified');
  }

  elsif $category.lc eq 'default' {
    $dialog.set-status(
      'Category \'default\' is fixed in any form of text-case'
    );
  }

  else {
    my Str $container = $dropdown.get-dropdown-text;
#    $container = '' if $container eq '--';

    # Add category to list. Message gets defined if something is wrong.
    my Str $msg = $!config.add-category(
      $category, $container, :lockable($check-button.get-active)
    );

    if ?$msg {
      $dialog.set-status($msg);
    }

    else {
      $!sidebar.fill-sidebar;
      $sts-ok = True;
    }
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
=begin pod
=head2 category-rename

Select from menu to rename a category. First select a category from the sidebar. There are two lists of categories and containers. These are used to rename the selected category. There is also a drop down list to select a container where the renamed category must reside.

  .category-rename ( N-Object $parameter )

=item $parameter; Data given by the menu action. It is not set so it can be ignored

=end pod

method category-rename ( N-Object $parameter ) {

  my Str $select-category = $!config.get-current-category;
  my Str $select-container = $!config.get-current-container;

  # Prepare dialog entries.
  # An entry to change the name of the selected category, prefilled with
  # the current one.
  my Gnome::Gtk4::Entry $new-cat-entry .= new-entry;
  $new-cat-entry.set-text($select-category);

  # A dropdown to list categories. The current category is preselected.
  my PuzzleTable::Gui::DropDown $old-cat-dropdown .= new;
  $old-cat-dropdown.fill-categories(
    $select-category, $select-container, :skip-default
  );

  # A dropdown to list categories. The current category is preselected.
  my PuzzleTable::Gui::DropDown $old-cont-dropdown .= new;
  $old-cont-dropdown.fill-containers($select-container);

  # Find the container of the current category and use it in the container
  # list to preselect it.
  with my PuzzleTable::Gui::DropDown $new-cont-dropdown .= new {
    .fill-containers($select-container);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    .trap-container-changes( $old-cat-dropdown, :skip-default);
  }

  # Build the dialog
  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :dialog-header('Rename Category dialog')
  ) {
    .add-content( 'Select container to show category list', $old-cont-dropdown);
    .add-content( 'Specify the category to rename', $old-cat-dropdown);
    .add-content( 'Select container to move category to', $new-cont-dropdown);
    .add-content( 'New category name', $new-cat-entry);

    .add-button(
      self, 'do-category-rename', 'Rename',
      :$old-cat-dropdown, :$old-cont-dropdown,
      :$new-cat-entry, :$new-cont-dropdown,
      :$dialog
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-category-rename (
  PuzzleTable::Gui::DropDown :$old-cat-dropdown,
  PuzzleTable::Gui::DropDown :$old-cont-dropdown,
  Gnome::Gtk4::Entry :$new-cat-entry,
  PuzzleTable::Gui::DropDown :$new-cont-dropdown,
  PuzzleTable::Gui::Dialog :$dialog,
) {
  my Bool $sts-ok = False;
   my Str $new-category = $new-cat-entry.get-text;

  if ! $new-category {
    $dialog.set-status('No category name specified');
  }

  elsif $new-category.lc eq 'default' {
    $dialog.set-status('Category \'default\' cannot be renamed');
  }

#  elsif $new-category.tc eq $old-category {
#    $dialog.set-status('Category text same as selected');
#  }

  else {
    # Move members to other category and container
    my Str $message = $!config.move-category(
      $old-cat-dropdown.get-dropdown-text,
      $old-cat-dropdown.get-dropdown-text,
      $new-category,
      $new-cont-dropdown.get-dropdown-text
    );

    if $message {
      $dialog.set-status($message);
    }

    else {
      $!sidebar.fill-sidebar;
      $sts-ok = True;
    }
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
# Select from menu to remove a category
method category-delete ( N-Object $parameter ) {

  my Str $select-category = $!config.get-current-category;
  my Str $select-container = $!config.get-current-container;

  # Prepare dialog entries.
  # A dropdown to list categories. The current category is preselected.
  my PuzzleTable::Gui::DropDown $dropdown-cat .= new;
  $dropdown-cat.fill-categories(
    $select-category, $select-container, :skip-default
  );

  # Find the container of the current category and use it in the container
  # list to preselect it.
  with my PuzzleTable::Gui::DropDown $dropdown-cont .= new {
    .fill-containers($!config.get-current-container);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    .trap-container-changes( $dropdown-cat, :skip-default);
  }

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :dialog-header('Rename Category dialog')
  ) {
    .add-content( 'Select container', $dropdown-cont);
    .add-content( 'Select category to delete', $dropdown-cat);

    .add-button(
      self, 'do-category-delete', 'Delete', :dropdown($dropdown-cat), :$dialog
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-category-delete (
  PuzzleTable::Gui::Dialog :$dialog, PuzzleTable::Gui::DropDown :$dropdown
) {
  my Bool $sts-ok = False;
  my Str $category = $dropdown.get-dropdown-text;
  if $!config.has-puzzles($category) {
    $dialog.set-status('Category still has puzzles');
  }

  else {
    $!config.delete-category($category);
    $!sidebar.fill-sidebar;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
# Select from menu to lock or unlock a category
method category-lock ( N-Object $parameter ) {

  my Str $select-category = $!config.get-current-category;
  my Str $select-container = $!config.get-current-container;

  # A dropdown to list categories. The current category is preselected.
  my PuzzleTable::Gui::DropDown $dropdown-cat .= new;
  $dropdown-cat.fill-categories(
    $select-category, $select-container, :skip-default
  );

  # Find the container of the current category and use it in the container
  # list to preselect it.
  with my PuzzleTable::Gui::DropDown $dropdown-cont .= new {
    .fill-containers($!config.get-current-container);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    .trap-container-changes( $dropdown-cat, :skip-default);
  }

  my Gnome::Gtk4::CheckButton $check-button .=
    new-with-label('Lock category');
  $check-button.set-active(False);

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :dialog-header('(Un)Lock Dialog')
  ) {
    .add-content( 'Select container', $dropdown-cont);
    .add-content( 'Category to (un)lock', $dropdown-cat);
    .add-content( '', $check-button);

    .add-button(
      self, 'do-category-lock', 'Lock / Unlock',
      :$dropdown-cat, :$dropdown-cont, :$dialog, :$check-button
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-category-lock (
  PuzzleTable::Gui::Dialog :$dialog, Gnome::Gtk4::CheckButton :$check-button,
  PuzzleTable::Gui::DropDown :$dropdown-cat,
  PuzzleTable::Gui::DropDown :$dropdown-cont
) {
  my Bool $sts-ok = False;

  $!config.set-category-lockable(
    $dropdown-cat.get-dropdown-text,
    $dropdown-cont.get-dropdown-text,
    $check-button.get-active.Bool
  );

  # Sidebar changes when a category is set lockable and table is locked
  $!sidebar.fill-sidebar if $!config.is-locked;
  $sts-ok = True;

  $dialog.destroy-dialog if $sts-ok;
}

