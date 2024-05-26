
use v6.d;

use YAMLish;

#use PuzzleTable::Types;
use PuzzleTable::Config::Puzzle;

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Category:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
has Str $!category-name;
has Str $!config-dir;
has Hash $!category-config;
has Str $!config-path;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$!category-name, Str:D :$root-dir ) {

  $!config-dir = "$root-dir/$!category-name";
  mkdir $!config-dir, 0o700 unless $!config-dir.IO.e;

  $!config-path = "$!config-dir/puzzle-data.yaml";
  if $!config-path.IO.r {
    $!category-config = load-yaml($!config-path.IO.slurp);
  }

  else {
    $!category-config = %(
      :!locable,
      :members(%()),
      :name($!category-name),
    );
  }
}

#-------------------------------------------------------------------------------
# Called reguarly after changes. Only every 5 times saved to save time.
# except when forced.
method save-category-config ( Bool :$force = False ) {
  state $save-count = 0;

  if $save-count++ >= 5 or $force {
    my $t0 = now;
    $!config-path.IO.spurt(save-yaml($!category-config));

    note "Done saving puzzle category $!category-name.";
    note "Time needed to save: {(now - $t0).fmt('%.1f sec')}.";

    # Always set to 0, even if $force triggered the save.
    $save-count = 0;
  }
}

#-------------------------------------------------------------------------------
# Called when category is not needed anymore and will be destroyed.
method finish ( ) {
  self.save-category-config(:force);
  $!category-config = %();
}

#-------------------------------------------------------------------------------
# A collection holds several puzzles together with the progress file.
# The $!config-dir is the location where sub directories are created 
# for each puzzle found.
method import-collection ( Str:D $collection-path ) {
  my PuzzleTable::Config::Puzzle $puzzle .= new;
  my Int $count = 1;

  for $collection-path.IO.dir -> $collection-file {
    next if $collection-file.d;

    # Skip all files but *.puzzle
    next if $collection-file.Str !~~ m/ \. puzzle $/;

    # Find a free id to store the data
    my Str $puzzle-destination;
    while $!category-config<members>{"p$count.fmt('%03d')"}:exists { $count++; }

    # Create directory for the puzzles files
    my Str $puzzle-id = 'p' ~ $count.fmt('%03d');
    $puzzle-destination = [~] $!config-dir, '/', $puzzle-id;
    mkdir $puzzle-destination, 0o700 unless $puzzle-destination.IO.e;

    # Get the puzzle data and Hash
    my Hash $puzzle-config = $puzzle.import-puzzle(
      $collection-file.Str, $puzzle-destination
    );

    my Str $progress-file = $collection-file.Str;
    $progress-file ~~ s/ '.puzzle' $/.save/;
    if $progress-file.IO.r {
      $puzzle-config<Progress> = $puzzle.calculate-progress(
        $progress-file, $puzzle-config<PieceCount>
      );
    }

    $!category-config<members>{$puzzle-id} = $puzzle-config;
    $count++;
  }
}

#-------------------------------------------------------------------------------
method remove-puzzle ( Str:D $puzzle-id, Str:D $archive-trashbin ) {

  my Str $puzzle-path = [~] $!config-dir, '/', $puzzle-id;

  # Get the configuration data of this puzzle and remove it from the
  # configuration Hash.
  my Hash $puzzle-data = $!category-config<members>{$puzzle-id}:delete;

  my Str $progress-file = [~] '__FSC_', $puzzle-data<Filename>, '_0_.save';

  my PuzzleTable::Config::Puzzle $puzzle .= new;
  $puzzle.archive-puzzle(
    $archive-trashbin, $puzzle-path, $puzzle-id, $puzzle-data
  );
}


=finish
#-------------------------------------------------------------------------------
method remove-puzzle ( Str $puzzle-id ) {

  # Create the name of the archive
  my Str $archive-name = DateTime.now.Str;
  $archive-name ~~ s/ '.' (...) .* $/.$0/;
  $archive-name ~~ s:g/ <[:-]> //;
  $archive-name ~~ s:g/ <[T.]> /-/;

  # Get the source and destination of the puzzle
  my Str $puzzle-path = [~] PUZZLE_TABLE_DATA, $from-cat, '/', $puzzle-id;
  my Str $archive-path = [~] PUZZLE_TRASH, $archive-name;

  # Rename the puzzle path into the archive path, effectively removing the
  # puzzle data from the other puzzles.
  $puzzle-path.IO.rename($archive-path);

  # Get the configuration data of this puzzle and remove it from the
  # configuration Hash.
  my Hash $puzzle;
  #$!semaphore.reader( 'puzzle-data', {
    $puzzle = $*puzzle-data<categories>{$from-cat}<members>{$puzzle-id}:delete;
  #});

#`{{
  # Create the name of the progress file in any of the Palapeli collections
  my Str $progress-file = [~] '__FSC_', $puzzle<Filename>, '_0_.save';

  # Search for progress file. If found move it also to destination dir
  my Str $colection-dir;
  #$!semaphore.writer( 'puzzle-data', {
    for $*puzzle-data<palapeli><collections>.keys -> $key {
      $colection-dir = $*puzzle-data<palapeli><collections>{$key};
      my Str $progress-path =
        [~] $*HOME, '/', $colection-dir, '/', $progress-file;

      if $progress-path.IO.r {
        $progress-path.IO.move( "$archive-path/$progress-file", :createonly);
        last;
      }
    }
  #});
}}
  # Following doesn't need protection because paths are always unique
  # and only used here

  # Save config into a yaml file in the destination dir
  "$archive-path/$puzzle-id.yaml".IO.spurt(save-yaml($puzzle));

  # Change dir to archive path
  my Str $cwd = $*CWD.Str;
  chdir($archive-path);

  # Create a bzipped tar archive
  my Archive::Libarchive $a .= new(
    operation => LibarchiveWrite,
    file => "{PUZZLE_TRASH}$archive-name.tbz2",
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

  $archive-path.IO.rmdir;

  # Return to dir where we started
  chdir($cwd);
}
