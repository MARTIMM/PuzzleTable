use v6.d;

use YAMLish;
use Digest::SHA256::Native;

#use PuzzleTable::Types;
use PuzzleTable::Config::Puzzle;
use PuzzleTable::Config::Category;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Categories:auth<github:MARTIMM>;

has Str $!root-dir;
has Str $.config-path;
has Hash $.categories-config;
has PuzzleTable::Config::Category $!current-category;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$!root-dir ) {

  $!config-path = "$!root-dir/categories.yaml";
  if $!config-path.IO.r {
    $!categories-config = load-yaml($!config-path.IO.slurp);
  }

  else {
    $!categories-config<categories><Default> = %(:!lockable);

    $!categories-config<password> = '';

    given $!categories-config<palapeli><Flatpak> {
      .<collection> = '.var/app/org.kde.palapeli/data/palapeli/collection';
      .<exec> = "/usr/bin/flatpak run --filesystem={$!root-dir.IO.absolute}:ro --branch=stable --arch=x86_64 --command=palapeli --file-forwarding org.kde.palapeli";
    }

    given $!categories-config<palapeli><Snap> {
      .<collection> = 'snap/palapeli/current/.local/share/palapeli/collection';
      .<exec> = '/var/lib/snapd/snap/bin/palapeli';
      .<env> = %(
        :BAMF_DESKTOP_FILE_HINT</var/lib/snapd/desktop/applications/palapeli_palapeli.desktop>,
        :GDK_BACKEND<x11>,
      )
    }

    given $!categories-config<palapeli><Standard> {
      .<collection> = '.local/share/palapeli/collection';
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

  # Default width and height of displayed puzzle image
  $!categories-config<puzzle-image-width> = 300;
  $!categories-config<puzzle-image-height> = 300;
}

#-------------------------------------------------------------------------------
# Called after adding, removing, or other changes are made on a category
method save-categories-config ( ) {
  my $t0 = now;

  # Save categories config
  $!config-path.IO.spurt(save-yaml($!categories-config));

  # Also save puzzle data of current category
  $!current-category.save-category-config;

  #note "Done saving categories";
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
    mkdir $!root-dir ~ $category-name, 0o700;
  }

  $message
}

#-------------------------------------------------------------------------------
method move-category ( $cat-from, $cat-to ) {
  $!categories-config<categories>{$cat-to} =
    $!categories-config<categories>{$cat-from}:delete;

  my Str $dir-from = $!root-dir ~ $cat-from;
  my Str $dir-to = $!root-dir ~ $cat-to;
  $dir-from.IO.rename( $dir-to, :createonly);
}

#-------------------------------------------------------------------------------
method select-category ( Str:D $category-name is copy --> Str ) {
  my Str $message = '';
  $category-name .= tc;

  if $!categories-config<categories>{$category-name}:exists {
    # Save category before assigning a new
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
method set-palapeli-preference ( Str $preference ) {
  note "Flatpak does not seem to b able to start - set to 'Standard'"
       if $preference eq 'Flatpak';

  if $preference ~~ any(<Snap Flatpak Standard>) {
#  if $preference ~~ any(<Snap Standard>) {
    $!categories-config<palapeli><preference> = $preference;
  }

  else {
    $!categories-config<palapeli><preference> = 'Standard';
  }
}

#-------------------------------------------------------------------------------
method get-palapeli-preference ( --> Str ) {
  $!categories-config<palapeli><preference>
}

#-------------------------------------------------------------------------------
method set-palapeli-image-size ( Int() $width, Int() $height ) {
  $!categories-config<puzzle-image-width> = $width;
  $!categories-config<puzzle-image-height> = $height;
}

#-------------------------------------------------------------------------------
method get-palapeli-image-size ( --> List ) {
  $!categories-config<puzzle-image-width>,
  $!categories-config<puzzle-image-height>
}

#-------------------------------------------------------------------------------
method get-palapeli-collection ( --> Str ) {
  my $preference = $!categories-config<palapeli><preference>;
  $!categories-config<palapeli>{$preference}<collection>
}

#-------------------------------------------------------------------------------
# This puzzle hash must have the extra fields added by get-puzzles
method run-palapeli ( Hash $puzzle --> Str ) {

  # Get the preference of one of the palapeli installations
  my Str $pref = $!categories-config<palapeli><preference>;

  # Set the environment values if any
  for $!categories-config<palapeli>{$pref}<env>.kv -> $env-key, $env-val {
    %*ENV{$env-key} = $env-val;
  }


  # Get executable program
  my Str $exec = $!categories-config<palapeli>{$pref}<exec>;

  my Str $puzzle-id = $puzzle<PuzzleID>;
  my Str $puzzle-path = [~]
    $*CWD, '/', $!current-category.get-puzzle-destination($puzzle-id),
    '/', $puzzle<Filename>;

  # If $puzzle<ProgressFile> is not defined yet, set the name.
  $puzzle<ProgressFile> = [~] '__FSC_', $puzzle<Filename>, '_0_.save'
    unless ?$puzzle<ProgressFile>;

  # Get path to the local progress file (backup)
  my Str $prog-backup-filename = $puzzle<ProgressFile>;
  my Str $prog-backup-path = [~]
    $!current-category.get-puzzle-destination($puzzle-id),
    '/', $prog-backup-filename;

  # Get path to progress file in the palapeli collection directory
  my $coll-filename = [~]
    $*HOME, '/', $!categories-config<palapeli>{$pref}<collection>,
            '/', $prog-backup-filename;

  # Copy the file to the collection dir if local backup exists and if
  # collection file exists, compair modification dates.
  if $prog-backup-path.IO.r and $coll-filename.IO.r and
    $prog-backup-path.IO.modified > $coll-filename.IO.modified
  {
    $prog-backup-path.IO.copy($coll-filename);
  }

  elsif $prog-backup-path.IO.r {
    $prog-backup-path.IO.copy($coll-filename);
  }

  # Now start the puzzle, program will freeze!
note "$exec $puzzle-path";
  shell "$exec \@\@u $puzzle-path \@\@";

  # Just starting and stopping does not create a progress file, so test
  # for its existence before copying it back to its local place.
  my Str $progress = '';
  if $coll-filename.IO.r {
    $coll-filename.IO.copy($prog-backup-path);

    # And set the progress too
    $progress = PuzzleTable::Config::Puzzle.new.calculate-progress(
      $prog-backup-path, $puzzle<PieceCount>
    );

    # Update the puzzle for its progress
    $!current-category.update-puzzle( $puzzle-id, %( :Progress($progress) ));
  }

  $progress
}

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

