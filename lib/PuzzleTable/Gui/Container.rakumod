#`{{
Combobox widget to display the categories of puzzles. The widget is shown on
the main window. The actions to change the list are triggered from the
'category' menu. All changes are directly visible in the combobox on the main
page.
}}

use v6.d;

use PuzzleTable::Config;
use PuzzleTable::Gui::Dialog;
use PuzzleTable::Gui::DropDown;

use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
#use Gnome::Gtk4::DropDown:api<2>;
#use Gnome::Gtk4::StringList:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Container:auth<github:MARTIMM>;

has $!main is required;
has $!sidebar;
has PuzzleTable::Config $!config;

#-------------------------------------------------------------------------------
# Initialize from main page
submethod BUILD ( :$!main ) {
  $!config .= instance;
  $!sidebar = $!main.sidebar;
}

#-------------------------------------------------------------------------------
method container-add ( N-Object $parameter ) {

  with my PuzzleTable::Gui::Dialog $dialog .= new(
   :dialog-header('Add container Dialog')
  ) {
    my PuzzleTable::Gui::DropDown $roots-dd;
    if $*multiple-roots {
      $roots-dd .= new;
      $roots-dd.fill-roots($!config.get-current-root);

      # Show dropdown
      .add-content( 'Select a root', $roots-dd);
   }

    # Show entry for input
    .add-content(
      'Specify a new container', my Gnome::Gtk4::Entry $entry .= new-entry
    );

    # Buttons to add the container or cancel
    .add-button(
      self, 'do-container-add', 'Add', :$entry, :$dialog, :$roots-dd
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-container-add (
  PuzzleTable::Gui::Dialog :$dialog, Gnome::Gtk4::Entry :$entry,
  PuzzleTable::Gui::DropDown :$roots-dd
) {
  my Bool $sts-ok = False;
  my Str $root-dir;
  if $*multiple-roots {
    $root-dir = $roots-dd.get-dropdown-text;
  }

  my Str $container = $entry.get-text.lc.tc;
  if ! $container {
    $dialog.set-status('No category name specified');
  }

  elsif not $!config.add-container( $container, :$root-dir) {
    $dialog.set-status('Container already exists');
  }

  else {
    $!sidebar.fill-sidebar;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method container-delete ( N-Object $parameter ) {

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :dialog-header('Delete Container Dialog')
  ) {
    # Make a string list to be used in a combobox (dropdown)
    my PuzzleTable::Gui::DropDown $container-dd .= new;
    $container-dd.fill-containers(
      $!config.get-current-container, :skip-default
    );

    my PuzzleTable::Gui::DropDown $roots-dd;
    if $*multiple-roots {
      $roots-dd .= new;
      $roots-dd.fill-roots($!config.get-current-root);

      # Show dropdown
      .add-content( 'Select a root', $roots-dd);

      # Set a handler on the container list to change the category list
      # when an item is selected.
      $roots-dd.trap-root-changes( $container-dd, :skip-default);
    }

    # Show entry for input
    .add-content( 'Select container to delete', $container-dd);

    # Buttons to delete the container or cancel
    .add-button(
      self, 'do-container-delete', 'Delete',
      :$dialog, :$container-dd, :$roots-dd
    );
    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-container-delete (
  PuzzleTable::Gui::Dialog :$dialog,
  Gnome::Gtk4::DropDown :$container-dd, Gnome::Gtk4::DropDown :$roots-dd
) {
  my Bool $sts-ok = False;
  my Str $root-dir;
  if $*multiple-roots {
    $root-dir = $roots-dd.get-dropdown-text;
  }

  my Str $container = $container-dd.get-dropdown-text;
  
  if not $!config.delete-container( $container, :$root-dir) {
    $dialog.set-status("Container $container not empty");
  }

  else {
    $!sidebar.fill-sidebar;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

