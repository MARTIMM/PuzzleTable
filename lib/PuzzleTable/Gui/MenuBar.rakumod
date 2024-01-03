
use v6.d;
use NativeCall;

#use Gnome::Glib::N-VariantType:api<2>;

use Gnome::Gio::Menu:api<2>;
use Gnome::Gio::MenuItem:api<2>;
use Gnome::Gio::SimpleAction:api<2>;

use Gnome::Gtk4::Application:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::MenuBar:auth<github:MARTIMM>;

has Gnome::Gio::Menu $.bar;
has Gnome::Gtk4::Application $!application;

has Array $!menus;

#-------------------------------------------------------------------------------
submethod BUILD ( :$main-window ) {
  $!application = $main-window.application;
  $!bar .= new-menu;
  $!menus = [
    self.make-menu(:menu-name<File>),
    self.make-menu(:menu-name<Category>),
    self.make-menu(:menu-name('')),
    self.make-menu(:menu-name<Help>),
  ];
}

#-------------------------------------------------------------------------------
method make-menu ( Str :$menu-name --> Gnome::Gio::Menu ) {
  my Gnome::Gio::Menu $menu .= new-menu;
  $!bar.append-submenu( $menu-name, $menu);

  with $menu-name {
    when 'File' {
      self.add-entry( $menu, $menu-name, 'Open', 'app.open');
      self.add-entry( $menu, $menu-name, 'Quit', 'app.quit');
    }

    when 'Category' {
      self.add-entry( $menu, $menu-name, 'Add', 'app.add');
      self.add-entry( $menu, $menu-name, 'Rename', 'app.rename');
      self.add-entry( $menu, $menu-name, 'Remove', 'app.remove');
    }

    when '' {
      my Gnome::Gio::Menu $m .= new-menu;
      $menu.append-item($m);
    }
  }

  $menu
}

#-------------------------------------------------------------------------------
method add-entry (
  Gnome::Gio::Menu $menu, Str $menu-name, Str $name, Str $action-name
) {
  my Gnome::Gio::MenuItem $menu-item .= new-menuitem( $name, $action-name);
  $menu.append-item($menu-item);

  my Gnome::Gio::SimpleAction $action .=
    new-simpleaction( $name.lc, Pointer); #N-VariantType);
  $!application.add-action($action);

  my Str $method = [~] $menu-name.lc, '-', $name.lc;
  $action.register-signal( self, $method, 'activate');
}

#-------------------------------------------------------------------------------
method file-open ( N-Object $parameter ) {
  say 'file open';
}

#-------------------------------------------------------------------------------
method file-quit ( N-Object $parameter ) {
  say 'file quit';
  $!application.quit;
}

#-------------------------------------------------------------------------------
method category-add ( N-Object $parameter ) {
  say 'category add';
}

#-------------------------------------------------------------------------------
method category-rename ( N-Object $parameter ) {
  say 'category rename';
}

#-------------------------------------------------------------------------------
method category-remove ( N-Object $parameter ) {
  say 'category remove';
}
