use v6.d;

use Archive::Libarchive;
use Archive::Libarchive::Constants;

#-------------------------------------------------------------------------------
unit class PuzzleTable::ExtractDataFromPuzzle:auth<github:MARTIMM>;

my Str $puzzle-file;
my regex extract-regex {^ [ image \. | pala \. desktop ] };

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  
}

#-------------------------------------------------------------------------------
method extract ( Str:D $store-path, Str:D $puzzle-file ) {
  die "file '$puzzle-file' not found" unless $puzzle-file.IO.r;

#  my Str $parent = $puzzle-file.IO.parent.Str;
#  chdir($parent);

  my Archive::Libarchive $a .= new(
    operation => LibarchiveExtract,
    file => $puzzle-file,
    flags => ARCHIVE_EXTRACT_TIME +|
             ARCHIVE_EXTRACT_PERM +|
             ARCHIVE_EXTRACT_ACL +|
             ARCHIVE_EXTRACT_FFLAGS
  );

  try {
    $a.extract( &extract, $store-path);
    CATCH {
      say "Can't extract files: $_";
    }
  }

  $a.close;
}

#-------------------------------------------------------------------------------
sub extract ( Archive::Libarchive::Entry $e --> Bool ) {
  say "$e.pathname(), eq: ",
       $e.pathname ~~ m/ <extract-regex> /.Bool;
  $e.pathname ~~ m/ <extract-regex> /.Bool
}
