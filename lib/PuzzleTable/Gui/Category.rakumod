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
use Gnome::Gtk4::CheckButton:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

#use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Category:auth<github:MARTIMM>;

has $!main is required;
has PuzzleTable::Config $!config;
has $!sidebar;

#-------------------------------------------------------------------------------
# Initialize from main page
submethod BUILD ( :$!main ) {
  $!config .= instance;
  $!sidebar = $!main.sidebar;
}

#-------------------------------------------------------------------------------
# Select from menu to add a category
method category-add ( N-Object $parameter ) {

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :dialog-title('New Category'), :dialog-header(Q:to/EOCATD/)
        Create a new category. The category
        is placed in the selected container
        EOCATD
  ) {
    my $current-root = $!config.get-current-root;

    # Make a string list to be used in a combobox (dropdown)
    my PuzzleTable::Gui::DropDown $container-dd .= new;
    $container-dd.fill-containers(
      $!config.get-current-container, $current-root
    );

    my PuzzleTable::Gui::DropDown $roots-dd;
    if $*multiple-roots {
      $roots-dd .= new;
      $roots-dd.fill-roots($!config.get-current-root);

      # Show dropdown
      .add-content( 'Select a root', $roots-dd);

      # Set a handler on the container list to change the category list
      # when an item is selected.
      $roots-dd.trap-root-changes($container-dd);
    }

    # Show dropdown
    .add-content( 'Select a container', $container-dd);
    # Show entry for input
    my Gnome::Gtk4::Entry $entry .= new-entry;
    $entry.set-text($!config.get-current-category);
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
      :$dialog, :$container-dd, :$roots-dd
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-category-add (
  PuzzleTable::Gui::Dialog :$dialog,
  Gnome::Gtk4::Entry :$entry, Gnome::Gtk4::CheckButton :$check-button,
  PuzzleTable::Gui::DropDown :$container-dd,
  PuzzleTable::Gui::DropDown :$roots-dd
) {
  my Bool $sts-ok = False;
  my Str $category = $entry.get-text;

  if !$category {
    $dialog.set-status('No category name specified');
  }

  elsif $category.lc eq 'default' {
    $dialog.set-status('Category \'default\' already exists');
  }

  else {
    my Str $root-dir;
    if $*multiple-roots {
      $root-dir = $roots-dd.get-dropdown-text;
    }

    my Str $container = $container-dd.get-dropdown-text;

    # Add category to list. Message gets defined if something is wrong.
    my Str $msg = $!config.add-category(
      $category, $container, :lockable($check-button.get-active), :$root-dir
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
  my Str $select-root-dir = $!config.get-current-root;

  # Prepare dialog entries.
  # An entry to change the name of the selected category, prefilled with
  # the current one.
  my Gnome::Gtk4::Entry $new-cat-entry .= new-entry;
  $new-cat-entry.set-text($select-category);

  # A dropdown to list categories. The current category is preselected.
  my PuzzleTable::Gui::DropDown $old-category-dd .= new;
  $old-category-dd.fill-categories(
    $select-category, $select-container, $select-root-dir, :skip-default
  );

  # A dropdown to list containers. The current container is preselected.
  with my PuzzleTable::Gui::DropDown $old-container-dd .= new {
    .fill-containers( $select-container, $select-root-dir);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    .trap-container-changes( $old-category-dd, :skip-default);
  }

  # A dropdown to list containers. The current container is preselected.
  with my PuzzleTable::Gui::DropDown $new-container-dd .= new {
    .fill-containers( $select-container, $select-root-dir);

    # Set a handler on the container list to change the category list
    # when an item is selected.
#    .trap-container-changes( $old-category-dd, :skip-default);
  }

  my PuzzleTable::Gui::DropDown ( $old-roots-dd, $new-roots-dd);
  if $*multiple-roots {
    $old-roots-dd .= new;
    $old-roots-dd.fill-roots($!config.get-current-root);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    $old-roots-dd.trap-root-changes($old-container-dd);

    $new-roots-dd .= new;
    $new-roots-dd.fill-roots($!config.get-current-root);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    $new-roots-dd.trap-root-changes($new-container-dd);
  }

  # Build the dialog
  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :dialog-header('Rename Category dialog')
  ) {
    .add-content( 'Select the root where old container is', $old-roots-dd)
      if $*multiple-roots;
    .add-content( 'Select container where old category is', $old-container-dd);
    .add-content( 'Specify the category to move', $old-category-dd);

    .add-content( 'Select the root where new container is', $new-roots-dd)
      if $*multiple-roots;
    .add-content( 'Select container to move category to', $new-container-dd);
    .add-content( 'New category name', $new-cat-entry);

    .add-button(
      self, 'do-category-rename', 'Rename',
      :$old-category-dd, :$old-container-dd, :$old-roots-dd,
      :$new-cat-entry, :$new-container-dd, :$new-roots-dd,
      :$dialog
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-category-rename (
  PuzzleTable::Gui::Dialog :$dialog,
  PuzzleTable::Gui::DropDown :$old-category-dd,
  PuzzleTable::Gui::DropDown :$old-container-dd,
  PuzzleTable::Gui::DropDown :$old-roots-dd,
  PuzzleTable::Gui::DropDown :$new-container-dd,
  PuzzleTable::Gui::DropDown :$new-roots-dd,
  Gnome::Gtk4::Entry :$new-cat-entry,
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
    my Str $oroot = $*multiple-roots
                      ?? $old-roots-dd.get-dropdown-text
                      !! $!config.get-current-root;
    my Str $nroot = $*multiple-roots
                      ?? $new-roots-dd.get-dropdown-text
                      !! $!config.get-current-root;
    my Str $message = $!config.move-category(
      my Str $ocat = $old-category-dd.get-dropdown-text,
      my Str $ocont = $old-container-dd.get-dropdown-text,
      $oroot,
      $new-category,
      my Str $ncont = $new-container-dd.get-dropdown-text,
      $nroot
    );

    if $message {
      $dialog.set-status($message);
    }

    else {
      $!sidebar.fill-sidebar;
#      if $ocat eq $!config.get-current-category and
#         $ocont eq $!config.get-current-container
#      {
        $!sidebar.select-category(
          :category($new-category), :container($ncont), :root-dir($nroot)
        );
#      }

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
  my Str $select-root = $!config.get-current-root;

  # Prepare dialog entries.
  # A dropdown to list categories. The current category is preselected.
  my PuzzleTable::Gui::DropDown $category-dd .= new;
  $category-dd.fill-categories(
    $select-category, $select-container, $select-root, :skip-default
  );

  # Find the container of the current category and use it in the container
  # list to preselect it.
  with my PuzzleTable::Gui::DropDown $container-dd .= new {
    .fill-containers( $!config.get-current-container, $select-root);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    .trap-container-changes( $category-dd, :skip-default);
  }

  my PuzzleTable::Gui::DropDown $roots-dd;
  if $*multiple-roots {
    $roots-dd .= new;
    $roots-dd.fill-roots($select-root);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    $roots-dd.trap-root-changes($container-dd, :categories($category-dd));
  }

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :dialog-header('Rename Category dialog')
  ) {
    .add-content( 'Select a root', $roots-dd) if $*multiple-roots;
    .add-content( 'Select container', $container-dd);
    .add-content( 'Select category to delete', $category-dd);

    .add-button(
      self, 'do-category-delete', 'Delete',
      :$category-dd, :$container-dd, :$dialog, :$roots-dd
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-category-delete (
  PuzzleTable::Gui::Dialog :$dialog,
  PuzzleTable::Gui::DropDown :$category-dd,
  PuzzleTable::Gui::DropDown :$container-dd,
  PuzzleTable::Gui::DropDown :$roots-dd
) {
  my Bool $sts-ok = False;
  my Str $category = $category-dd.get-dropdown-text;
  my Str $container = $container-dd.get-dropdown-text;

  my Str $root-dir = $*multiple-roots
          ?? $roots-dd.get-dropdown-text
          !! $!config.get-current-root;

  if $!config.has-puzzles( $category, $container, $root-dir) {
    $dialog.set-status('Category still has puzzles');
  }

  else {
    my Str $message = $!config.delete-category(
      $category, $container, $root-dir
    );

    if ?$message {
      $dialog.set-status($message);
    }

    else {

      if $category eq $!config.get-current-category and
         $container eq $!config.get-current-container
      {
        $!sidebar.select-category(
          :category('Default'), :container('Default'), :$root-dir
        );
      }
      $!sidebar.fill-sidebar;
      $sts-ok = True;
    }
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
# Select from menu to lock or unlock a category
method category-lock ( N-Object $parameter ) {

  my Str $select-category = $!config.get-current-category;
  my Str $select-container = $!config.get-current-container;
  my Str $select-root = $!config.get-current-root;

  # A dropdown to list categories. The current category is preselected.
  my PuzzleTable::Gui::DropDown $category-dd .= new;
  $category-dd.fill-categories(
    $select-category, $select-container, $select-root, :skip-default
  );

  # Find the container of the current category and use it in the container
  # list to preselect it.
  with my PuzzleTable::Gui::DropDown $container-dd .= new {
    .fill-containers( $!config.get-current-container, $select-root);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    .trap-container-changes( $category-dd, :skip-default);
  }

  my PuzzleTable::Gui::DropDown $roots-dd;
  if $*multiple-roots {
    $roots-dd .= new;
    $roots-dd.fill-roots($select-root);

    # Set a handler on the container list to change the category list
    # when an item is selected.
    $roots-dd.trap-root-changes( $container-dd, :categories($category-dd));
  }

  my Gnome::Gtk4::CheckButton $check-button .= new-with-label('Lock category');
  $check-button.set-active(False);

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :dialog-header('(Un)Lock Dialog')
  ) {
    .add-content( 'Select a root', $roots-dd) if $*multiple-roots;
    .add-content( 'Select container', $container-dd);
    .add-content( 'Category to (un)lock', $category-dd);
    .add-content( '', $check-button);

    .add-button(
      self, 'do-category-lock', 'Lock / Unlock',
      :$category-dd, :$container-dd, :$roots-dd, :$dialog, :$check-button
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-category-lock (
  PuzzleTable::Gui::Dialog :$dialog, Gnome::Gtk4::CheckButton :$check-button,
  PuzzleTable::Gui::DropDown :$category-dd,
  PuzzleTable::Gui::DropDown :$container-dd,
  PuzzleTable::Gui::DropDown :$roots-dd
) {
  my Bool $sts-ok = False;

  $!config.set-category-lockable(
    $category-dd.get-dropdown-text,
    $container-dd.get-dropdown-text,
    ( $*multiple-roots
      ?? $roots-dd.get-dropdown-text
      !! $!config.get-current-root
    ),
    $check-button.get-active.Bool
  );

  # Sidebar changes when a category is set lockable and table is locked
  $!sidebar.fill-sidebar if $!config.is-locked;
  $sts-ok = True;

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method file-refresh-sidebar ( N-Object $parameter ) {
note "$?LINE";
  $!sidebar.fill-sidebar(:recalculate);
}