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
#use Gnome::Gtk4::CheckButton:api<2>;
#use Gnome::Gtk4::Button:api<2>;
#use Gnome::Gtk4::Label:api<2>;
#use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Box:api<2>;
#use Gnome::Gtk4::Expander:api<2>;
#use Gnome::Gtk4::ComboBoxText:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::DropDown:api<2>;
use Gnome::Gtk4::StringList:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Container:auth<github:MARTIMM>;
#also is Gnome::Gtk4::ScrolledWindow;

has $!main is required;
has $!sidebar;
has PuzzleTable::Config $!config;

#-------------------------------------------------------------------------------
# Initialize from main page
submethod BUILD ( :$!main ) {
  $!config = $!main.config;
  $!sidebar = $!main.sidebar;

}

#-------------------------------------------------------------------------------
method container-add ( N-Object $parameter ) {

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
    $!sidebar.fill-sidebar;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method container-delete ( N-Object $parameter ) {

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
    $!sidebar.fill-sidebar;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

