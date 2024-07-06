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
      $!sidebar.fill-sidebar;
      $sts-ok = True;
    }
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
# Select from menu to lock or unlock a category
method category-lock ( N-Object $parameter ) {

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('(Un)Lock Dialog')
  ) {
    my Gnome::Gtk4::CheckButton $check-button .=
      new-with-label('Lock or unlock category');
    $check-button.set-active(False);

    my Gnome::Gtk4::DropDown $dropdown = self.fill-categories(:skip-default);

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
  $!sidebar.fill-sidebar
    if $check-button.get-active.Bool and $!config.is-locked;
  $sts-ok = True;

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
# Select from menu to rename a category
method category-rename ( N-Object $parameter ) {
#  say 'category rename';

  my Gnome::Gtk4::Entry $entry .= new-entry;
  my Gnome::Gtk4::DropDown $dropdown-cat = self.fill-categories(:skip-default);
  my Gnome::Gtk4::DropDown $dropdown-cont = self.fill-containers;

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Rename Category dialog')
  ) {
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
    $!sidebar.fill-sidebar;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#`{{
#-------------------------------------------------------------------------------
# Select from menu to remove a category
method category-remove-category ( N-Object $parameter ) {
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
