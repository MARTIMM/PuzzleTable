
use v6.d;
use NativeCall;

use GnomeTools::Gio::Menu;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::Container;
use PuzzleTable::Gui::Category;
use PuzzleTable::Gui::Puzzle;
#use PuzzleTable::Gui::Sidebar;
use PuzzleTable::Gui::Settings;
use PuzzleTable::Gui::IconButton;
use PuzzleTable::Gui::Help;
use PuzzleTable::Gui::IconButton;

#use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::MenuBar:auth<github:MARTIMM>;

has PuzzleTable::Gui::Puzzle $!phandling;
has PuzzleTable::Gui::Category $!cat;
has PuzzleTable::Gui::Container $!cont;
has PuzzleTable::Gui::Settings $!set;
has PuzzleTable::Gui::Help $!help;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!phandling .= new;
  $!set .= new;
  $!help .= new;
  $!cat .= new;
  $!cont .= new;

}

#-------------------------------------------------------------------------------
method make-menu ( --> GnomeTools::Gio::Menu ) {
  my GnomeTools::Gio::Menu $bar .= new;

  my GnomeTools::Gio::Menu $file-menu .= new( :parent-menu($bar), :name<File>);
  my Str $actionname = $file-menu.item( 'Quit', self, 'file-quit');
  self.set-toolbar-icon(
    :icon<application-exit>, :tooltip('Quit application'), :$actionname
  );

  my GnomeTools::Gio::Menu $container-menu .= new(
    :parent-menu($bar), :name<Container>, :$actionname
  );
  $actionname = $container-menu.item( 'Add', $!cont, 'container-add');
  self.set-toolbar-icon(
    :path(DATA_DIR ~ 'images/add-cont-64.png'),
    :tooltip('Add a container'), :$actionname
  );
  $container-menu.item( 'Rename', $!cont, 'container-rename');
  $container-menu.item( 'Delete', $!cont, 'container-delete');

  my GnomeTools::Gio::Menu $category-menu .= new(
    :parent-menu($bar), :name<Category>
  );
  $actionname = $category-menu.item( 'Add', $!cat, 'category-add');
  self.set-toolbar-icon(
    :path(DATA_DIR ~ 'images/add-cat-64.png'),
    :tooltip('Add a new category'), :$actionname
  );
  $actionname = $category-menu.item( 'Rename', $!cat, 'category-rename');
  self.set-toolbar-icon(
    :path(DATA_DIR ~ 'images/ren-cat-64.png'),
    :tooltip('Rename a category'), :$actionname
  );
  $category-menu.item( 'Delete', $!cat, 'category-delete');
  $category-menu.item( 'Lock', $!cat, 'category-lock');

  my GnomeTools::Gio::Menu $puzzle-menu .= new(
    :parent-menu($bar), :name<Puzzle>
  );
  $actionname = $puzzle-menu.item( 'Move', $!phandling, 'puzzle-move');
  self.set-toolbar-icon(
    :path(DATA_DIR ~ 'images/move-64.png'),
    :tooltip('Move puzzles'), :$actionname
  );
  $actionname = $puzzle-menu.item( 'Archive', $!phandling, 'puzzle-archive');
  self.set-toolbar-icon(
    :path(DATA_DIR ~ 'images/archive-64.png'),
    :tooltip('Archive puzzles'), :$actionname
  );

  my GnomeTools::Gio::Menu $settings-menu .= new(
    :parent-menu($bar), :name<Settings>
  );
  $settings-menu.item( 'Set Password', $!set, 'settings-set-password');
  $settings-menu.item(
    'Unlock Categories', $!set, 'settings-unlock-categories'
  );
  $settings-menu.item( 'Lock Categories', $!set, 'settings-lock-categories');

  my GnomeTools::Gio::Menu $help-menu .= new( :parent-menu($bar), :name<Help>);
  $actionname = $help-menu.item( 'About', $!help, 'help-about');
  self.set-toolbar-icon(
    :icon<help-about>, :tooltip('About info'), :$actionname
  );
  $help-menu.item(
    'Show Shortcuts Window', $!help, 'help-show-shortcuts-window'
  );

  $bar
}

#-------------------------------------------------------------------------------
method set-toolbar-icon (
  Str :$icon, Str :$path, Str :$tooltip, Str :$actionname
) {

  if ?$icon and ?$actionname {
note "$?LINE $icon, $actionname";
    my PuzzleTable::Gui::IconButton $toolbar-button .= new-button(
      :$icon, :$actionname
    );

    $toolbar-button.set-tooltip-text($tooltip) if ?$tooltip;

    $*main-window.toolbar.append($toolbar-button);
  }

  elsif ?$path and ?$actionname {
note "$?LINE $path, $actionname";
    my PuzzleTable::Gui::IconButton $toolbar-button .= new-button(
      :$path, :$actionname
    );

    $toolbar-button.set-tooltip-text($tooltip) if ?$tooltip;

    $*main-window.toolbar.append($toolbar-button);
  }
}

#-------------------------------------------------------------------------------
method file-quit ( N-Object $parameter ) {
  say 'file quit';
  $*main-window.application.quit;
}

=finish

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::Container;
use PuzzleTable::Gui::Category;
use PuzzleTable::Gui::Puzzle;
#use PuzzleTable::Gui::Sidebar;
use PuzzleTable::Gui::Settings;
use PuzzleTable::Gui::IconButton;
use PuzzleTable::Gui::Help;

#use Gnome::Glib::N-VariantType:api<2>;

use Gnome::Gio::Menu:api<2>;
use Gnome::Gio::MenuItem:api<2>;
use Gnome::Gio::SimpleAction:api<2>;

use Gnome::Gtk4::Button:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::MenuBar:auth<github:MARTIMM>;

has Gnome::Gio::Menu $.bar;

has Array $!menus;
has PuzzleTable::Gui::Puzzle $!phandling;
has PuzzleTable::Gui::Category $!cat;
has PuzzleTable::Gui::Container $!cont;
has PuzzleTable::Gui::Settings $!set;
has PuzzleTable::Gui::Help $!help;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!phandling .= new;
  $!set .= new;
  $!help .= new;
  $!cat .= new;
  $!cont .= new;

  $!bar .= new-menu;
  $!menus = [
    self.make-menu(:menu-name<File>, :shortcut),
    self.make-menu(:menu-name<Container>),
    self.make-menu(:menu-name<Category>),
    self.make-menu(:menu-name<Puzzle>),
    self.make-menu(:menu-name<Settings>),
    self.make-menu(:menu-name<Help>),
  ];
}

#-------------------------------------------------------------------------------
method make-menu (
  Str :$menu-name, Bool :$shortcut = False --> Gnome::Gio::Menu
) {
  my Gnome::Gio::Menu $menu .= new-menu;
  $!bar.append-submenu( $shortcut ?? "_$menu-name" !! "$menu-name", $menu);

  with $menu-name {
    when 'File' {
      self.bind-action(
        $menu, $menu-name, $!cat, 'Refresh Sidebar',
        :icon<view-refresh>, :tooltip('Refresh sidebar')
      );
      self.bind-action(
        $menu, $menu-name, self, 'Quit'
#        , :icon<application-exit>,
#        :tooltip('Quit application')
      );
    }

    when 'Container' {
      self.bind-action(
        $menu, $menu-name, $!cont, 'Add',
        :path(DATA_DIR ~ 'images/add-cont-64.png'),
        :tooltip('Add a container')
      );
      self.bind-action( $menu, $menu-name, $!cont, 'Rename');
#      self.bind-action( $menu, $menu-name, $!cont, 'Move');
      self.bind-action( $menu, $menu-name, $!cont, 'Delete');
    }

    when 'Category' {
      self.bind-action(
        $menu, $menu-name, $!cat, '_Add',
        :path(DATA_DIR ~ 'images/add-cat-64.png'),
        :tooltip('Add a new category'),
      );
      self.bind-action(
        $menu, $menu-name, $!cat, '_Rename',
        :path(DATA_DIR ~ 'images/ren-cat-64.png'), :tooltip('Rename a category')
      );
      self.bind-action( $menu, $menu-name, $!cat, 'Delete');
      self.bind-action( $menu, $menu-name, $!cat, 'Lock');
    }

    when 'Puzzle' {
      self.bind-action(
        $menu, $menu-name, $!phandling, 'Move',
        :path(DATA_DIR ~ 'images/move-64.png'), :tooltip('Move puzzles')
      );
      self.bind-action(
        $menu, $menu-name, $!phandling, 'Archive',
        :path(DATA_DIR ~ 'images/archive-64.png'), :tooltip('Archive puzzles')
      );
    }

    when 'Settings' {
      self.bind-action( $menu, $menu-name, $!set, 'Set Password');
      self.bind-action(
        $menu, $menu-name, $!set, 'Unlock Categories',
#        :shortcut
#        :icon<changes-allow>, :tooltip('Unlock locked categories')
      );
      self.bind-action(
        $menu, $menu-name, $!set, 'Lock Categories',
      );
    }

    when 'Help' {
      self.bind-action( $menu, $menu-name, $!help, 'About',
        :icon<help-about>, :tooltip('About Info')
      );
      self.bind-action( $menu, $menu-name, $!help, 'Show Shortcuts Window');
    }
  }

  $menu
}

#-------------------------------------------------------------------------------
method bind-action (
  Gnome::Gio::Menu $menu, Str $menu-name, Mu $object, Str $entry-name,
  Str :$icon, Str :$path, Str :$tooltip #, Bool :$shortcut = False
) {
  my PuzzleTable::Config $config .= instance;

  # Make a method and action name
  my Str $method = [~] $menu-name, ' ', $entry-name;
  $method .= lc;
  $method ~~ s/ \s '_' / /; # remove optional _ given by entry-name
  $method ~~ s:g/ \s+ /-/;

  my Str $action-name = 'app.' ~ $method;
note "$?LINE $menu-name, '$entry-name', $method, $action-name";

  # Make a menu entry
#  my Gnome::Gio::MenuItem $menu-item .= new-menuitem(
#    $shortcut ?? "_$entry-name" !! $entry-name, $action-name
#  );
  my Gnome::Gio::MenuItem $menu-item .= new-menuitem(
    $entry-name, $action-name
  );
  $menu.append-item($menu-item);

  # Use the method name
  my Gnome::Gio::SimpleAction $action .= new-simpleaction( $method, Pointer);
  $*main-window.add-action($action);
  $action.register-signal( $object, $method, 'activate');

  if ?$icon {
    my PuzzleTable::Gui::IconButton $toolbar-button .= new-button(
      :$icon, :$action-name
    );

    $toolbar-button.set-tooltip-text($tooltip) if ?$tooltip;

    $*main-window.toolbar.append($toolbar-button);
  }

  elsif ?$path {
    my PuzzleTable::Gui::IconButton $toolbar-button .= new-button(
      :$path, :$action-name
    );

    $toolbar-button.set-tooltip-text($tooltip) if ?$tooltip;

    $*main-window.toolbar.append($toolbar-button);
  }
}

#-------------------------------------------------------------------------------
method file-quit ( N-Object $parameter ) {
  say 'file quit';
  $*main-window.quit;
}
