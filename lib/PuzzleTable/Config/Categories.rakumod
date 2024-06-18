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

    # Default width and height of displayed puzzle image
    $!categories-config<puzzle-image-width> = 300;
    $!categories-config<puzzle-image-height> = 300;

    self.save-categories-config;
  }

  # Always lock at start
  $!categories-config<locked> = True;

  # Always select the default category
  $!current-category .= new( :category-name('Default'), :$!root-dir);
}

#-------------------------------------------------------------------------------
# Called after adding, removing, or other changes are made on a category
method save-categories-config ( ) {
#  my $frame = callframe(1);
#  note "$?LINE Called from {$frame.file}:{$frame.line}.";

  my $t0 = now;

  # Save categories config
  $!config-path.IO.spurt(save-yaml($!categories-config));

  # Also save puzzle data of current category
#  $!current-category.save-category-config;

  #note "Done saving categories";
  note "Time needed to save categories: {(now - $t0).fmt('%.1f sec')}."
       if $*verbose-output;
}

#-------------------------------------------------------------------------------
# TODO check in subcats too. dir names are still on same level =>
# all cats are unique
# TODO add in subcats? or move afterwards
method add-category (
  Str:D $category-name is copy, Str :$category-container-name is copy = '',
  :$lockable = False --> Str
) {
  my Str $message = '';
  $category-name .= tc;

  if $!categories-config<categories>{$category-name}:exists {
    $message = "Category $category-name already exists";
  }

  else {
    $!categories-config<categories>{$category-name}<lockable> = $lockable;
    self.save-categories-config;
    mkdir $!root-dir ~ $category-name, 0o700;
  }

  $message
}

#-------------------------------------------------------------------------------
method move-category ( $cat-from, $cat-to ) {
  $!categories-config<categories>{$cat-to} =
    $!categories-config<categories>{$cat-from}:delete;

  self.save-categories-config;

#  $!categories-config<categories><name> = $cat-to;

  my Str $dir-from = $!root-dir ~ $cat-from;
  my Str $dir-to = $!root-dir ~ $cat-to;
  $dir-from.IO.rename( $dir-to, :createonly);
}

#-------------------------------------------------------------------------------
method select-category (
  Str:D $cat-name, Str :$category-container-name is copy = '' --> Str
) {
  my Str $message = '';
  my Str $category-name = $cat-name.tc;
  $category-container-name = $category-container-name.tc ~ '_EX_'
      if ? $category-container-name;

  if ? $category-container-name and
     $!categories-config<categories>{$category-container-name}{$category-name}:exists
  {
    $!current-category .= new(
      :$category-name, :$category-container-name, :$!root-dir
    );
  }

  elsif $!categories-config<categories>{$category-name}:exists {
    # Set to new category
    $!current-category .= new( :$category-name, :$!root-dir);
  }

  else {
    $message = "Category $category-name does not exist";
  }

  $message
}

#-------------------------------------------------------------------------------
method get-categories (
  Str :$filter, Str :$category-container-name is copy = '' --> Seq
) {
  my Bool $locked = self.is-locked;
  $category-container-name = $category-container-name.tc ~ '_EX_'
     if ? $category-container-name;

  my @cat-key-list;
  if ? $category-container-name {
    @cat-key-list =
      $!categories-config<categories>{$category-container-name}.keys;
  }

  else {
    @cat-key-list = $!categories-config<categories>.keys;
  }

  my @cat = ();
  for @cat-key-list -> $category {
    given $filter {
      when 'default' {
        next if $category eq 'Default';
      }

      when 'lockable' {
        next if $locked and
                self.is-category-lockable( $category, $category-container-name);
      }
    }

    @cat.push: $category;
  }

  @cat.sort
}

#-------------------------------------------------------------------------------
method group-in-subcategory (
  Str $category-container-name is copy, Str $cat-name
) {
  my Str $category-name = $cat-name.tc;
  $category-container-name = $cat-container-name.tc ~ '_EX_'
     if ? $category-container-name;

  # Only move category when name is not in the subcategory
  #TODO when cats are unique everywhere then test is not needed
  my Hash $categories := $!categories-config<categories>;
  if $categories{$category-name}:exists
     and $categories{$category-container-name}{$category-name}:!exists
  {
#    $categories{$category-container-name} = %()
#      unless $categories{$category-container-name}:exists;

    $categories{$category-container-name}{$category-name} =
      $categories{$category-name}:delete;

    self.save-categories-config;
  }
}

#-------------------------------------------------------------------------------
method ungroup-in-subcategory ( Str $cat-container-name, Str $cat-name ) {
  my Str $category-name = $cat-name.tc;
  my Str $category-container-name = $cat-container-name.tc ~ '_EX_';
  my Hash $categories := $!categories-config<categories>;

  # Only move back when name in subcat is not in cat
  #TODO when cats are unique everywhere then test is not needed
  if $categories{$category-container-name}{$category-name}:exists
     and $categories{$category-name}:!exists
  {
    # Move category out of subcategory
    $categories{$category-name} =
      $categories{$category-container-name}{$category-name}:delete;

#    # Delete subcategory when empty
#    $categories{$category-container-name}:delete
#      unless ? $categories{$category-container-name};

    self.save-categories-config;
  }
}

#-------------------------------------------------------------------------------
method get-current-category ( --> Str ) {
  $!current-category.category-name;
}

#-------------------------------------------------------------------------------
method get-category-status (
  Str $cat-name, Str $cat-container-name = '' --> Array
) {
  my Str $category-name = $cat-name.tc;
  my Str $category-container-name = $cat-container-name.tc ~ '_EX_';
  my Array $cat-status = [ 0, 0, 0, 0];
  my Hash $categories := (?$cat-container-name
    ?? $!categories-config<categories>{$category-container-name}
    !! $!categories-config<categories>);

  if $categories{$category-name}<status>:exists {
    $cat-status = $categories{$category-name}<status>;
  }

  else {
    my PuzzleTable::Config::Category $category .= new(
      :$category-name, :$!root-dir
    );

    for $category.get-puzzle-ids -> $puzzle-id {
      my Hash $puzzle-config = $category.get-puzzle($puzzle-id);

      # Test for old version data
      my Num() $progress;
      if $puzzle-config<Progress> ~~ Hash {
        $progress =
          $puzzle-config<Progress>{$puzzle-config<Progress>.keys[0]} // 0e0;
      }

      else {
        $progress = $puzzle-config<Progress> // 0e0;
      }

      $cat-status[0]++;
      $cat-status[1]++ if $progress == 0e0;
      $cat-status[2]++ if 0e0 < $progress < 1e2;
      $cat-status[3]++ if $progress == 1e2;
    }

    $categories{$category-name}<status> = $cat-status;
    self.save-categories-config;
  }

  $cat-status
}

#-------------------------------------------------------------------------------
method update-category-status ( ) {
  my Array $cat-status = [ 0, 0, 0, 0];

  for $!current-category.get-puzzle-ids -> $puzzle-id {
    my Hash $puzzle-config = $!current-category.get-puzzle($puzzle-id);

    # Test for old version data
    my Num() $progress;
    if $puzzle-config<Progress> ~~ Hash {
      $progress =
        $puzzle-config<Progress>{$puzzle-config<Progress>.keys[0]} // 0e0;
    }

    else {
      $progress = $puzzle-config<Progress> // 0e0;
    }

    $cat-status[0]++;
    $cat-status[1]++ if $progress == 0e0;
    $cat-status[2]++ if 0e0 < $progress < 1e2;
    $cat-status[3]++ if $progress == 1e2;
  }

  my Str $category-name = $!current-category.category-name;
  my Str $container-name = $!current-category.category-container-name;
note "$?LINE $category-name, $container-name";

  if ? $container-name {
    $!categories-config<categories>{$container-name}{$category-name}<status> =
      $cat-status;
  }

  else {
    $!categories-config<categories>{$category-name}<status> = $cat-status;
  }

  self.save-categories-config;
}

#-------------------------------------------------------------------------------
method import-collection ( Str:D $collection-path --> Str ) {
  my Str $message = '';

  if $collection-path.IO.d {
    $!current-category.import-collection($collection-path);
    self.update-category-status;
    self.save-categories-config;
  }

  else {
    $message = 'Collection path does not exist or isn\'t a directory';
  }

  $message
}

#`{{
#-------------------------------------------------------------------------------
multi method add-puzzle ( Str $category, Str:D $puzzle-path --> Str ) {
  my PuzzleTable::Config::Category $c .=
     new( :category-name($category // 'Default'), :$!root-dir);

  self.select-category($category // 'Default');
  $!current-category.add-puzzle($puzzle-path) if $puzzle-path.IO.r;
}
}}

#-------------------------------------------------------------------------------
#multi method add-puzzle ( Str:D $puzzle-path --> Str ) {
method add-puzzle ( Str:D $puzzle-path --> Str ) {
  my Str $message = '';

  if $puzzle-path.IO.r {
    my Str $puzzle-id = $!current-category.add-puzzle($puzzle-path);
    self.update-category-status;
    self.save-categories-config;
  }

  else {
    $message = 'Puzzle does not exist or isn\'t a puzzle file';
  }

  $message
}

#-------------------------------------------------------------------------------
method move-puzzle ( Str $to-cat, Str:D $puzzle-id ) {

  # Init the categories initialized
  my PuzzleTable::Config::Category $c-from = $!current-category;

  my PuzzleTable::Config::Category $c-to .=
     new( :category-name($to-cat), :$!root-dir);

  # Get path of puzzle where the puzzle is now
  my Str $puzzle-source = $c-from.get-puzzle-destination($puzzle-id);

  # Get a new id for the puzzle in the destination category
  my Str $new-puzzle-id = $c-to.new-puzzle-id;
  # Get path of puzzle where the puzzle must go
  my Str $puzzle-destination = $c-to.get-puzzle-destination($new-puzzle-id);

#note "$?LINE rename $puzzle-source to $puzzle-destination";

  # Rename the file to the new location
  $puzzle-source.IO.rename( $puzzle-destination, :createonly);

  # Get the puzzle config and remove it from source category config
  my Hash $puzzle-config = $c-from.get-puzzle( $puzzle-id, :delete);

  # Set the puzzle config in the destination category config
  $c-to.set-puzzle( $new-puzzle-id, $puzzle-config);

  # Update overall status info
  self.update-category-status;

  # Save and categories
  $c-from.save-category-config;
  $c-to.save-category-config;
}

#-------------------------------------------------------------------------------
method remove-puzzle ( Str:D $puzzle-id, Str:D $archive-trashbin --> Str ) {
  my Str $message = '';

  if ! $!current-category.remove-puzzle( $puzzle-id, $archive-trashbin) {
    $message = 'Puzzle id is wrong and/or Puzzle store not found';
  }

  else {
    self.update-category-status;
    self.save-categories-config;
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
method get-puzzle-image ( Str $category-name --> Str ) {

  my PuzzleTable::Config::Category $category .= new(
    :$category-name, :$!root-dir
  );

  my Str $puzzle-id = $category.get-puzzle-ids.roll;
  return Str unless ?$puzzle-id;

  # Return path to image
  $!root-dir ~ "$category-name/$puzzle-id/image400.jpg"
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
    $puzzle-config<Category-Container> =
      $!current-category.category-container-name;
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
  if $preference ~~ any(<Snap Flatpak Standard>) {
    $!categories-config<palapeli><preference> = $preference;
  }

  else {
    $!categories-config<palapeli><preference> = 'Standard';
  }

  self.save-categories-config;
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

note "\n$?LINE Error missing \$puzzle-id: Hash = $puzzle.gist()"
unless ? $puzzle<PuzzleID>;
  my Str $puzzle-id = $puzzle<PuzzleID>;
  my Str $puzzle-path = [~]
    $!current-category.get-puzzle-destination($puzzle-id),
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

  # Now start the puzzle, program will freeze! use :err to hide all errors like
  # 'qt.qpa.wayland: Setting cursor position is not possible on wayland'.
  # TODO maybe use Proc::Async, it then needs to know where it ends and how
  # to update the progress
  my Proc $p = shell "$exec '$puzzle-path'", :err;
  $p.err.close;

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

    # Update the category status
    self.update-category-status;
    self.save-categories-config;
  }

  $progress
}

#-------------------------------------------------------------------------------
method update-puzzle ( Hash $puzzle ) {
  $!current-category.update-puzzle( $puzzle<PuzzleID>, $puzzle);
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
  if $is-set {
    $!categories-config<password> = sha256-hex($new-password);
    self.save-categories-config;
  }

  $is-set
}

#-------------------------------------------------------------------------------
# Get the category lockable state
method is-category-lockable (
  Str:D $category, Str $container-name = '' --> Bool
) {
  my Hash $c := $!categories-config<categories>;
  if ? $container-name {
    if $container-name ~~ m/ '_EX_' $/ {
      $c{$container-name}{$category}<lockable>.Bool
    }

    else {
      $c{$container-name ~ '_EX_'}{$category}<lockable>.Bool
    }
  }

  else {
    $c{$category}<lockable>.Bool
  }
}

#-------------------------------------------------------------------------------
method set-category-lockable ( Str:D $category, Bool:D $lockable --> Bool ) {
  my Bool $is-set = False;
  if $category ne 'Default' {
    $!categories-config<categories>{$category}<lockable> = $lockable;
    self.save-categories-config;
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
  self.save-categories-config;
}

#-------------------------------------------------------------------------------
# Reset the puzzle table locking state
method unlock ( Str $password --> Bool ) {
  my Bool $ok = self.check-password($password);
  $!categories-config<locked> = False if $ok;
  self.save-categories-config;
  $ok
}

