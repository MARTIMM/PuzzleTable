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
    $!categories-config = %();
    $!categories-config<categories> = %();
    $!categories-config<categories><Default> = %(:!lockable);
  }

  $!categories-config<locked> = True;
  $!categories-config<password> = '';
  
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
    $!current-category.add-puzzle($puzzle-path);
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

#`{{
#-------------------------------------------------------------------------------
method get-puzzle ( Str:D $puzzle-id --> Hash ) {
  my Str $message = '';

  if ! $!current-category.get-puzzle($puzzle-id) {
    $message = 'Puzzle id is wrong and/or Puzzle store not found';
  }

  $message
}
}}

#-------------------------------------------------------------------------------
# Return an array of hashes. Basic info comes from
# $*puzzle-data<categories>{$category}<members> where info of Image and the
# index of the puzzle is added.
method get-puzzles ( --> Seq ) {

  my Str $pi;
  my Int $found-count = 0;
  my Array $cat-puzzle-data = [];

  for $!current-category.get-puzzle-ids -> $puzzle-id {
    my Hash $puzzle-data = $!current-category.get-puzzle($puzzle-id);

    $puzzle-data<Puzzle-index> = $puzzle-id;
    $puzzle-data<Category> = $!current-category.category-name;
    $puzzle-data<Image> = 
      $!current-category.get-puzzle-destination($puzzle-id) ~ 'image400.jpg';
    $cat-puzzle-data.push: $puzzle-data;
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

