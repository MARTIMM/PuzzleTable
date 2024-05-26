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
# Extract image and desktop file from $puzzle-file, a tar file, and
# store the data at $store-path.
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

  my Hash $h = %();
  my Int $piece-count = 0;
  my Bool $do-count = False;
  for "$store-path/pala.desktop".IO.slurp.lines -> $line {
    $do-count = True if $line eq '[PieceOffsets]';
    $do-count = False if $line eq '[Relations]';

    next unless $line ~~ m/ '=' /;
    $piece-count++ if $do-count;

    my ( $name, $val) = $line.split('=');
    my Str $slicer = '';
    given $name {
      when 'Comment' {
        $h<Comment> = $val // '';
      }

      when 'Name' {
        $h<Name> = $val // '';
      }

      when / Author / {
        $h<Source> = $val // '';
      }

      when 'ImageSize' {
        my $size = $val // '';
        my ( $width, $height) = $size.split(',');
        $h<ImageSize> = "$width x $height";
      }

      when 'Slicer' {
        $val ~~ s/^ palapeli '_' //;
        $val ~~ s/ slicer $//;
        $h<Slicer> = $val;
      }

      when 'SlicerMode' {
        if    $val eq 'preset' { $h<SlicerMode> = ', predefined cut'; }
        elsif $val eq 'rect'   { $h<SlicerMode> = ', rectangular cut'; }
        elsif $val eq 'cairo'  { $h<SlicerMode> = ', cairo cut'; }
        elsif $val eq 'hex'    { $h<SlicerMode> = ', hexagonal cut'; }
        elsif $val eq 'rotrex' { $h<SlicerMode> = ', rhombi trihexagonal cut'; }
        elsif $val eq 'irreg'  { $h<SlicerMode> = ', irregular cut'; }
        elsif $val eq ''       {
          if $h<Slicer> eq 'rect' {
            $h<SlicerMode> = ' cut in rectangles';
          }

          elsif $h<Slicer> eq 'jigsaw' {
            $h<SlicerMode> = ' cut in classic pieces';
          }
        }
      }
    }
  }

  $h<PieceCount> = $piece-count;

  $h
}
