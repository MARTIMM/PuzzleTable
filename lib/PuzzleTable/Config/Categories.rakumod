use v6.d;

use YAMLish;
use Digest::SHA256::Native;

#use PuzzleTable::Types;
#use PuzzleTable::Config::Puzzle;
use PuzzleTable::Config::Category;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Categories:auth<github:MARTIMM>;

has Str $!root-dir;
has Str $!config-path;
has Hash $!categories-config;
has PuzzleTable::Config::Category $!current-category;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$!root-dir ) {

  $!config-path = "$!root-dir/categories.yaml";
  if $!config-path.IO.r {
    $!categories-config = load-yaml($!config-path.IO.slurp);
  }

  else {
#    $!categories-config = %();
#    $!categories-config<categories> = %();
    $!categories-config<categories><Default> = %(:!lockable);

    $!categories-config<password> = '';

#    $!categories-config<palapeli> = %();
    given $!categories-config<palapeli><Flatpak> {
      .<collection> = '.var/app/org.kde.palapeli/data/palapeli/collection>';
      .<exec> = '/usr/bin/flatpak run org.kde.palapeli';
      .<env> = %(
        :GDK_BACKEND<x11>,
      )
   }

    given $!categories-config<palapeli><Snap> {
      .<collection> = 'snap/palapeli/current/.local/share/palapeli/collection>';
      .<exec> = '/var/lib/snapd/snap/bin/palapeli';
      .<env> = %(
        :BAMF_DESKTOP_FILE_HINT</var/lib/snapd/desktop/applications/palapeli_palapeli.desktop>,
        :GDK_BACKEND<x11>,
      )
    }

    given $!categories-config<palapeli><Standard> {
      .<collection> = <.local/share/palapeli/collection>;
      .<exec> = '/usr/bin/palapeli';
      .<env> = %(
        :GDK_BACKEND<x11>,
      )
    }

    $!categories-config<palapeli><preference> = 'Snap';
  }

  # Always lock at start
  $!categories-config<locked> = True;

  # Always select the default category
  $!current-category .= new( :category-name('Default'), :$!root-dir);
}

#-------------------------------------------------------------------------------
# Called after adding, removing, or other changes are made on a category
method save-categories-config ( ) {
  my $t0 = now;

  # Save categories config
  $!config-path.IO.spurt(save-yaml($!categories-config));

  # And, if there is a selected category, also save category data
  $!current-category.save-category-config;

#  note "Done saving categories";
  note "Time needed to save categories: {(now - $t0).fmt('%.1f sec')}.";
}

#-------------------------------------------------------------------------------
method add-category (
  Str:D $category-name is copy, :$lockable = False --> Str
) {
  my Str $message = '';
  $category-name .= tc;

  if $!categories-config<categories>{$category-name}:exists {
    $message = "Category $category-name already exists";
  }

  else {
    $!categories-config<categories>{$category-name}<lockable> = $lockable;
  }

  $message
}

#-------------------------------------------------------------------------------
method select-category ( Str:D $category-name is copy --> Str ) {
  my Str $message = '';
  $category-name .= tc;

  if $!categories-config<categories>{$category-name}:exists {
    # Check if a category was selected. If so, save before assigning a new
    $!current-category.save-category-config;

    # Set to new category
    $!current-category .= new( :$category-name, :$!root-dir);
  }

  else {
    $message = "Category $category-name does not exist";
  }

  $message
}

#-------------------------------------------------------------------------------
method get-current-category ( --> Str ) {
  $!current-category.category-name;
}

#-------------------------------------------------------------------------------
method import-collection ( Str:D $collection-path --> Str ) {
  my Str $message = '';

  if $collection-path.IO.d {
    $!current-category.import-collection($collection-path);
  }

  else {
    $message = 'Collection path does not exist or isn\'t a directory';
  }

  $message
}

#-------------------------------------------------------------------------------
method add-puzzle ( Str:D $puzzle-path ) {
  my Str $message = '';

  if $puzzle-path.IO.r {
    my Str $puzzle-id = $!current-category.add-puzzle($puzzle-path);
#`{{
    my Hash $puzzle-config = $!current-category.get-puzzle($puzzle-id);
    if ?$puzzle-config<ProgressFile> {
      #!!!!!!!!!!!!!!!!!!!!
    }

    else {
      my Str $p = $!categories-config<palapeli><preference>;
      my Str $c = $!categories-config<palapeli>{$p}<collection>;
      my Str $filename = $puzzle-config<Filename>;
      my Str $progress-filename = [~] '__FSC_', $filename, '_0_.save';
      #!!!!!!!!!!!!!!!!!!!!
    }
}}
  }

  else {
    $message = 'Puzzle does not exist or isn\'t a puzzle file';
  }

  $message
}

#-------------------------------------------------------------------------------
method remove-puzzle ( Str:D $puzzle-id, Str:D $archive-trashbin --> Str ) {
  my Str $message = '';

  if ! $!current-category.remove-puzzle( $puzzle-id, $archive-trashbin) {
    $message = 'Puzzle id is wrong and/or Puzzle store not found';
  }

  $message
}

#-------------------------------------------------------------------------------
method restore-puzzle ( Str:D $archive-trashbin, Str:D $archive-name --> Str ) {
  my Str $message = '';

  if ! $!current-category.restore-puzzle( $archive-trashbin, $archive-name) {
    $message = 'Archive not found or does not have the proper contents';
  }

  $message
}

#-------------------------------------------------------------------------------
=begin pod

Return an sequence of hashes. Puzzles are taken from the current category and extra information is added to update the puzzles later if needed. The sequence is sorted on the number of pieces used for the puzzle. This method is called from the puzzle table display to be able to

=item display in the order set above.
=item to edit a few fields in the structure followed by .update-puzzle().
=item to run the Palapeli program to play the puzzle with .run-palapeli().
=item to update the progress after playing using .calculate-progress() in class B<PuzzleTable::Config::Puzzle> followed by .update-puzzle().

  method get-puzzles ( --> Seq )

=end pod

method get-puzzles ( --> Seq ) {

  my Str $pi;
  my Int $found-count = 0;
  my Array $cat-puzzle-data = [];

  for $!current-category.get-puzzle-ids -> $puzzle-id {
    my Hash $puzzle-config = $!current-category.get-puzzle($puzzle-id);

    # Add extra info so it can be used to modify the data later, e.g. progress.
    $puzzle-config<PuzzleID> = $puzzle-id;
    $puzzle-config<Category> = $!current-category.category-name;
    $puzzle-config<Image> = 
      $!current-category.get-puzzle-destination($puzzle-id) ~ '/image400.jpg';

    # Drop some data
    $puzzle-config<SourceFile>:delete;

    $cat-puzzle-data.push: $puzzle-config;
  }

  # Sort pusles on its size
  my Seq $puzzles = $cat-puzzle-data.sort(
    -> $item1, $item2 { 
      if $item1<PieceCount> < $item2<PieceCount> { Order::Less }
      elsif $item1<PieceCount> == $item2<PieceCount> { Order::Same }
      else { Order::More }
    }
  );

  $puzzles
}

#-------------------------------------------------------------------------------
# This puzzle hash must have the extra fields added by get-puzzles
method run-palapeli ( Hash $puzzle ) {
  my Str $pref = $!categories-config<palapeli><preference>;
  for $!categories-config<palapeli>{$pref}<env>.kv -> $env-key, $env-val {
    %*ENV{$env-key} = $env-val;
  }

  my Str $exec = $!categories-config<palapeli>{$pref}<exec>;
  my Str $puzzle-id = $puzzle<PuzzleID>;
  my Str $puzzle-path = [~]
    $!current-category.get-puzzle-destination($puzzle-id),
    '/', $puzzle<Filename>;

  my Str $prog-filename = $puzzle<ProgressFile> //
      [~] '__FSC_', $puzzle<Filename>, '_0_.save';

  my Str $prog-path = [~]
    $!current-category.get-puzzle-destination($puzzle-id),
    '/', $prog-filename if ?$prog-filename;

  if ?$prog-filename and $prog-path.IO.r {
    my $collection = $!categories-config<palapeli>{$pref}<collection>;
    $prog-path.IO.copy("$collection/$prog-filename");
  }

  shell "$exec $puzzle-path";

# ! restore
}

#`{{
#-------------------------------------------------------------------------------
# Called from call-back in Table after playing a puzzle.
# The object holds most of the fields of some puzzle added with
# the following fields: Puzzle-index, Category and Image (see get-puzzles()
# below) while Name and SourceFile are removed (see add-puzzle-to-table()
# in Table).
method restore-progress-file ( Hash $puzzle ) {

  my $c = $puzzle<Category>;
  my $i = $puzzle<Puzzle-index>;

  my Str $filename = $*puzzle-data<categories>{$c}<members>{$i}<Filename>;
  my Str $collection-filename = [~] '__FSC_', $filename, '_0_.save';
  my Str $collection-path =
     [~] $!config.get-pala-collection, '/', $collection-filename;

  my Str $backup-path = [~] PUZZLE_TABLE_DATA, $puzzle<Category>,
          '/', $puzzle<Puzzle-index>, '/', $collection-filename;

  if $backup-path.IO.e and $collection-path.IO.e and
      $collection-path.IO.modified < $backup-path.IO.modified {
    $backup-path.IO.copy($collection-path);
  }

  elsif $backup-path.IO.e {
    $backup-path.IO.copy($collection-path);
  }
}

#-------------------------------------------------------------------------------
# The object holds most of the fields of a puzzle added with
# the following fields: Puzzle-index, Category and Image (see get-puzzles()
# below) while Name and SourceFile are removed (see add-puzzle-to-table()
# in Table).
method save-progress-file ( Hash $puzzle  ) {

  my $c = $puzzle<Category>;
  my $i = $puzzle<Puzzle-index>;

  my Str $filename = $*puzzle-data<categories>{$c}<members>{$i}<Filename>;
  my Str $collection-filename = [~] '__FSC_', $filename, '_0_.save';
  my Str $collection-path =
     [~] $!config.get-pala-collection, '/', $collection-filename;

  my Str $backup-path = [~] PUZZLE_TABLE_DATA, $puzzle<Category>,
          '/', $puzzle<Puzzle-index>, '/', $collection-filename;

  if $backup-path.IO.e and $collection-path.IO.e and
      $collection-path.IO.modified > $backup-path.IO.modified {
    $collection-path.IO.copy($backup-path)
  }

  elsif $collection-path.IO.e {
    $collection-path.IO.copy($backup-path)
  }
}
}}

#-------------------------------------------------------------------------------
method update-puzzle ( Hash $puzzle --> Hash ) {
  $!current-category{ $puzzle<Puzzle-index>, $puzzle};
}

#-------------------------------------------------------------------------------
method get-password ( --> Str ) {
  $!categories-config<password> // ''
}

#-------------------------------------------------------------------------------
method check-password ( Str $password --> Bool ) {
  my Bool $ok = True;
  $ok = ( sha256-hex($password) eq $!categories-config<password> ).Bool
    if ? $!categories-config<password>;

  $ok
}

#-------------------------------------------------------------------------------
method set-password ( Str $old-password, Str $new-password --> Bool ) {
  my Bool $is-set = False;

  # Return fault when old one is empty while there should be one given.
  return $is-set if $old-password eq '' and ?self.get-password;

  # Check if old password matches before a new one is set
  $is-set = self.check-password($old-password);
  $!categories-config<password> = sha256-hex($new-password) if $is-set;

  $is-set
}

#-------------------------------------------------------------------------------
# Get the category lockable state
method is-category-lockable ( Str:D $category --> Bool ) {
  $!categories-config<categories>{$category}<lockable>.Bool
}

#-------------------------------------------------------------------------------
method set-category-lockable ( Str:D $category, Bool:D $lockable --> Bool ) {
  my Bool $is-set = False;
  if $category ne 'Default' {
    $!categories-config<categories>{$category}<lockable> = $lockable;
    $is-set = True;
  }

  $is-set
}

#-------------------------------------------------------------------------------
# Get the puzzle table locking state
method is-locked ( --> Bool ) {
  ? $!categories-config<locked>.Bool;
}

#-------------------------------------------------------------------------------
# Set the puzzle table locking state
method lock ( ) {
  $!categories-config<locked> = True;
}

#-------------------------------------------------------------------------------
# Reset the puzzle table locking state
method unlock ( Str $password --> Bool ) {
  my Bool $ok = self.check-password($password);
  $!categories-config<locked> = False if $ok;
  $ok
}

