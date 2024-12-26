use v6.d;

use YAMLish;
use Digest::SHA256::Native;

#use PuzzleTable::Types;
use PuzzleTable::Config::Puzzle;
use PuzzleTable::Config::Category;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Categories:auth<github:MARTIMM>;

has Hash $!config-paths = %();
has Hash $.categories-config = %();
has PuzzleTable::Config::Category $!current-category;
has #`{{PuzzleTable::Config}} $!config;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$root-dir, :$!config ) {
  self.load-category-config($root-dir);
}

#-------------------------------------------------------------------------------
method load-category-config ( Str:D $root-dir is copy ) {
  $root-dir ~= '/' unless $root-dir ~~ m/ \/ $/;
note "\n$?LINE $root-dir, ", $!config-paths{$root-dir}:exists;

  if $!config-paths{$root-dir}:!exists {
    $!config-paths{$root-dir} = "$root-dir/categories.yaml";

    if $!config-paths{$root-dir}.IO.r {
      $!categories-config{$root-dir} =
        load-yaml($!config-paths{$root-dir}.IO.slurp);
    }

    else {
      $!categories-config{$root-dir}<Default_EX_><categories><Default> =
        %(:!lockable);
    }
  }

  # Always select the default category in the default container of
  # the current root directory
  $!current-category .= new(
    :category-name('Default'), :container('Default'), :$root-dir
  );

#for $!categories-config.keys -> $root-dir {
#note "\n$?LINE $root-dir\n$!categories-config{$root-dir}.gist()";
#}
}

#-------------------------------------------------------------------------------
# Method to add another root where table data is found. It is created when
# it not exists. Also the default container and category is created (both
# called Default).
method add-table-root ( Str $root-dir ) {
  self.load-category-config($root-dir);
}

#-------------------------------------------------------------------------------
method get-roots ( --> Seq ) {
  $!categories-config.keys.sort
}

#-------------------------------------------------------------------------------
# Called after adding, removing, or other changes made on a category
method save-categories-config ( ) {

  my $t0 = now;

  # Save categories config
  for $!categories-config.keys -> $root-dir {
#note "$?LINE save to $root-dir";
    $!config-paths{$root-dir}.IO.spurt(
      save-yaml($!categories-config{$root-dir})
    );
  }

  note "Time needed to save categories: ",
       (now - $t0).fmt('%.1f sec.') if $*verbose-output;
}

#-------------------------------------------------------------------------------
method add-category (
  Str:D $category-name is copy, Str:D $container is copy, 
  :$lockable is copy = False, Str :$root-dir is copy
  --> Str
) {
  my Str $message = '';
  $category-name = $category-name.lc.tc;
  $container = $!current-category.set-container-name($container);
  $root-dir //= $!current-category.root-dir;
note "$?LINE $root-dir";
  $!categories-config{$root-dir}{$container}<categories> = %()
      if $!categories-config{$root-dir}{$container}<categories>:!exists;

  my Hash $cats := $!categories-config{$root-dir}{$container}<categories>;
  if $cats{$category-name}:exists {
    $message = "Category $category-name already exists";
  }

  else {
    # Default containers and categories aren't lockable
    $lockable = False
      if $container eq 'Default_EX_' or $category-name eq 'Default';
    $cats{$category-name}<lockable> = $lockable;
#note "$?LINE mkdir '$root-dir$container/$category-name'";
#    mkdir "$root-dir$container/$category-name", 0o700;

    my PuzzleTable::Config::Category $category .= new(
      :$category-name, :$container, :$root-dir
    );
    self.update-category-status(:$category);
    self.save-categories-config;
  }

  $message
}

#-------------------------------------------------------------------------------
method select-category (
  Str:D $category-name is copy, Str:D $container is copy,
  Str :$root-dir is copy --> Str
) {
  my Str $message = '';
  $category-name .= tc;
  $container = $!current-category.set-container-name($container);
  $root-dir //= $!current-category.root-dir;
#note "$?LINE $category-name, $container, $root-dir";

  $!categories-config{$root-dir}{$container}<categories> = %()
      if $!categories-config{$root-dir}{$container}<categories>:!exists;

  my Hash $cats = $!categories-config{$root-dir}{$container}<categories>;
  if $cats{$category-name}:exists {
    $!current-category .= new( :$category-name, :$container, :$root-dir);
  }

  else {
    $message = "Category $category-name does not exist";
  }

  $message
}

#-------------------------------------------------------------------------------
method move-category (
  Str $cat-from is copy, Str:D $cont-from is copy,
  Str $cat-to is copy, Str:D $cont-to is copy
  --> Str
) {
  my Str $message = '';

  $cat-from .= tc;
  $cat-to .= tc;
  $cont-from = $!current-category.set-container-name($cont-from);
  $cont-to = $!current-category.set-container-name($cont-to);
  my Str $root-dir-from = $!current-category.root-dir;
  my Str $root-dir-to = $!current-category.root-dir;

  if $!categories-config{$root-dir-from}{$cont-from}<categories>{$cat-from}:exists and 
     $!categories-config{$root-dir-to}{$cont-to}<categories>{$cat-to}:!exists
  {
    $!categories-config{$root-dir-to}{$cont-to}<categories>{$cat-to} =
      $!categories-config{$root-dir-from}{$cont-from}<categories>{$cat-from}:delete;

    self.save-categories-config;

    # Create category dir if it doesn't exist
    mkdir "$root-dir-to$cont-to", 0o700 unless "$root-dir-to$cont-to".IO.e;

    # Rename source category directory
    my Str $dir-from = "$root-dir-from$cont-from/$cat-from";
    my Str $dir-to = "$root-dir-to$cont-to/$cat-to";
    $dir-from.IO.rename( $dir-to, :createonly);
  }

  elsif $!categories-config{$root-dir-to}{$cont-to}<categories>{$cat-to}:exists {
    $message = 'Destination already exists';
  }

  elsif $!categories-config{$root-dir-from}{$cont-from}<categories>{$cat-from}:!exists {
    $message = 'Source does not exist';
  }

  $message
}

#-------------------------------------------------------------------------------
method delete-category (
  Str:D $category is copy, Str:D $container is copy --> Str
) {
  my Str $message = '';

  $category .= tc;
  $container = $!current-category.set-container-name($container);
  my Str $root-dir = $!current-category.root-dir;

  my Hash $conts := $!categories-config{$root-dir};
  if $conts{$container}:exists {
    if $conts{$container}<categories>{$category}:exists {
      if self.has-puzzles( $category, $container) {
        $message = 'Category still has puzzles';
      }

      else {
        # Remove the category from the container
        $conts{$container}<categories>{$category}:delete;

        # Remove the files and directory, should be empty
        .unlink for dir("$root-dir$container/$category");
        "$root-dir$container/$category".IO.rmdir;

        self.save-categories-config;
      }
    }

    else {
      $message = 'Category does not exist';
    }
  }

  else {
    $message = 'Container does not exist';
  }

  $message
}

#-------------------------------------------------------------------------------
method get-categories ( Str:D $container is copy, Str:D $root-dir --> List ) {
  my Bool $locked = $!config.is-locked;
  $container = $!current-category.set-container-name($container);
#  my Str $root-dir = $!current-category.root-dir;

  my @cat-key-list;
  @cat-key-list =
    $!categories-config{$root-dir}{$container}<categories>.keys.sort;

  my @cat = ();
  for @cat-key-list -> $category {
    next if ( $locked and self.is-category-lockable( $category, $container));
    @cat.push: $category;
  }

  @cat
}

#-------------------------------------------------------------------------------
method get-current-category ( --> Str ) {
  $!current-category.category-name;
}

#-------------------------------------------------------------------------------
method get-current-container ( --> Str ) {
  S/ '_EX_' $// with $!current-category.container
}

#-------------------------------------------------------------------------------
method get-current-root ( --> Str ) {
  S/ '_EX_' $// with $!current-category.root-dir
}

#-------------------------------------------------------------------------------
method get-category-status (
  Str:D $category-name is copy, Str:D $container is copy,
  Str:D $root-dir is copy
  --> Array
) {
  $category-name .= tc;
  $container = $!current-category.set-container-name($container);
  $root-dir //= $!current-category.root-dir;
#note "$?LINE $root-dir $container $category-name";

  # Store 4 numbers: total nbr puzlles, not started, started, finished
  my Array $cat-status = [ 0, 0, 0, 0];

  # initialize if not yet available
  $!categories-config{$root-dir}{$container}<categories> = %()
    if $!categories-config{$root-dir}{$container}<categories>:!exists;

  my Hash $categories :=
     $!categories-config{$root-dir}{$container}<categories>;

#note "$?LINE ", $categories{$category-name}.gist, "\n", $categories{$category-name}<status>:exists;

  if $categories{$category-name}<status>:exists {
    $cat-status = $categories{$category-name}<status>;

    # maybe an update needed when all is 0
    if $cat-status.sum == 0 {
      my PuzzleTable::Config::Category $category .= new(
        :$category-name, :$container, :$root-dir
      );

      self.update-category-status(:$category);
      $cat-status = $categories{$category-name}<status>;
    }
  }

  else {
    my PuzzleTable::Config::Category $category .= new(
      :$category-name, :$container, :$root-dir
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

      $cat-status[0]++;                           # total nbr puzzles
      $cat-status[1]++ if $progress == 0e0;       # puzzles not started
      $cat-status[2]++ if 0e0 < $progress < 1e2;  # puzzles started not finished
      $cat-status[3]++ if $progress == 1e2;       # puzzles finished
    }

    $categories{$category-name}<status> = $cat-status;
    self.save-categories-config;
  }

  $cat-status
}

#-------------------------------------------------------------------------------
method update-category-status (
  PuzzleTable::Config::Category :$category = $!current-category
) {

  # Store 4 numbers: total nbr puzlles, not started, started, finished
  my Array $cat-status = [ 0, 0, 0, 0];

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

  my Str $category-name = $category.category-name;
  my Str $container-name = $category.container;
  my Str $root-dir = $category.root-dir;

  if ? $container-name {
    $!categories-config{$root-dir}{$container-name}<categories>{$category-name}<status> = $cat-status;
  }

  else {
    $!categories-config{$root-dir}{$category-name}<status> = $cat-status;
  }

#note "$?LINE new status ", $cat-status.gist();

  self.save-categories-config;
}

#-------------------------------------------------------------------------------
method get-puzzle ( Str $puzzle-id, Bool :$delete = False --> Hash ) {
  $!current-category.get-puzzle( $puzzle-id, :$delete)
}

#-------------------------------------------------------------------------------
method add-container (
  Str $container is copy = '', Str :$root-dir is copy --> Bool
) {
note "$?LINE $root-dir, $container";
  my Bool $add-ok = False;
  $container = $!current-category.set-container-name($container);
  $root-dir //= $!current-category.root-dir;

  if $!categories-config{$root-dir}{$container}:!exists {
    $!categories-config{$root-dir}{$container} = %(:categories(%()));
    mkdir "$root-dir$container", 0o700 unless "$root-dir$container".IO.e;
    $add-ok = True;

    self.save-categories-config;
  }
  
  $add-ok
}

#-------------------------------------------------------------------------------
method delete-container (
  Str $container is copy = '', Str :$root-dir is copy --> Bool
) {
note "$?LINE $root-dir, $container";
  my Bool $delete-ok = False;
  $container = $!current-category.set-container-name($container);
  $root-dir //= $!current-category.root-dir;

  if $!categories-config{$root-dir}{$container}:exists and
     $!categories-config{$root-dir}{$container}<categories>.elems == 0
  {
    $!categories-config{$root-dir}{$container}:delete;
    self.save-categories-config;
    rmdir "$root-dir$container";
    $delete-ok = True;
  }

  $delete-ok
}

#-------------------------------------------------------------------------------
method get-containers ( Str :$root-dir is copy --> List ) {

  my Bool $locked = $!config.is-locked;
  $root-dir //= $!current-category.root-dir;
  my @containers = ();
#  for $!categories-config.keys.sort -> $root-dir {
    for $!categories-config{$root-dir}.keys.sort -> $container {
      # Containers have an _EX_ extension which is removed
      # Don't include in list if lockable and table is locked
      @containers.push: (S/ '_EX_' $// with $container)
        unless self.has-lockable-categories($container).Bool and $locked;
    }
#  }

  @containers
}

#-------------------------------------------------------------------------------
method is-expanded ( Str:D $container is copy --> Bool ) {
  my Bool $expanded = False;
  $container = $!current-category.set-container-name($container);
  my Str $root-dir = $!current-category.root-dir;

  $expanded = $!categories-config{$root-dir}{$container}<expanded> // False
     if $!categories-config{$root-dir}{$container}:exists;

  $expanded
}

#-------------------------------------------------------------------------------
method set-expand ( Str:D $container is copy, Bool $expanded --> Str ) {
  my Str $message = '';
  $container = $!current-category.set-container-name($container);
  my Str $root-dir = $!current-category.root-dir;

  if $!categories-config{$root-dir}{$container}:exists {
    $!categories-config{$root-dir}{$container}<expanded> = $expanded;
    self.save-categories-config;
  }

  else {
    $message = 'Container does not exist';
  }

  $message
}

#-------------------------------------------------------------------------------
# Method to check if container needs to be hidden
method has-lockable-categories ( Str $container is copy = '' --> Bool ) {
  my Bool $lockable-categeries = False;
  $container = $!current-category.set-container-name($container);
  my Str $root-dir = $!current-category.root-dir;

  for $!categories-config{$root-dir}{$container}<categories>.keys -> $category
  {
    if self.is-category-lockable( $category, $container) {
      $lockable-categeries = True;
      last
    }
  }

  $lockable-categeries
}

#-------------------------------------------------------------------------------
method import-collection ( Str:D $collection-path --> Str ) {
  my Str $message = '';
  my Str $root-dir = $!current-category.root-dir;

  if $collection-path.IO.d {
    $!current-category.import-collection($collection-path);
    self.update-category-status;
  }

  else {
    $message = 'Collection path does not exist or isn\'t a directory';
  }

  $message
}

#-------------------------------------------------------------------------------
method add-puzzle ( Str:D $puzzle-path --> Str ) {
  my Str $puzzle-id = '';
  my Str $root-dir = $!current-category.root-dir;

  if $puzzle-path.IO.r {
    $puzzle-id = $!current-category.add-puzzle($puzzle-path);
    self.update-category-status;
  }

  $puzzle-id
}

#-------------------------------------------------------------------------------
method move-puzzle (
  Str:D $to-cat is copy, Str:D $to-cont is copy, Str:D $puzzle-id,
  Str :$root-dir-to is copy
) {
  $to-cat .= tc;

  # Init the categories initialized
  my PuzzleTable::Config::Category $c-from = $!current-category;
  my Str $root-dir-from = $!current-category.root-dir;
  $root-dir-to //= $root-dir-from;

  my PuzzleTable::Config::Category $c-to .= new(
    :category-name($to-cat), :container($to-cont), :root-dir($root-dir-to)
  );

  # Get path of puzzle where the puzzle is now
  my Str $puzzle-source = $c-from.get-puzzle-destination($puzzle-id);

  # Get a new id for the puzzle in the destination category
  my Str $new-puzzle-id = $c-to.new-puzzle-id;

  # Get path of puzzle where the puzzle must go
  my Str $puzzle-destination = $c-to.get-puzzle-destination($new-puzzle-id);

  # Rename the file to the new location
  $puzzle-source.IO.rename( $puzzle-destination, :createonly);

  # Get the puzzle config and remove it from source category config
  my Hash $puzzle-config = $c-from.get-puzzle( $puzzle-id, :delete);

  # Set the puzzle config in the destination category config
  $c-to.set-puzzle( $new-puzzle-id, $puzzle-config);

  # Update overall status info
  self.update-category-status;
  self.update-category-status(:category($c-to));

  # Save categories
  $c-from.save-category-config;
  $c-to.save-category-config;
}

#-------------------------------------------------------------------------------
method archive-puzzles (
  Array:D $puzzle-ids, Str:D $archive-trashbin --> List
) {
  my Str $message = '';

  # Returns [ success, archive-name]
  my @ap = $!current-category.archive-puzzles(
    $puzzle-ids, $archive-trashbin
  );
  
  if ? @ap[0] {
    self.update-category-status;
  }

  else {
    $message = 'One of the puzzle ids is wrong and/or puzzle store not found';
  }

  ( $message, @ap[1])
}

#-------------------------------------------------------------------------------
method restore-puzzles (
  Str:D $archive-trashbin, Str:D $archive-name --> Str
) {
  my Str $message = '';

  my Str $category;
  my Str $container;
  ( $, $container, $category) = $archive-name.split(':');
  $container = $container.tc ~ '_EX_'
    if ? $container and $container !~~ m/ '_EX_' $/;

  $category ~~ s/ '.tbz2' $//;


  # Restoring puzzles can be for another category or in the current one
  if $category eq $!current-category.category-name {
    if $!current-category.restore-puzzles(
      $archive-trashbin, $archive-name
    ) {
      self.update-category-status;
    }

    else {
      $message = 'Archive not found or does not have the proper contents';
    }
  }

  else {
    my Str $root-dir = $!current-category.root-dir;
    my PuzzleTable::Config::Category $cat .= new(
      :category-name($category), :$container, :$root-dir
    );

    $message = 'Archive not found or does not have the proper contents'
      unless $cat.restore-puzzles( $archive-trashbin, $archive-name);
  }

  $message
}

#-------------------------------------------------------------------------------
method get-puzzle-image (
  Str $category, Str $container, Str $root-dir is copy --> Str
) {

  $root-dir //= $!current-category.root-dir;
  my PuzzleTable::Config::Category $cat .= new(
    :category-name($category), :$container, :$root-dir
  );

  my Str $puzzle-id = $cat.get-puzzle-ids.roll;
  return Str unless ?$puzzle-id;

  # Return path to image
  $root-dir ~ "{$container}_EX_/$category/$puzzle-id/image400.jpg"
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
    $puzzle-config<Category-Container> = $!current-category.container;
    $puzzle-config<Image> = 
      $!current-category.get-puzzle-destination($puzzle-id) ~ '/image400.jpg';

    # Drop some data
    $puzzle-config<SourceFile>:delete;

    $cat-puzzle-data.push: $puzzle-config;
  }

  # Sort puzzles on its size
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
method has-puzzles (
  Str:D $category is copy, Str:D $container is copy --> Bool
) {
  my Bool $hp = False;
  
  $category .= tc;
  $container = $!current-category.set-container-name($container);
  if $category eq $!current-category.category-name {
    $hp = $!current-category.get-puzzle-ids.elems.Bool;
  }

  else {
    my Str $root-dir = $!current-category.root-dir;
    my PuzzleTable::Config::Category $cat .= new(
      :category-name($category), :$container, :$root-dir
    );
    
    $hp = $cat.get-puzzle-ids.elems.Bool;
  }

  $hp
}

#`{{
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
}}

#-------------------------------------------------------------------------------
# This puzzle hash must have the extra fields added by get-puzzles
method run-palapeli ( Hash $puzzle --> Str ) {

  # Set the environment values if any
  $!config.set-palapeli-env;

  # Get executable program
  my Str $exec = $!config.get-palapeli-exec;

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
    $*HOME, '/', $!config.get-palapeli-collection,
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
  }

  $progress
}

#-------------------------------------------------------------------------------
method update-puzzle ( Hash $puzzle ) {
  $!current-category.update-puzzle( $puzzle<PuzzleID>, $puzzle);
}

#`{{
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
}}

#-------------------------------------------------------------------------------
# Get the category lockable state. Returns undefined when container/category
# is not found.
method is-category-lockable (
  Str:D $category is copy, Str:D $container is copy --> Bool
) {
  my Bool $lockable;

  $category .= tc;
  $container = $!current-category.set-container-name($container);
  my Str $root-dir = $!current-category.root-dir;

  if $!categories-config{$root-dir}{$container}<categories>{$category}:exists {
    $lockable = $!categories-config{$root-dir}{$container}<categories>{$category}<lockable>.Bool;
  }

  $lockable
}

#-------------------------------------------------------------------------------
# Set the category lockable state. Returns undefined when container/category
# is not found.
method set-category-lockable (
  Str:D $category, Str:D $container is copy, Bool:D $lockable
  --> Bool
) {
  my Bool $is-set = False;
  $container = $!current-category.set-container-name($container);
  my Str $root-dir = $!current-category.root-dir;

  # Never any category in the Default container
  if $container ne 'Default_EX_' {
    if $!categories-config{$root-dir}{$container}<categories>{$category}:exists {
      $!categories-config{$root-dir}{$container}<categories>{$category}<lockable> = $lockable;
    }

    self.save-categories-config;
    $is-set = True;
  }

  $is-set
}

#`{{
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
}}
