
use v6.d;

use YAMLish;

use PuzzleTable::Config::Puzzle;
use PuzzleTable::Archive;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Category:auth<github:MARTIMM>;

has Str $.category-name;
has Str $.container;
has Str $!config-dir;
has Str $.root-dir;
has Hash $!category-config;
has Str $!config-path;

#-------------------------------------------------------------------------------
submethod BUILD (
  Str:D :$!category-name, Str:D :$!container, Str:D :$!root-dir
) {
#  $!category-name .= tc;
  $!container = self.set-container-name($!container);

  $!config-dir = "$!root-dir$!container/$!category-name";
#note "$?LINE $!config-dir, $!container, $!category-name";
note "$?LINE mkdir '$!config-dir'" unless $!config-dir.IO.e;
note "$?LINE Second call for pt2\n", Backtrace.new.nice if ! $!config-dir.IO.e and $!config-dir ~~ m/'/pt2/'/;
  mkdir $!config-dir, 0o700 unless $!config-dir.IO.e;

  $!config-path = "$!config-dir/puzzles.yaml";
  if $!config-path.IO.r {
    $!category-config = load-yaml($!config-path.IO.slurp);
  }

  else {
    $!category-config = %(
      :members(%()),
      :name($!category-name),
    );
  }
}

#-------------------------------------------------------------------------------
# Change the name which must be defined but may be empty ('')
# - First letter uppercase
# - Append '_EX_' to the name
method set-container-name ( Str:D $name --> Str ) {
note "$?LINE Use of '' in \$name\n", Backtrace.new.nice if $name eq '';

  my Str $container-name;

  # name has non empty string
  if ? $name {
    # name does not have _EX_ postfix yet
    if $name !~~ m/ '_EX_' $/ {
      $container-name = $name.lc.tc ~ '_EX_';
    }

    else {
      $container-name = $name.tc;
    }
  }

  # TODO test above for empty string using Backtrace
  else {
    $container-name = 'Default_EX_';
  }

  $container-name
}

#-------------------------------------------------------------------------------
# Called reguarly after changes. Only every 5 times saved to save time.
# except when forced.
method save-category-config ( ) {
  if ?self and ?$!category-config and ?$!config-path {
    my $t0 = now;
    $!config-path.IO.spurt(save-yaml($!category-config));

  #  note "Done saving puzzle category $!category-name.";
    note "Time needed to save category $!category-name: {(now - $t0).fmt('%.1f sec')}." if $*verbose-output;
  }
}

#-------------------------------------------------------------------------------
# A collection holds several puzzles together with the progress file.
# The $!config-dir is the location where sub directories are created 
# for each puzzle found.
method import-collection ( Str:D $collection-path ) {
  my PuzzleTable::Config::Puzzle $puzzle .= new;

  for $collection-path.IO.dir -> $collection-file {
    next if $collection-file.d;

    # Skip all files but *.puzzle
    next if $collection-file.Str !~~ m/ \. puzzle $/;

    # Get a new puzzle id
    my Str $puzzle-id = self.new-puzzle-id;

    # Get directory for the puzzles files
    my Str $puzzle-destination = self.get-puzzle-destination($puzzle-id);

    # Get the puzzle data and Hash
    my Hash $puzzle-config = $puzzle.import-puzzle(
      $collection-file.Str, $puzzle-destination
    );

    # Check if there is a progress file
    my Str $progress-file = $collection-file.Str;
    $progress-file ~~ s/ '.puzzle' $/.save/;
    if $progress-file.IO.r {
      $puzzle-config<Progress> = $puzzle.calculate-progress(
        $progress-file, $puzzle-config<PieceCount>
      );

      my Str $config-progress-filename =
         [~] '__FSC_', $puzzle-config<Filename>, '_0_.save';
      $progress-file.IO.copy("$puzzle-destination/$config-progress-filename");
      $puzzle-config<ProgressFile> = $config-progress-filename;
    }

    $!category-config<members>{$puzzle-id} = $puzzle-config;
    self.save-category-config;
  }
}

#-------------------------------------------------------------------------------
method add-puzzle ( Str:D $puzzle-path --> Str ) {

  # Get a new puzzle id
  my Str $puzzle-id = self.new-puzzle-id;

  # Get directory for the puzzles files
  my Str $puzzle-destination = self.get-puzzle-destination($puzzle-id);

  my PuzzleTable::Config::Puzzle $puzzle .= new;
  my Hash $puzzle-config = $puzzle.import-puzzle(
     $puzzle-path, $puzzle-destination
  );

  $!category-config<members>{$puzzle-id} = $puzzle-config;
  self.save-category-config;
  
  $puzzle-id
}

#-------------------------------------------------------------------------------
method update-puzzle ( Str:D $puzzle-id, Hash $new-pairs --> Bool ) {
  return False unless $!category-config<members>{$puzzle-id}:exists;

  for $new-pairs.kv -> Str $field-name, $value {
    if $field-name ~~ any(<Comment Source Progress>) and $value.defined {
      $!category-config<members>{$puzzle-id}{$field-name} = $value;
    }
  }

  #TODO remove temprary until all puzzles are slimmed down
  # Drop a few fields if they stick.
  $!category-config<members>{$puzzle-id}<Image>:delete;
  $!category-config<members>{$puzzle-id}<PuzzleID>:delete;
  $!category-config<members>{$puzzle-id}<Category>:delete;
  $!category-config<members>{$puzzle-id}<Category-Container>:delete;
  self.save-category-config;

  True
}

#-------------------------------------------------------------------------------
# To copy a confguration call this method. Only neede for the converter
method set-puzzle ( Str:D $puzzle-id, Hash $new-pairs ) {
  for $new-pairs.kv -> Str $field-name, $value {
    $!category-config<members>{$puzzle-id}{$field-name} = $value;
  }

  # Drop a few fields if they stick
  $!category-config<members>{$puzzle-id}<Image>:delete;
  $!category-config<members>{$puzzle-id}<PuzzleID>:delete;
  $!category-config<members>{$puzzle-id}<Category>:delete;
  $!category-config<members>{$puzzle-id}<Category-Container>:delete;
  self.save-category-config;
}

#-------------------------------------------------------------------------------
method archive-puzzles (
  Array:D $puzzle-ids, Str:D $archive-trashbin --> List
) {
  my Hash $puzzles = %();

  # First check all puzzles before changing the config
  for @$puzzle-ids -> $puzzle-id {
    return ( False, '') unless
      $!category-config<members>{$puzzle-id}:exists and
      "$!config-dir/$puzzle-id".IO.d;
  }

  # Create the archive info
  for @$puzzle-ids -> $puzzle-id {
    $puzzles{$puzzle-id} = %();
    $puzzles{$puzzle-id}<puzzle-path> = "$!config-dir/$puzzle-id";
    $puzzles{$puzzle-id}<puzzle-data> =
      $!category-config<members>{$puzzle-id}:delete;
  }

  # And archive the puzzles
  my PuzzleTable::Archive $archive .= new;
  my Str $archive-name = $archive.archive-puzzles(
    $archive-trashbin, $!category-name, $!container, $puzzles,
  );

  # Save all changes
  self.save-category-config;

  ( True, $archive-name)
}

#-------------------------------------------------------------------------------
method restore-puzzles (
  Str:D $archive-trashbin, Str:D $archive-name --> Bool
) {
  my PuzzleTable::Archive $archive .= new;

  my Hash $puzzles =
    $archive.restore-puzzles( $archive-trashbin, $archive-name, $!config-dir);

  return False unless ?$puzzles;

  for $puzzles.keys -> $puzzle {
    my Str $puzzle-id = $puzzles{$puzzle}<puzzle-id>;
    my Hash $puzzle-data = $puzzles{$puzzle}<puzzle-data>;
    $!category-config<members>{$puzzle-id} = $puzzle-data;
  }

  # Save all changes
  self.save-category-config;
  True
}

#-------------------------------------------------------------------------------
method get-puzzle ( Str $puzzle-id, Bool :$delete = False --> Hash ) {

  my Hash $h;
  if $delete {
    $h = $!category-config<members>{$puzzle-id}:delete;
    self.save-category-config;
  }

  else {
    # Must clone the hash when it is a scaler. Changes in $h are visible
    # in the source $!category-config<members>{$puzzle-id}
    $h = $!category-config<members>{$puzzle-id}.clone;
  }

  $h
}

#-------------------------------------------------------------------------------
method get-puzzle-ids ( --> Seq ) {
  $!category-config<members>.keys
}

#-------------------------------------------------------------------------------
method get-puzzle-destination ( Str $puzzle-id --> Str ) {

  # Define path to directory for the puzzle
  my Str $puzzle-destination = [~] $!config-dir, '/', $puzzle-id;

  $puzzle-destination
}

#-------------------------------------------------------------------------------
method new-puzzle-id ( --> Str ) {

  # Start at number of elements, less change of a collision, then find
  # a free id to store the data
  my Int $count = $!category-config<members>.elems;
  while $!category-config<members>{"p$count.fmt('%03d')"}:exists { $count++; }

  # Return the puzzle id
  'p' ~ $count.fmt('%03d')
}
