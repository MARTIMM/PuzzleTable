
use v6.d;

use PuzzleTable::Types;

#use Gnome::N::GlibToRakuTypes:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Init:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

  # Create css file
  (PUZZLE_CSS).IO.spurt(q:to/EOCSS/);
    window {
    }

    .puzzle-table-frame {
      border-width: 3px;
      border-style: outset;
      border-color: #ffee00;
      padding: 3px;
    /*	border-style: inset; */
    /*	border-style: solid; */
    /*	border-style: none; */
    }

    EOCSS
}
