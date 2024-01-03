use v6.d;

#-------------------------------------------------------------------------------
unit package PuzzleTable::Types:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
constant APP_ID is export = 'io.github.martimm.puzzle-table';

constant DATA_DIR is export = [~] $*HOME, '/.config/', APP_ID, '/';

constant PUZZLE_DATA is export = DATA_DIR ~ 'puzzle-data.yaml';
constant PUZZLE_CSS is export = DATA_DIR ~ 'puzzle-data.css';
constant PUZZLE_TABLE_DATA is export = DATA_DIR ~ 'puzzle-table-data';


# Create directories
mkdir( DATA_DIR, 0o700) unless DATA_DIR.IO.e;
mkdir( DATA_DIR, 0o700) unless DATA_DIR.IO.e;
#say "$?LINE, ", PUZZLE_DATA;
