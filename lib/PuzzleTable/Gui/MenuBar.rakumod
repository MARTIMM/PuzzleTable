
use v6.d;
use NativeCall;

use PuzzleTable::Gui::Category:api<2>;

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
    self.make-menu(:menu-name<Help>),
  ];
}

#-------------------------------------------------------------------------------
method make-menu ( Str :$menu-name --> Gnome::Gio::Menu ) {
  my Gnome::Gio::Menu $menu .= new-menu;
  $!bar.append-submenu( $menu-name, $menu);
  

  with $menu-name {
    when 'File' {
#      self.bind-action( $menu, $menu-name, self, 'Open', 'app.open');
      self.bind-action( $menu, $menu-name, self, 'Quit', 'app.quit');
    }

    when 'Category' {
      my PuzzleTable::Gui::Category $cat = $!main.combobox;
      self.bind-action( $menu, $menu-name, $cat, 'Add', 'app.add');
      self.bind-action( $menu, $menu-name, $cat, 'Rename', 'app.rename');
      self.bind-action( $menu, $menu-name, $cat, 'Remove', 'app.remove');
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
  Str $name, Str $action-name
) {
  my Gnome::Gio::MenuItem $menu-item .= new-menuitem( $name, $action-name);
  $menu.append-item($menu-item);

  my Gnome::Gio::SimpleAction $action .=
    new-simpleaction( $name.lc, Pointer); #N-VariantType);
  $!application.add-action($action);

  my Str $method = [~] $menu-name.lc, '-', $name.lc;
  $action.register-signal( $object, $method, 'activate');
}

#`{{
#-------------------------------------------------------------------------------
method file-open ( N-Object $parameter ) {
  say 'file open';
}
}}

#-------------------------------------------------------------------------------
method file-quit ( N-Object $parameter ) {
  say 'file quit';
  $!application.quit;
}

#-------------------------------------------------------------------------------
method help-about ( N-Object $parameter ) {
  say 'help about';
}

