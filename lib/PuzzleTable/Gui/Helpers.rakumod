
use v6.d;

use Gnome::N::GlibToRakuTypes:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Helpers:auth<github:MARTIMM>;

method exit-application ( ) {     #( Mu :$main-loop --> gboolean ) {
  say 'close request';
#  $main-loop.quit;

  0
}

