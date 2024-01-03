
use v6.d;

use PuzzleTable::Types;

use YAMLish;

#use Gnome::N::GlibToRakuTypes:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Init:auth<github:MARTIMM>;

#has Array $!puzzle-locations = ();
has Hash $!puzzle-data = %();

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

  # Load puzzle data
  $!puzzle-data = load-yaml(PUZZLE_DATA.IO.slurp) if PUZZLE_DATA.IO.r;

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
