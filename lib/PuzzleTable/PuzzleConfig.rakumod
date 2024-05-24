use v6.d;

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
=item SlicerMode": ", irregular cut"
=item Source": "m"
=item SourceFile": "/home/marcel/.var/app/org.kde.palapeli/data/palapeli/collection/{8702b808-1c23-4f8f-9961-5e31a1355c67}.puzzle"

=end pod


#-------------------------------------------------------------------------------
use PuzzleTable::Types;

#-------------------------------------------------------------------------------
method archive ( ) {
}

#-------------------------------------------------------------------------------
method restore ( ) {
}

#-------------------------------------------------------------------------------
method import-exported-puzzle ( Str $path ) {
}

#-------------------------------------------------------------------------------
method import-collection-puzzle ( Str $path ) {
}
