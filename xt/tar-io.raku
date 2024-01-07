use v6.d;

use Archive::Libarchive;
use Archive::Libarchive::Constants;

my Str $puzzle-file;
my regex extract-regex {^ [ image \. | pala \. desktop ] };

sub MAIN( $f! where { .IO.r // die "file '$puzzle-file' not found" } ) {
  $puzzle-file = $f;
  my Str $parent = $puzzle-file.IO.parent.Str;
  chdir($parent);

  my Archive::Libarchive $a .= new(
    operation => LibarchiveExtract,
    file => $puzzle-file,
    flags => ARCHIVE_EXTRACT_TIME +|
             ARCHIVE_EXTRACT_PERM +|
             ARCHIVE_EXTRACT_ACL +|
             ARCHIVE_EXTRACT_FFLAGS
  );

  try {
    $a.extract( &extract, $parent);
    CATCH {
      say "Can't extract files: $_";
    }
  }

  $a.close;
}

sub extract ( Archive::Libarchive::Entry $e --> Bool ) {
  say "$e.pathname(), eq: ",
       $e.pathname ~~ m/ <extract-regex> /.Bool;
  $e.pathname ~~ m/ <extract-regex> /.Bool
}
