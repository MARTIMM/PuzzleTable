use v6.d;

use PuzzleTable::Types;
use PuzzleTable::ExtractDataFromPuzzle;

use Digest::SHA256::Native;
use Archive::Libarchive;
use Archive::Libarchive::Constants;
use YAMLish;

#-------------------------------------------------------------------------------
=begin pod

PuzzleConfig handles a separate puzzle. Its tasks are
=item Archiving; Archiving is done when a puzzle is removed from the puzzle table.
=item Restore; This is the opposite of the archiving operation when one wants the puzzle back on the puzzle table.
=item Import; Create a new structure when reading an exported puzzle from disk or a puzzle found in a Palapeli collection

The information stored in a Hash have the following keys
=item Comment; Info from exported file and is editable.
=item Filename; The filename after it is imported. It is a sha256 encoded .source file with a prefixed timestamp to make the file unique.
=item ImageSize; Size as it is found in the puzzle.
=item Name; Short name of the puzzle.
=item PieceCount; Number of pieces.
=item Progress; Progress of the played puzzle in percentage finished. It has a subkey of Snap, Flatpak or Standard, depending on the Palapeli program used.
=item Slicer; Type of puzzle piece slicer used to generate the puzzle. This is done by the Palapeli program.
=item SlicerMode; The mode used by the slicer.
=item Source; Remarks of the origin of the picture.
=item SourceFile; The source filename of the original puzzle.

=end pod

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Puzzle:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
method archive-puzzle (
  Str:D $archive-trashbin, Str:D $puzzle-path, Hash:D $puzzle-data
) {

  # Create the name of the archive
  my Str $archive-name = DateTime.now.Str;
  $archive-name ~~ s/ '.' (...) .* $/.$0/;
  $archive-name ~~ s:g/ <[:-]> //;
  $archive-name ~~ s:g/ <[T.]> /-/;

  my Str $archive-path = [~] $archive-trashbin, $archive-name;

  # Rename the puzzle path into the archive path, effectively removing the
  # puzzle data from the other puzzles.
  $puzzle-path.IO.rename($archive-path);

  # Change dir to archive path
  my Str $cwd = $*CWD.Str;
  chdir($archive-path);

  # Save config into a yaml file in the archive dir
  "puzzle-data.yaml".IO.spurt(save-yaml($puzzle-data));

  # Create a bzipped tar archive
  my Archive::Libarchive $a .= new(
    operation => LibarchiveWrite,
    file => "$archive-path.tbz2",
    format => 'v7tar',
    filters => ['bzip2']
  );

  # Store each file in this path into the archive
  for dir('.') -> $file {
    $a.write-header($file.Str);
    $a.write-data($file.Str);
  }

  # And close the archive
  $a.close;

  # Cleanup the directory and leave tarfile in the trash dir
  for dir('.') -> $file {
    $file.IO.unlink;
  }

  # Return to dir where we started
  chdir($cwd);
  $archive-path.IO.rmdir;
}

#-------------------------------------------------------------------------------
method restore-puzzle (
  Str:D $archive-trashbin, Str:D $archive-name, Str:D $puzzle-path --> Hash
) {

  my Str $archive-path = [~] $archive-trashbin, $archive-name;
  return Hash unless $archive-path.IO.r;

  my Archive::Libarchive $a .= new(
    operation => LibarchiveExtract,
    file => "$archive-path",
    flags => ARCHIVE_EXTRACT_TIME +| ARCHIVE_EXTRACT_PERM +|
             ARCHIVE_EXTRACT_ACL +|  ARCHIVE_EXTRACT_FFLAGS
  );

  try {
    $a.extract("$archive-trashbin/puzzle");
    CATCH {
      say "Can't extract files: $_";
      return Hash;
    }
  }

  $a.close;

  # Older versions of archives hold the config in a '<puzzle-id>.yaml' file
  # Now it is stored in a straight forward name 'puzzle-data.yaml'.
  my Str $config-file;
  if "$archive-trashbin/puzzle/puzzle-data.yaml".IO.e {
    $config-file = "$archive-trashbin/puzzle/puzzle-data.yaml";
  }

  else {
    for dir("$archive-trashbin/puzzle") -> $f {
      if $f.Str ~~ m/ '/' p \d+ '.yaml' $/ {
        $config-file = $f.Str;
        last;
      }
    }
  }

  my Hash $config;
  if ? $config-file {
    $config = load-yaml($config-file.IO.slurp);
    $config-file.IO.unlink;

    # Remove unneeded data, older version might have it saved in the archive
    "$archive-trashbin/puzzle/image.jpg".IO.unlink
      if "$archive-trashbin/puzzle/image.jpg".IO.e;
    "$archive-trashbin/puzzle/pala.desktop".IO.unlink
      if "$archive-trashbin/puzzle/pala.desktop".IO.e;

    # Rename the archive path into the puzzle path, effectively adding the
    # puzzle data into a category.
    "$archive-trashbin/puzzle".IO.rename($puzzle-path);
  }

  else {
    sub cleanup-extracted-data ( Str:D $d ) {
      for dir($d) -> $f {
        if $f.d {
          cleanup-extracted-data($f.Str);
        }

        else {
          $f.unlink;
        }
      }

      $d.rmdir;
    }

    cleanup-extracted-data("$archive-trashbin/puzzle");
    return Hash;
  }

  $config
}

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
  my PuzzleTable::ExtractDataFromPuzzle $extracter .= new;
  $extracter.extract( $destination, $puzzle-path);

  # Convert the image into a smaller one to be displayed on the puzzle table
  run '/usr/bin/convert', "$destination/image.jpg",
      '-resize', '400x400', "$destination/image400.jpg";

  # Get some info from the desktop file
  my Hash $info = $extracter.palapeli-info($destination);

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
=begin pod

Method to calculate the progress of the played puzzle. The C<$progress-path> points to the C<I<file>.save> file. The progress is converted to a string before returning.

=end pod

method calculate-progress (
  Str $progress-path, Int $number-of-pieces --> Str
) {
  my Bool $get-lines = False;
  my Hash $piece-coordinates = %();

  for $progress-path.IO.slurp.lines -> $line {
    if $line ~~ m/ '[' [ 'XYCo-ordinates' | 'Relations' ] ']' / {
      $get-lines = True;
      next;
    }

    last if $get-lines and $line ~~ m / '[' /;

    if $get-lines {
      my Str ( $, $piece-coordinate ) = $line.split('=');
      $piece-coordinates{$piece-coordinate} = 1;
    }
  }

  # A puzzle of n pieces has n different pieces at the start and only one
  # when finished. To calculate the progress substract one from the numbers
  # before deviding.
  my Rat $p =
     100.0 - ($piece-coordinates.elems -1) / ($number-of-pieces -1) * 100.0;

  $p.fmt('%3.1f')
}

