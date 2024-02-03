use v6.d;

#-------------------------------------------------------------------------------
unit package PuzzleTable::Types:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
constant APP_ID is export = 'io.github.martimm.puzzle-table';

constant DATA_DIR is export = [~] $*HOME, '/.config/', APP_ID, '/';

constant PUZZLE_DATA is export = DATA_DIR ~ 'puzzle-data.yaml';
constant PUZZLE_TABLE_DATA is export = DATA_DIR ~ 'puzzle-table-data/';

constant PUZZLE_TRASH is export = DATA_DIR ~ 'puzzle-trash/';

enum InstallType is export < FlatPak Snap Standard >;

# Create directories
mkdir( DATA_DIR, 0o700) unless DATA_DIR.IO.e;
mkdir( PUZZLE_TABLE_DATA, 0o700) unless PUZZLE_TABLE_DATA.IO.e;
mkdir( PUZZLE_TRASH, 0o700) unless PUZZLE_TRASH.IO.e;
