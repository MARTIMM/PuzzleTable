
use v6.d;

use PuzzleTable::Config;

use Gnome::Gtk4::DropDown:api<2>;
use Gnome::Gtk4::StringList:api<2>;
use Gnome::Gtk4::T-types:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::DropDown:auth<github:MARTIMM>;
also is Gnome::Gtk4::DropDown;

has PuzzleTable::Config $!config;
#has Gnome::Gtk4::StringList $!stringlist;

#-------------------------------------------------------------------------------
method new ( |c ) {
#note "$?LINE ", c.gist;
  self.new-dropdown(|c);
}

#-------------------------------------------------------------------------------
# Initialize from main page
submethod BUILD ( ) {
  $!config .= instance;

  # Initialize the dropdown object with an empty list
  my Gnome::Gtk4::StringList $stringlist .= new-stringlist([]);
  self.set-model($stringlist);
}

#-------------------------------------------------------------------------------
=begin pod
=head2 fill-categories

Fill a dropdown widget with a list of category names

  method fill-categories ( )

=end pod

method fill-categories (
  Bool :$skip-default = False, Str :$select-category, Str :$select-container
) {
#  my Gnome::Gtk4::StringList() $category-list;
  my Gnome::Gtk4::StringList() $stringlist .= new-stringlist([]);
  self.set-model($stringlist);

  my Str $category = $select-category // $!config.get-current-category;
  my Str $category-container =
     $select-container // $!config.find-container($category);

  my Int $index = 0;
  my Bool $index-found = False;
  for $!config.get-categories(
      :$category-container, :skip-containers
    ) -> $subcat
  {
    $index-found = True if $subcat eq $category;  #$select-category;
    $index++ unless $index-found;
    $stringlist.append($subcat);
  }

  $index = 0 unless $index-found;
  self.set-selected($index);
}

#-------------------------------------------------------------------------------
method fill-containers (
  Bool :$no-empty = False, Str :$select-container = ''
) {
  my Gnome::Gtk4::StringList() $stringlist = self.get-model;
  my Int $index = 0;
  my Bool $index-found = False;

  # Add an entry to be able to select a category at toplevel
  unless $no-empty {
    $stringlist.append('--');
    $index-found = True unless ?$select-container;
    $index++ unless $index-found;
  }

  # Add the container strings
  for $!config.get-containers -> $container {
    $stringlist.append($container);
    $index-found = True if $container eq $select-container;
    $index++ unless $index-found;
  }

  self.set-selected($index);
}

#-------------------------------------------------------------------------------
method get-dropdown-text ( --> Str ) {
  my Gnome::Gtk4::StringList() $stringlist;
  my UInt $p;

  $stringlist = self.get-model;
  $p = self.get-selected;

  my Str $s = '';
  $s = $stringlist.get-string($p) unless $p == GTK_INVALID_LIST_POSITION;

  $s
}

#-------------------------------------------------------------------------------
# Only a container drop down list can call this
method trap-container-changes (
  PuzzleTable::Gui::DropDown $categories, Bool $skip-default = False
) {
  state $containers = self;
  self.register-signal(
    self, 'select-categories', 'notify::selected',
    :$containers, :$categories, :$skip-default
  );

  my Str $select-container = self.get-dropdown-text;
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

#TODO somehow there is an empty stringlist when using _native-object named argument
method select-categories (
  N-Object $, # PuzzleTable::Gui::DropDown() :_native-object($containers),
  PuzzleTable::Gui::DropDown :$categories, Bool :$skip-default,
  PuzzleTable::Gui::DropDown :$containers
) {

  my Str $select-container = $containers.get-dropdown-text;
  $select-container = '' if $select-container eq '--';

  $categories.fill-categories(
    :$skip-default, :$select-container
  );

#exit;
}

