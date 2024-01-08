use v6.d;
#use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::ExtractDataFromPuzzle;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config:auth<github:MARTIMM>;

has Version $.version = v0.3.1; 
has Array $.options = [<category=s import=s puzzle=s h help version>];

#-------------------------------------------------------------------------------
method file-import ( N-Object $parameter ) {
  say 'file import';
}

#-------------------------------------------------------------------------------
method check-category ( Str $category ) {
  say 'check category';
}

#-------------------------------------------------------------------------------
method add-category ( Str $category ) {
  say 'add category';
}

#-------------------------------------------------------------------------------
method rename-category ( Str $category-from, Str $category-to ) {
  say 'rename category';
}

#-------------------------------------------------------------------------------
method remove-category ( Str $category ) {
  say 'remove category';
}
