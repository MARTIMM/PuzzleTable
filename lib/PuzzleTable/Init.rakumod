
use v6.d;

use PuzzleTable::Types;

use YAMLish;

#use Gnome::N::GlibToRakuTypes:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Init:auth<github:MARTIMM>;

#my Array $!puzzle-locations = ();
my Hash $!puzzle-data = %();

#-------------------------------------------------------------------------------
method first-init ( ) {

  mkdir( DATA_DIR, 0o700) unless DATA_DIR.IO.e;
  say "$?LINE, ",  DATA_DIR ~ PUZZLE_DATA;

  $!puzzle-data = load-yaml((DATA_DIR ~ PUZZLE_DATA).IO.slurp)
    if (DATA_DIR ~ PUZZLE_DATA).IO.r;
}
