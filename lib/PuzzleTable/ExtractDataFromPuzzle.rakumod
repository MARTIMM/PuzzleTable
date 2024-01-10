use v6.d;

use Archive::Libarchive;
use Archive::Libarchive::Constants;

#-------------------------------------------------------------------------------
unit class PuzzleTable::ExtractDataFromPuzzle:auth<github:MARTIMM>;

my Str $puzzle-file;
my regex extract-regex {^ [ image \. | pala \. desktop ] };

#-------------------------------------------------------------------------------
#submethod BUILD ( ) { }

#-------------------------------------------------------------------------------
method extract ( Str:D $store-path, Str:D $puzzle-file ) {
  unless $puzzle-file.IO.r {
    note "file '$puzzle-file' not found";
    return;
  }

  my Archive::Libarchive $a .= new(
    operation => LibarchiveExtract,
    file => $puzzle-file,
    flags => ARCHIVE_EXTRACT_TIME +| ARCHIVE_EXTRACT_PERM +|
             ARCHIVE_EXTRACT_ACL +|  ARCHIVE_EXTRACT_FFLAGS
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
  $e.pathname ~~ m/ <extract-regex> /.Bool
}

#-------------------------------------------------------------------------------
method palapeli-info( Str:D $store-path --> Hash ) {
#note "$?LINE extract from $store-path/pala.desktop";

  my Hash $h = %();
  for "$store-path/pala.desktop".IO.slurp.lines -> $line {
    next unless $line ~~ m/ '=' /;
    my ( $name, $val) = $line.split('=');

    given $name {
      when 'Comment' {
        $h<Comment> = $val // '';
      }

      when 'Name' {
        $h<Name> = $val // '';
      }

      when 'ImageSize' {
        my $size = $val // '';
        my ( $width, $height) = $size.split(',');
        $h<Width> = $width.Int;
        $h<Height> = $height.Int;
      }

      when / PieceCount / {
        $h<PieceCount> = $val.Int;
      }
    }
  }

#note "$?LINE $h.gist()";
  $h
}
