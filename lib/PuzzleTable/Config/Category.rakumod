
use v6.d;

use YAMLish;

#use PuzzleTable::Types;
use PuzzleTable::Config::Puzzle;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Category:auth<github:MARTIMM>;

has Str $.category-name;
has Str $!config-dir;
has Hash $!category-config;
has Str $!config-path;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$!category-name, Str:D :$root-dir ) {

  $!category-name .= tc;

  $!config-dir = "$root-dir/$!category-name";
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
# Called reguarly after changes. Only every 5 times saved to save time.
# except when forced.
method save-category-config ( ) {
  my $t0 = now;
  $!config-path.IO.spurt(save-yaml($!category-config));

#  note "Done saving puzzle category $!category-name.";
  note "Time needed to save category $!category-name: {(now - $t0).fmt('%.1f sec')}.";
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
    my Str $puzzle-id = self!new-puzzle-id;

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
  }
}

#-------------------------------------------------------------------------------
method add-puzzle ( Str:D $puzzle-path --> Str ) {

  # Get a new puzzle id
  my Str $puzzle-id = self!new-puzzle-id;

  # Get directory for the puzzles files
  my Str $puzzle-destination = self.get-puzzle-destination($puzzle-id);

  my PuzzleTable::Config::Puzzle $puzzle .= new;
  my Hash $puzzle-config = $puzzle.import-puzzle(
     $puzzle-path, $puzzle-destination
  );

  $!category-config<members>{$puzzle-id} = $puzzle-config;
  
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

  True
}

#-------------------------------------------------------------------------------
method remove-puzzle ( Str:D $puzzle-id, Str:D $archive-trashbin --> Bool ) {

  return False unless $!category-config<members>{$puzzle-id}:exists;

  my Str $puzzle-path = [~] $!config-dir, '/', $puzzle-id;
  return False unless $puzzle-path.IO.d;

  # Get the configuration data of this puzzle and remove it from the
  # configuration Hash.
  my Hash $puzzle-config = $!category-config<members>{$puzzle-id}:delete;

  my Str $progress-file = [~] '__FSC_', $puzzle-config<Filename>, '_0_.save';

  my PuzzleTable::Config::Puzzle $puzzle .= new;
  $puzzle.archive-puzzle( $archive-trashbin, $puzzle-path, $puzzle-config);

  True
}

#-------------------------------------------------------------------------------
method restore-puzzle (
  Str:D $archive-trashbin, Str:D $archive-name  --> Bool
) {
  my Bool $restore-ok = False;

  # Get a new puzzle id
  my Str $puzzle-id = self!new-puzzle-id;
  my Str $puzzle-path = [~] $!config-dir, '/', $puzzle-id;

  # Restore puzzle at $puzzle-path
  my PuzzleTable::Config::Puzzle $puzzle .= new;
  my Hash $puzzle-config = $puzzle.restore-puzzle(
    $archive-trashbin, $archive-name, $puzzle-path
  );

  if ? $puzzle-config {
    $!category-config<members>{$puzzle-id} = $puzzle-config;
    $restore-ok = True;
  }

  $restore-ok
}

#-------------------------------------------------------------------------------
method get-puzzle ( Str $puzzle-id  --> Hash ) {
  $!category-config<members>{$puzzle-id};
}

#-------------------------------------------------------------------------------
method get-puzzle-ids ( --> Seq ) {
  $!category-config<members>.keys
}

#-------------------------------------------------------------------------------
method get-puzzle-destination ( Str $puzzle-id --> Str ) {

  # Create directory for the puzzles files
  my Str $puzzle-destination = [~] $!config-dir, '/', $puzzle-id;
  mkdir $puzzle-destination, 0o700 unless $puzzle-destination.IO.e;

  $puzzle-destination
}

#-------------------------------------------------------------------------------
method !new-puzzle-id ( --> Str ) {

  # Start at number of elements, less change of a collision, then find
  # a free id to store the data
  my Int $count = $!category-config<members>.elems;
  while $!category-config<members>{"p$count.fmt('%03d')"}:exists { $count++; }

  # Create directory for the puzzles files
  'p' ~ $count.fmt('%03d')
}
