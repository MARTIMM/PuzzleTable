use v6.d;
use PuzzleTable::Types:auth<github:MARTIMM>;

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
unit class PuzzleTable::Config::Puzzle;

#-------------------------------------------------------------------------------
method archive ( ) {
}

#-------------------------------------------------------------------------------
method restore ( ) {
}

#-------------------------------------------------------------------------------
method import-exported-puzzle ( Str $puzzle-path --> Hash ) {
}

#-------------------------------------------------------------------------------
method import-collection-puzzle ( Str $collection-path --> Hash ) {
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

