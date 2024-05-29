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
    $!categories-config = %( :categories(%()) );
  }

  $!categories-config<locked> = True;
  $!categories-config<password> = '';
}

#-------------------------------------------------------------------------------
# Called after adding, removing, or other changes are made on a category
method save-categories-config ( ) {
  my $t0 = now;

  # Save categories config
  $!config-path.IO.spurt(save-yaml($!categories-config));

  # And, if there is a selected category, also save category data
  $!current-category.save-category-config if ? $!current-category;

#  note "Done saving categories";
  note "Time needed to save categories: {(now - $t0).fmt('%.1f sec')}.";
}

#-------------------------------------------------------------------------------
method add-category ( Str:D $name, :$lockable = False --> Str ) {
  my Str $message = '';
  if $!categories-config<categories>{$name}:exists {
    $message = "Category $name already exists";
  }

  else {
    $!categories-config<categories>{$name}<lockable> = $lockable;
  }

  $message
}

#-------------------------------------------------------------------------------
method select-category ( Str:D $category-name --> Str ) {
  my Str $message = '';

  if $!categories-config<categories>{$category-name}:exists {
    # Check if a category was selected. If so, save before assigning a new
    $!current-category.save-category-config if ? $!current-category;

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
  my Str $category-name;
  $category-name = $!current-category.category-name if ? $!current-category;

  $category-name
}

#-------------------------------------------------------------------------------
method import-collection ( Str:D $collection-path --> Str ) {
  my Str $message = '';

  if ? $!current-category {
    if $collection-path.IO.d {
      $!current-category.import-collection($collection-path);
    }

    else {
      $message = 'Collection path does not exist or isn\'t a directory';
    }
  }

  else {
    $message = 'No collection selected';
  }

  $message
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

#  self.save-categories-config if $is-set;
  $is-set
}

#-------------------------------------------------------------------------------
# Get the category lockable state
method is-category-lockable ( Str:D $category --> Bool ) {
  $!categories-config<categories>{$category}<lockable>.Bool
}

#-------------------------------------------------------------------------------
method set-category-lockable ( Str:D $category, Bool:D $lockable ) {
  $!categories-config<categories>{$category}<lockable> = $lockable;
#  self.save-categories-config;
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
#  self.save-categories-config;
}

#-------------------------------------------------------------------------------
# Reset the puzzle table locking state
method unlock ( Str $password --> Bool ) {
  my Bool $ok = self.check-password($password);
  $!categories-config<locked> = False if $ok;
#  self.save-categories-config;
  $ok
}

