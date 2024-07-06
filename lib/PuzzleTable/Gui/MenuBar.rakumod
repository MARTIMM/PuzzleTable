
use v6.d;
use NativeCall;

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
has $!application is required;
has $!main is required;

has Array $!menus;
has PuzzleTable::Gui::Puzzle $!phandling;
has PuzzleTable::Gui::Category $!cat;
has PuzzleTable::Gui::Container $!cont;
has PuzzleTable::Gui::Settings $!set;
has PuzzleTable::Gui::Help $!help;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!application = $!main.application;
  $!phandling .= new(:$!main);
  $!set .= new(:$!main);
  $!help .= new(:$!main);
  $!cat .= new(:$!main);
  $!cont .= new(:$!main);

  $!bar .= new-menu;
  $!menus = [
    self.make-menu(:menu-name<File>, :shortcut),
    self.make-menu(:menu-name<Container>),
    self.make-menu(:menu-name<Category>),
    self.make-menu(:menu-name<Puzzles>),
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

#  my PuzzleTable::Config $config = $!main.config;

  with $menu-name {
    when 'File' {
      self.bind-action(
        $menu, $menu-name, self, 'Quit', :icon<application-exit>,
        :tooltip('Quit application')
      );
    }

    when 'Container' {
      self.bind-action( $menu, $menu-name, $!cont, 'Add');
      self.bind-action( $menu, $menu-name, $!cont, 'Delete');
    }

    when 'Category' {
      self.bind-action(
        $menu, $menu-name, $!cat, 'Add',
        :path(DATA_DIR ~ 'images/add-cat.png'), :tooltip('Add a new category')
      );
      self.bind-action( $menu, $menu-name, $!cat, 'Delete');
      self.bind-action( $menu, $menu-name, $!cat, 'Lock');
      self.bind-action(
        $menu, $menu-name, $!cat, 'Rename',
        :path(DATA_DIR ~ 'images/ren-cat.png'), :tooltip('Rename a category')
      );
      self.bind-action(
        $menu, $menu-name, $!cat, 'Delete',
#        :path(DATA_DIR ~ 'images/rem-cat.png'), :tooltip('Remove a category')
      );
      self.bind-action(
        $menu, $menu-name, $!cat, 'Refresh Sidebar',
        :icon<view-refresh>, :tooltip('Refresh sidebar')
      );
    }

    when 'Puzzles' {
      self.bind-action(
        $menu, $menu-name, $!phandling, 'Move',
        :path(DATA_DIR ~ 'images/move-64.png'), :tooltip('Move puzzles')
      );
      self.bind-action(
        $menu, $menu-name, $!phandling, 'Remove',
#        :path(DATA_DIR ~ 'images/archive-64.png'), :tooltip('Remove puzzles')
      );
    }

    when 'Settings' {
      self.bind-action( $menu, $menu-name, $!set, 'Set Password');
      self.bind-action(
        $menu, $menu-name, $!set, 'Unlock Categories',
        :shortcut
#        :icon<changes-allow>, :tooltip('Unlock locked categories')
      );
      self.bind-action(
        $menu, $menu-name, $!set, 'Lock Categories',
        :shortcut
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
  Str :$icon, Str :$path, Str :$tooltip, Bool :$shortcut = False
) {
  # Make a method and action name
  my Str $method = [~] $menu-name, ' ', $entry-name;
  $method .= lc;
  $method ~~ s:g/ \s+ /-/;

  my Str $action-name = 'app.' ~ $method;
note "$?LINE $menu-name, '$entry-name', $method, $action-name";

  # Make a menu entry
  my Gnome::Gio::MenuItem $menu-item .= new-menuitem(
    $shortcut ?? "_$entry-name" !! $entry-name, $action-name
  );
  $menu.append-item($menu-item);

  # Use the method name
  my Gnome::Gio::SimpleAction $action .= new-simpleaction( $method, Pointer);
  $!application.add-action($action);
  $action.register-signal( $object, $method, 'activate');

  if ?$icon {
    my PuzzleTable::Gui::IconButton $toolbar-button .= new-button(
      :$icon, :$action-name, :config($!main.config)
    );

    $toolbar-button.set-tooltip-text($tooltip) if ?$tooltip;

    $!main.toolbar.append($toolbar-button);
  }

  elsif ?$path {
    my PuzzleTable::Gui::IconButton $toolbar-button .= new-button(
      :$path, :$action-name, :config($!main.config)
    );

    $toolbar-button.set-tooltip-text($tooltip) if ?$tooltip;

    $!main.toolbar.append($toolbar-button);
  }
}

#-------------------------------------------------------------------------------
method file-quit ( N-Object $parameter ) {
  say 'file quit';
  $!application.quit;
}
