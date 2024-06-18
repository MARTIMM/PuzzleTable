
use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::PuzzleHandling;
use PuzzleTable::Gui::Sidebar;
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
has PuzzleTable::Gui::PuzzleHandling $!phandling;
has PuzzleTable::Gui::Sidebar $!cat;
has PuzzleTable::Gui::Settings $!set;
has PuzzleTable::Gui::Help $!help;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!application = $!main.application;
  $!cat = $!main.category;
  $!phandling .= new(:$!main);
  $!set .= new(:$!main);
  $!help .= new(:$!main);

  $!bar .= new-menu;
  $!menus = [
    self.make-menu(:menu-name<File>, :shortcut),
    self.make-menu(:menu-name<Categories>),
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
        $menu, $menu-name, self, 'Quit', 'app.quit', :icon<application-exit>,
        :tooltip('Quit application')
      );
    }

    when 'Categories' {
      self.bind-action(
        $menu, $menu-name, $!cat, 'Add Category', 'app.add-category',
        :path(DATA_DIR ~ 'images/add-cat.png'), :tooltip('Add a new category')
      );
      self.bind-action(
        $menu, $menu-name, $!cat, 'Add Container', 'app.add-container',
        :path(DATA_DIR ~ 'images/add-cont.png'), :tooltip('Add a new category container')
      );
      self.bind-action(
        $menu, $menu-name, $!cat, 'Lock Category', 'app.lock-category'
      );
      self.bind-action(
        $menu, $menu-name, $!cat, 'Rename Category', 'app.rename-category',
        :path(DATA_DIR ~ 'images/ren-cat.png'), :tooltip('Rename a category')
      );
      self.bind-action(
        $menu, $menu-name, $!cat, 'Remove Category', 'app.remove-category',
#        :path(DATA_DIR ~ 'images/rem-cat.png'), :tooltip('Remove a category')
      );
      self.bind-action(
        $menu, $menu-name, $!cat, 'Refresh Sidebar', 'app.refresh-sidebar',
        :icon<view-refresh>, :tooltip('Refresh sidebar')
      );
    }

    when 'Puzzles' {
      self.bind-action(
        $menu, $menu-name, $!phandling, 'Move Puzzles', 'app.move-puzzles',
        :path(DATA_DIR ~ 'images/move-64.png'), :tooltip('Move puzzles')
      );
      self.bind-action(
        $menu, $menu-name, $!phandling, 'Remove Puzzles', 'app.remove-puzzles',
        :path(DATA_DIR ~ 'images/archive-64.png'), :tooltip('Remove puzzles')
      );
    }

    when 'Settings' {
      self.bind-action(
        $menu, $menu-name, $!set, 'Set Password', 'app.set-password'
      );
      self.bind-action(
        $menu, $menu-name, $!set, 'Unlock Categories', 'app.unlock-categories', 
        :shortcut
#        :icon<changes-allow>, :tooltip('Unlock locked categories')
      );
      self.bind-action(
        $menu, $menu-name, $!set, 'Lock Categories', 'app.lock-categories', 
        :shortcut
      );
    }

    when 'Help' {
      self.bind-action( $menu, $menu-name, $!help, 'About', 'app.about',
        :icon<help-about>, :tooltip('About Info')
      );
      self.bind-action(
        $menu, $menu-name, $!help, 'Show Shortcuts Window',
        'app.show-shortcuts-window'
      );
#      self.bind-action( $menu, $menu-name, $!help, '', '');
    }
  }

  $menu
}

#-------------------------------------------------------------------------------
method bind-action (
  Gnome::Gio::Menu $menu, Str $menu-name, Mu $object,
  Str $name is copy, Str $action-name,
  Str :$icon, Str :$path, Str :$tooltip, Bool :$shortcut = False
) {
  my Gnome::Gio::MenuItem $menu-item .= new-menuitem(
    $shortcut ?? "_$name" !! $name, $action-name
  );
  $menu.append-item($menu-item);

  $name ~~ s:g/ \s+ /-/;
  my Gnome::Gio::SimpleAction $action .=
    new-simpleaction( $name.lc, Pointer);
  $!application.add-action($action);

  my Str $method = [~] $menu-name.lc, '-', $name.lc;
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
