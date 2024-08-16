=begin pod
Combobox widget to display the categories of puzzles. The widget is shown on
the main window. The actions to change the list are triggered from the
'category' menu. All changes are directly visible in the combobox on the main
page.
=end pod

use v6.d;

use PuzzleTable::Config;
use PuzzleTable::Gui::Dialog;

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
use Gnome::Gtk4::DropDown:api<2>;
use Gnome::Gtk4::StringList:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
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
  $!config = $!main.config;
  $!sidebar = $!main.sidebar;
}

#-------------------------------------------------------------------------------
# Select from menu to add a category
method category-add ( N-Object $parameter ) {

  my Str $ccat = $!config.get-current-category;
  my Str $select-container = $!config.find-container($ccat);

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Add Category Dialog')
  ) {
    # Make a string list to be used in a combobox (dropdown)
    my Gnome::Gtk4::DropDown() $dropdown = $!sidebar.fill-containers(
        :$select-container
    );

    # Show dropdown
    .add-content( 'Select a container', $dropdown);

    # Show entry for input
    my Gnome::Gtk4::Entry $entry .= new-entry;
    $entry.set-text($ccat);
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
    my Str $category-container = $!sidebar.get-dropdown-text($dropdown);
    $category-container = '' if $category-container eq '--';

    # Add category to list. Message gets defined if something is wrong.
    my Str $msg = $!main.config.add-category(
      $cat-text, :lockable($check-button.get-active), :$category-container
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

Select from menu to rename a category. There are two drop down lists, one of a list of containers and the other to list categories. The category list is the list of categories found in a container and changes when another container is selected.

  .category-rename ( N-Object $parameter )

=item $parameter; Data given by the menu action. It is not set so it can be ignored

=end pod

method category-rename ( N-Object $parameter ) {

  my Str $ccat = $!config.get-current-category;

  # Prepare dialog entries.
  # An entry to change the name of the selected category, prefilled with
  # the current one.
  my Gnome::Gtk4::Entry $entry .= new-entry;
  $entry.set-text($ccat);

  # A dropdown to list categories. The current category is preselected.
  my Gnome::Gtk4::DropDown $dropdown-cat =
     $!sidebar.fill-categories( :skip-default, :select-category($ccat));

  # Find the container of the current category and use it in the container
  # list to preselect it.
  my Str $select-container = $!config.find-container($ccat);
  my Gnome::Gtk4::DropDown $dropdown-cont =
     $!sidebar.fill-containers(:$select-container);

  # Set a handler on the container list to change the category list
  # when an item is selected.
  $dropdown-cont.register-signal(
    self, 'select-categories', 'notify',
    :categories($dropdown-cat), :skip-default
  );

  # Build the dialog
  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Rename Category dialog')
  ) {
    .add-content( 'Select container', $dropdown-cont);
    .add-content( 'Specify the category to rename', $dropdown-cat);
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
  my Str $old-category = $!sidebar.get-dropdown-text($dropdown-cat);
  my Str $new-category = $entry.get-text.tc;
  my Str $container = $!sidebar.get-dropdown-text($dropdown-cont);
  $container = '' if $container eq '--';

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
      $old-category, $new-category.tc, :category-container($container)
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

  my Str $ccat = $!config.get-current-category;

  # Prepare dialog entries.
  # A dropdown to list categories. The current category is preselected.
  my Gnome::Gtk4::DropDown $dropdown-cat = $!sidebar.fill-categories(
    :skip-default, :select-category($ccat)
  );

  # Find the container of the current category and use it in the container
  # list to preselect it.
  my Str $select-container = $!config.find-container($ccat);
  my Gnome::Gtk4::DropDown $dropdown-cont =
     $!sidebar.fill-containers(:$select-container);

  # Set a handler on the container list to change the category list
  # when an item is selected.
  $dropdown-cont.register-signal(
    self, 'select-categories', 'notify',
    :categories($dropdown-cat), :skip-default
  );

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Rename Category dialog')
  ) {
    .add-content( 'Select container', $dropdown-cont);
    .add-content( 'Select category to delete', $dropdown-cat);

    .add-button(
      self, 'do-category-delete', 'Delete', :$dropdown-cat, :$dialog
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-category-delete (
  PuzzleTable::Gui::Dialog :$dialog, Gnome::Gtk4::DropDown :$dropdown
) {
  my Bool $sts-ok = False;
  my Str $category = $!sidebar.get-dropdown-text($dropdown);
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
note "$?LINE lock, ", self;
  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('(Un)Lock Dialog')
  ) {
    my Gnome::Gtk4::CheckButton $check-button .=
      new-with-label('Lock category');
    $check-button.set-active(False);

    my Gnome::Gtk4::DropDown $dropdown = $!sidebar.fill-categories(
      :skip-default, :select-category($!config.get-current-category)
    );

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
  my Str $category-name = $!sidebar.get-dropdown-text($dropdown);

  $!config.set-category-lockable(
    $category-name, $!config.find-container($category-name),
    $check-button.get-active.Bool
  );

  # Sidebar changes when a category is set lockable and table is locked
  $!sidebar.fill-sidebar if $!config.is-locked;
  $sts-ok = True;

note "$?LINE $!sidebar.get-dropdown-text($dropdown), $check-button.get-active.Bool(), $!config.is-locked(), $sts-ok";

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
=begin pod
=head2 select-categories

Handler for the container dropdown list to change the category dropdown list after a selecteion is made.

  method select-categories (
    N-Object $, Gnome::Gtk4::DropDown() :_native-object($containers),
    Gnome::Gtk4::DropDown() :$categories, Bool :$skip-default
  )

=item $ ; A ParamSpec object. It is ignored.
=item $containers: The container list.
=item $categories: The category list.
=item $skip-default; Used to hide the 'Default' category from the list.

=end pod

method select-categories (
  N-Object $, Gnome::Gtk4::DropDown() :_native-object($containers),
  Gnome::Gtk4::DropDown() :$categories, Bool :$skip-default
) {
  my Gnome::Gtk4::StringList() $string-list .= new-stringlist([]);
  $categories.set-model($string-list);

  my Str $container = $!sidebar.get-dropdown-text($containers);
  $container = '' if $container eq '--';
  $!sidebar.fill-categories(
    :$skip-default, :dropdown($categories), :select-container($container)
  );
}

