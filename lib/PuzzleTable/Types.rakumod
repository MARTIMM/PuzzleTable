use v6.d;

#-------------------------------------------------------------------------------
unit package PuzzleTable::Types:auth<github:MARTIMM>;

our $version = Version.new(v0.8.1);

#-------------------------------------------------------------------------------
constant APP_ID is export = 'io.github.martimm.puzzle-table';

constant DATA_DIR is export = [~] $*HOME, '/.config/', APP_ID, '/';

#constant PUZZLE_DATA is export = DATA_DIR ~ 'puzzle-data.yaml';
constant GLOBAL_CONFIG is export = DATA_DIR;
constant PUZZLE_TABLE_DATA is export = DATA_DIR ~ 'puzzle-table-data/';

constant PUZZLE_TRASH is export = DATA_DIR ~ 'puzzle-trash/';

enum InstallType is export < FlatPak Snap Standard >;

# Names the entries in the totals array
enum TotalType is export <
  TOTAL_PUZZLES UNTOUCHED_PUZZLES UNFINISHED_PUZZLES FINISHED_PUZZLES
  >;

# A Supply is read by several clients. These are codes the clients must
# test to check the rest of the data in a given hash.
enum SupplyCode is export <
  PROCESS_TOTALS
  >;

# Create directories in the default location. When other locations are
# added, only a location for the new table data and trash are added using
# a provided root.
mkdir( DATA_DIR, 0o700) unless DATA_DIR.IO.e;
mkdir( PUZZLE_TABLE_DATA, 0o700) unless PUZZLE_TABLE_DATA.IO.e;
mkdir( PUZZLE_TRASH, 0o700) unless PUZZLE_TRASH.IO.e;

