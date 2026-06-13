use v6.d;

#-------------------------------------------------------------------------------
use PuzzleTable::Config;

use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::IconButton:auth<github:MARTIMM>;
also is Gnome::Gtk4::Button;

#-------------------------------------------------------------------------------
multi submethod BUILD ( Str:D :$icon!, Str:D :$action-name ) {
  my PuzzleTable::Config $config .= instance;
  with self {
    $config.set-css( .get-style-context, :css-class<toolbar-icon>);
    .set-icon-name($icon);
    .set-size-request( 64, 64);
    .set-action-name($action-name);
  }
}

#-------------------------------------------------------------------------------
multi submethod BUILD ( Str:D :$path!, Str:D :$action-name ) {
#  my PuzzleTable::Config $config .= instance;

  with my Gnome::Gtk4::Picture $image .= new-for-filename($path) {
    .set-content-fit(GTK_CONTENT_FIT_SCALE_DOWN);
    .set-can-shrink(True);
    .set-size-request( 64, 64);
  }

  with self {
    .set-size-request( 64, 64);
    .set-child($image);
    .set-action-name($action-name);
  }
}
