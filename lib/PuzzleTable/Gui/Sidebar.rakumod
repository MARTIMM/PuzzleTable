use v6.d;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::Category;

use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Box:api<2>;
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

has Gnome::Gtk4::Box $!cat-grid;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  self.fill-sidebar;
}

#-------------------------------------------------------------------------------
method fill-sidebar ( ) {
#  self.set-size-request( 100, 100);
  self.set-halign(GTK_ALIGN_FILL);
  self.set-valign(GTK_ALIGN_FILL);
#  self.set-hexpand(True);
  self.set-vexpand(True);


  $!config = $!main.config;
  $!category = $!main.category;

#  my Int $i = 0;
  with $!cat-grid .= new-box( GTK_ORIENTATION_VERTICAL, 0) {
    .set-name('sidebar');
    .set-size-request( 100, 100);
#    .set-margin-top(3);
#    .set-margin-bottom(3);
#    .set-margin-start(3);
#    .set-margin-end(3);
#    .set-vexpand(True);

    for $!config.get-categories(:filter<lockable>) -> $category {
#`{{
      my Str $png-file = DATA_DIR ~ 'icons8-run-64.png';
      my Gnome::Gtk4::Picture $p .= new-picture;
      $p.set-filename($png-file);

      my Gnome::Gtk4::Button $cat-button .= new-button;
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
}}
      

      my Gnome::Gtk4::Button $cat-name .= new-button($category);
      $!config.set-css(
        $cat-name.get-style-context, :css-class<sidebar-label>
      );
      $cat-name.set-label($category);
      $cat-name.set-hexpand(True);
#      $cat-name.set-vexpand(True);
      $cat-name.set-halign(GTK_ALIGN_START);
#      $cat-name.set-valign(GTK_ALIGN_START);
      $cat-name.set-has-tooltip(True);
      $cat-name.register-signal(
        self, 'show-tooltip', 'query-tooltip', :$category
      );

      .append($cat-name);
#      $i++;
    }
  }

  self.set-child($!cat-grid);
}

#-------------------------------------------------------------------------------
method show-tooltip (
  Int $x, Int $y, gboolean $kb-mode, Gnome::Gtk4::Tooltip() $tooltip,
  Str :$category
  --> gboolean
) {
  my Gnome::Gtk4::Picture $p .= new-picture;
  $p.set-filename($!config.get-puzzle-image($category));
  $tooltip.set-custom($p);
  True

}