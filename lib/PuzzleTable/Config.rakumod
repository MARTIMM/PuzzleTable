use v6.d;
#use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::ExtractDataFromPuzzle;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
method file-import ( N-Object $parameter ) {
  say 'file import';
}
