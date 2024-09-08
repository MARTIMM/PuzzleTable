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
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::DropDown:api<2>;
use Gnome::Gtk4::StringList:api<2>;

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
  my Str $container = $entry.get-text.tc;
  if ! $container {
    $dialog.set-status('No category name specified');
  }

  elsif not $!config.add-container($container) {
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
    my Gnome::Gtk4::DropDown() $dropdown = $!sidebar.fill-containers(:no-enpty);

    # Show entry for input
    .add-content( 'Select container to delete', $dropdown);

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
  my Str $container = $dropdown.get-dropdown-text;
  
  if not $!config.delete-container($container) {
    $dialog.set-status("Container $container not empty");
  }

  else {
    $!sidebar.fill-sidebar;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

