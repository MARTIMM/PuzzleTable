use v6.d;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::Category;

use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::T-Enums:api<2>;
use Gnome::Gtk4::T-Enums:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Button:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Sidebar:auth<github:MARTIMM>;
also is Gnome::Gtk4::ScrolledWindow;

has $!main is required;
has PuzzleTable::Config $!config;
has PuzzleTable::Gui::Category $!category;

has Gnome::Gtk4::Grid $!cat-grid;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!config = $!main.config;
  $!category = $!main.category;

  my Int $i = 0;
  with $!cat-grid .= new-grid {
    .set-name('sidebar');
    .set-margin-top(3);
    .set-margin-bottom(3);
    .set-margin-start(3);
    .set-margin-end(3);
    .set-hexpand(True);

    for $!config.get-categories(:filter<lockable>) -> $category {
      my Str $png-file = DATA_DIR ~ 'icons8-run-64.png';
      my Gnome::Gtk4::Button $cat-button .= new-button;
      my Gnome::Gtk4::Picture $p .= new-picture;
      $p.set-filename($png-file);
      $cat-button.set-child($p);

      $cat-button.set-valign(GTK_ALIGN_START);
      $cat-button.set-size-request( 64, 64);

#`{{
      $cat-button.set-has-tooltip(True);
      $cat-button.register-signal(
        self, 'show-tooltip', 'query-tooltip',
        :tip(
          'Run the ' ~ $!config.get-palapeli-preference ~ ' version of palapeli'
        )
      );
}}
      
      .attach( $cat-button, 0, $i, 1, 1);

      my Gnome::Gtk4::Label $cat-name .= new-label($category);
      $cat-name.set-valign(GTK_ALIGN_START);
      .attach( $cat-name, 1, $i, 1, 1);
      $i++;
    }
  }

  self.set-child($!cat-grid);
}


=finish
#-------------------------------------------------------------------------------
method BUILD ( ) {

}