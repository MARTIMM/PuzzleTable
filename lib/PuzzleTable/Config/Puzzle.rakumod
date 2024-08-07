use v6.d;

use PuzzleTable::Types;
use PuzzleTable::Archive;

use Digest::SHA256::Native;
use Archive::Libarchive;
use Archive::Libarchive::Constants;
use YAMLish;

#-------------------------------------------------------------------------------
=begin pod

PuzzleConfig handles a separate puzzle. Its tasks are
=item Import; Create a new structure when reading an exported puzzle from disk or a puzzle found in a Palapeli collection

The information stored in a Hash have the following keys
=item2 Comment; Info from exported file and is editable.
=item2 Filename; The filename after it is imported. It is a sha256 encoded .source file with a prefixed timestamp to make the file unique.
=item2 ImageSize; Size as it is found in the puzzle.
=item2 Name; Short name of the puzzle.
=item2 PieceCount; Number of pieces.
=item2 Progress; Progress of the played puzzle in percentage finished. It has a subkey of Snap, Flatpak or Standard, depending on the Palapeli program used.
=item2 Slicer; Type of puzzle piece slicer used to generate the puzzle. This is done by the Palapeli program.
=item2 SlicerMode; The mode used by the slicer.
=item2 Source; Remarks of the origin of the picture.
=item2 SourceFile; The source filename of the original puzzle.

=item Calculate the progress of a puzzle

=end pod

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Puzzle:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
# Get data of a puzzle and store in a Hash. Also a $destination where puzzle
# files and extra info is stored.
method import-puzzle ( Str $puzzle-path, Str $destination --> Hash ) {

  # If one is dumping the puzzles in the same dir all the time using
  # the same file names, one can run into a clash with older puzzles,
  # sha256 does not help enough with that. So postfix with a date stamp.
  my Str $extra-change = DateTime.now.Str;

  # Store the puzzle using a unique filename.
  mkdir( $destination, 0o700) unless $destination.IO.e;
  my Str $unique-name = sha256-hex($puzzle-path ~ $extra-change) ~ ".puzzle";
  $puzzle-path.IO.copy( "$destination/$unique-name", :createonly);

  # Get the image and desktop file from the puzzle file, a tar archive.
  my PuzzleTable::Archive $archive .= new;
  $archive.extract( $destination, $puzzle-path);

  # Add a smaller version of image
  self.convert-image($destination);

  # Get some info from the desktop file
  my Hash $info = $archive.palapeli-info($destination);

  # Remove unneeded data
  "$destination/image.jpg".IO.unlink;
  "$destination/pala.desktop".IO.unlink;

  # Add :Filename and :SourceFile keys
  %(
    :Filename($unique-name),
    :SourceFile($puzzle-path),
    :Source($info<Source>),
    :Comment($info<Comment>),
    :Name($info<Name>),
    :ImageSize($info<ImageSize>),
    :PieceCount($info<PieceCount>),
    :Slicer($info<Slicer>),
    :SlicerMode($info<SlicerMode>),
  )
}

#-------------------------------------------------------------------------------
# Convert the image into a smaller one to be displayed on the puzzle table
# Modern version (IMv7) of magick has convert deprecated
method convert-image ( Str $destination ) {

  my Bool $is-new = False;
  my Proc $p = shell "/usr/bin/magick -version", :out;
  for $p.out.lines -> $l {
    if $l ~~ m/^ Version ':' \s ImageMagick \s $<v> = \d+ / {
      $is-new = True if $/<v>.Str.Int > 6;
      last;
    }
  }
  $p.out.close;

  if $is-new {
    run '/usr/bin/magick', "$destination/image.jpg",
        '-resize', '400x400', "$destination/image400.jpg";
  }

  else {
    run '/usr/bin/magick', 'convert', "$destination/image.jpg",
        '-resize', '400x400', "$destination/image400.jpg";
  }
}

#-------------------------------------------------------------------------------
=begin pod

Method to calculate the progress of the played puzzle. The C<$progress-path> points to the C<I<file>.save> file. The progress is converted to a string before returning.

=end pod

method calculate-progress (
  Str $progress-path, Int $number-of-pieces --> Str
) {
  my Bool $get-lines = False;
  my SetHash $piece-coordinates .= new;

  for $progress-path.IO.slurp.lines -> $line {
    if $line ~~ m/ '[' [ 'XYCo-ordinates' | 'Relations' ] ']' / {
      $get-lines = True;
      next;
    }

    last if $get-lines and $line ~~ m / '[' /;

    if $get-lines {
      my Str ( $, $piece-coordinate ) = $line.split('=');
      $piece-coordinates.set($piece-coordinate);
    }
  }

  # A puzzle of n pieces has n different pieces at the start and only one
  # when finished. To calculate the progress substract one from the numbers
  # before deviding.
  my Rat $p =
     100.0 - ($piece-coordinates.elems -1) / ($number-of-pieces -1) * 100.0;

  $p.fmt('%3.1f')
}

