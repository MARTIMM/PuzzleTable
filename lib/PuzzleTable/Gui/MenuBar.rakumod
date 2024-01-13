
use v6.d;
use NativeCall;

use PuzzleTable::Config;
use PuzzleTable::Gui::Category;
use PuzzleTable::Gui::Settings;

#use Gnome::Glib::N-VariantType:api<2>;

use Gnome::Gio::Menu:api<2>;
use Gnome::Gio::MenuItem:api<2>;
use Gnome::Gio::SimpleAction:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::MenuBar:auth<github:MARTIMM>;

has Gnome::Gio::Menu $.bar;
has $!application is required;
has $!main is required;

has Array $!menus;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!application = $!main.application;

  $!bar .= new-menu;
  $!menus = [
    self.make-menu(:menu-name<File>),
    self.make-menu(:menu-name<Category>),
    self.make-menu(:menu-name<Settings>),
    self.make-menu(:menu-name<Help>),
  ];
}

#-------------------------------------------------------------------------------
method make-menu ( Str :$menu-name --> Gnome::Gio::Menu ) {
  my Gnome::Gio::Menu $menu .= new-menu;
  $!bar.append-submenu( $menu-name, $menu);

  my PuzzleTable::Config $config = $!main.config;
  my PuzzleTable::Gui::Category $cat = $!main.category;
  my PuzzleTable::Gui::Settings $set .= new(:$!main);

  with $menu-name {
    when 'File' {
      self.bind-action( $menu, $menu-name, self, 'Quit', 'app.quit');
    }

    when 'Category' {
      self.bind-action( $menu, $menu-name, $cat, 'Add', 'app.add');
      self.bind-action( $menu, $menu-name, $cat, 'Rename', 'app.rename');
      self.bind-action( $menu, $menu-name, $cat, 'Remove', 'app.remove');
    }

    when 'Settings' {
      self.bind-action(
        $menu, $menu-name, $set, 'Set Password', 'app.set-password'
      );

      self.bind-action(
        $menu, $menu-name, $set, 'Unlock Categories', 'app.unlock-categories'
      );

      self.bind-action(
        $menu, $menu-name, $set, 'Lock Categories', 'app.lock-categories'
      );
    }

    when 'Help' {
      self.bind-action( $menu, $menu-name, self, 'About', 'app.about');
#      self.bind-action( $menu, $menu-name, self, '', '');
    }
  }

  $menu
}

#-------------------------------------------------------------------------------
method bind-action (
  Gnome::Gio::Menu $menu, Str $menu-name, Mu $object,
  Str $name is copy, Str $action-name
) {
  my Gnome::Gio::MenuItem $menu-item .= new-menuitem( $name, $action-name);
  $menu.append-item($menu-item);

  $name ~~ s:g/ \s+ /-/;
  my Gnome::Gio::SimpleAction $action .=
    new-simpleaction( $name.lc, Pointer);
  $!application.add-action($action);

  my Str $method = [~] $menu-name.lc, '-', $name.lc;
#note "$?LINE $menu-name, $name, $action-name, $method";
  $action.register-signal( $object, $method, 'activate');
}

#-------------------------------------------------------------------------------
method file-quit ( N-Object $parameter ) {
  say 'file quit';
  $!application.quit;
}

#-------------------------------------------------------------------------------
method help-about ( N-Object $parameter ) {
  say 'help about';
}

