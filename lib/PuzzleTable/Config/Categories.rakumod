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
    $!categories-config<containers><Default_EX_><categories><Default> = %(:!lockable);

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
  $!current-category .= new(
    :category-name('Default'), :container(''), :$!root-dir
  );
  self.update-category-status;
}

#-------------------------------------------------------------------------------
# Called after adding, removing, or other changes are made on a category
method save-categories-config ( ) {

  my $t0 = now;

  # Save categories config
  $!config-path.IO.spurt(save-yaml($!categories-config));

  note "Time needed to save categories: {(now - $t0).fmt('%.1f sec')}."
       if $*verbose-output;
}

#-------------------------------------------------------------------------------
# $category-container can be one of '', '--', '...' or '..._EX_'
#
method add-category (
  Str:D $category-name is copy, Str:D $container is copy, 
  :$lockable is copy = False
  --> Str
) {
  my Str $message = '';
  $category-name .= tc;
  $container = $!current-category.set-container-name($container);

  my Hash $cats := $!categories-config<containers>;
  if $cats{$container}<categories>{$category-name}:exists {
    $message = "Category $category-name already exists";
  }

  else {
    $lockable = False if $container eq 'Default_EX_';
    $cats{$container}<categories>{$category-name}<lockable> = $lockable;
    mkdir "$!root-dir$container/$category-name", 0o700;

    my PuzzleTable::Config::Category $category .= new(
      :$category-name, :$container, :$!root-dir
    );
    self.update-category-status(:$category);
    self.save-categories-config;
  }

  $message
}

#-------------------------------------------------------------------------------
method select-category (
  Str:D $category-name is copy, Str:D $container is copy --> Str
) {
  my Str $message = '';
  $category-name .= tc;
  $container = $!current-category.set-container-name($container);

  my Hash $cats := $!categories-config<containers>;
  if $cats{$container}<categories>{$category-name}:exists {
    $!current-category .= new( :$category-name, :$container, :$!root-dir);
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

  my Hash $cats := $!categories-config<containers>;
  
  if $cats{$cont-from}<categories>{$cat-from}:exists and 
     $cats{$cont-to}<categories>{$cat-to}:!exists
  {
    $cats{$cont-to}<categories>{$cat-to} =
      $cats{$cont-from}<categories>{$cat-from}:delete;

    self.save-categories-config;

    my Str $dir-from = "$!root-dir$cont-from/$cat-from";
    my Str $dir-to = "$!root-dir$cont-to/$cat-to";
    mkdir "$!root-dir$cont-to", 0o700 unless "$!root-dir$cont-to".IO.e;
    $dir-from.IO.rename( $dir-to, :createonly);
  }

  elsif $cats{$cont-to}<categories>{$cat-to}:exists {
    $message = 'Destination already exists';
  }

  elsif $cats{$cont-from}<categories>{$cat-from}:!exists {
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

  my Hash $conts := $!categories-config<containers>;
  if $conts{$container}:exists {
    if $conts{$container}<categories>{$category}:exists {
      if self.has-puzzles( $category, $container) {
        $message = 'Category still has puzzles';
      }

      else {
        # Remove the category from the container
        $conts{$container}<categories>{$category}:delete;

        # Remove the files and directory, should be empty
        .unlink for dir("$!root-dir$container/$category");
        "$!root-dir$container/$category".IO.rmdir;

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
method get-categories ( Str:D $container is copy --> Seq ) {
  my Bool $locked = self.is-locked;
  $container = $!current-category.set-container-name($container);

  my @cat-key-list;
  @cat-key-list = $!categories-config<containers>{$container}<categories>.keys;

  my @cat = ();
  for @cat-key-list -> $category {
    next if ( $locked and self.is-category-lockable( $category, $container));

    @cat.push: $category;
  }

  @cat.sort
}

#`{{
#-------------------------------------------------------------------------------
method group-in-subcategory (
  Str:D $category-container is copy, Str:D $category-name is copy
) {
  $category-name .= tc;
  $category-container = $category-container.tc ~ '_EX_'
     if ? $category-container and $category-container !~~ m/ '_EX_' $/;

  # Only move category when name is not in the subcategory
  #TODO when cats are unique everywhere then test is not needed
  my Hash $categories := $!categories-config<containers>;
  if $categories{$category-name}:exists
     and $categories{$category-container}{$category-name}:!exists
  {
    $categories{$category-container}<categories>{$category-name} =
      $categories{$category-name}:delete;

    self.save-categories-config;
  }
}

#-------------------------------------------------------------------------------
method ungroup-from-subcategory (
  Str $category-container is copy, Str $category-name is copy
) {
  $category-name .= tc;
  $category-container = $category-container.tc ~ '_EX_'
     if ? $category-container and $category-container !~~ m/ '_EX_' $/;

  # Only move back when name in subcat is not in cat
  #TODO when cats are unique everywhere then test is not needed
  my Hash $categories := $!categories-config<containers>;
  if $categories{$category-container}<categories>{$category-name}:exists
     and $categories{$category-name}:!exists
  {
    # Move category out of subcategory
    $categories{$category-name} =
      $categories{$category-container}<categories>{$category-name}:delete;

    self.save-categories-config;
  }
}
}}

#-------------------------------------------------------------------------------
method get-current-category ( --> Str ) {
  $!current-category.category-name;
}

#-------------------------------------------------------------------------------
method get-current-container ( --> Str ) {
  S/ '_EX_' $// with $!current-category.container
}

#-------------------------------------------------------------------------------
method get-category-status (
  Str $category-name is copy, Str:D $container is copy --> Array
) {
  $category-name .= tc;
  $container = $!current-category.set-container-name($container);
  my Array $cat-status = [ 0, 0, 0, 0];

  my Hash $categories :=
     $!categories-config<containers>{$container}<categories>;

  if $categories{$category-name}<status>:exists {
    $cat-status = $categories{$category-name}<status>;
  }

  else {
    my PuzzleTable::Config::Category $category .= new(
      :$category-name, :$container, :$!root-dir
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
  PuzzleTable::Config::Category :$category = $!current-category ) {
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

  if ? $container-name {
    $!categories-config<containers>{$container-name}<categories>{$category-name}<status> = $cat-status;
  }

  else {
    $!categories-config<containers>{$category-name}<status> = $cat-status;
  }

  self.save-categories-config;
}

#-------------------------------------------------------------------------------
method get-puzzle ( Str $puzzle-id, Bool :$delete = False --> Hash ) {
  $!current-category.get-puzzle( $puzzle-id, :$delete)
}

#`{{
#-------------------------------------------------------------------------------
method find-container ( Str:D $category-name is copy --> Str ) {
  $category-name .= tc;

  my Hash $cats := $!categories-config<containers>;
  my Str $container;
  for $cats.keys -> $cat {
    if $cat ~~ m/ '_EX_' $/ {
      for $cats{$cat}<categories>.keys -> $subcat {
        if $category-name eq $subcat {
          $container = S/ '_EX_' $// with $cat;
          last;
        }
      }
    }

    elsif $category-name eq $cat {
      $container = $!current-category.container;
      last;
    }
  }

  # If undefined, the $category-name is not found
  $container
}
}}

#-------------------------------------------------------------------------------
method add-container ( Str $container is copy = '' --> Bool ) {
  my Bool $add-ok = True;
  $container = $!current-category.set-container-name($container);

  if $!categories-config<containers>{$container}:exists {
    $add-ok = False;
  }

  else {
    $!categories-config<containers>{$container} = %(:categories(%()));

  }
  
  $add-ok
}

#-------------------------------------------------------------------------------
method delete-container ( Str $container is copy = '' --> Bool ) {
  my Bool $delete-ok = False;
  $container = $!current-category.set-container-name($container);

  if $!categories-config<containers>{$container}:exists and
     $!categories-config<containers>{$container}<categories>.elems == 0
  {
    $!categories-config<containers>{$container}:delete;
    self.save-categories-config;
    rmdir "$!root-dir$container";
    $delete-ok = True;
  }

  $delete-ok
}

#-------------------------------------------------------------------------------
method get-containers ( --> Seq ) {

  my Bool $locked = self.is-locked;
  my @containers = ();
  my Bool $lockable = False;
  for $!categories-config<containers>.keys -> $cat {

    # If extension _EX_ is added then it is a container
    if $cat ~~ m/ '_EX_' $/ {
      $lockable = self.has-lockable-categories($cat);
      (@containers.push: S/ '_EX_' $// with $cat) unless $lockable and $locked;
    }
  }

  # Sort containers
  @containers.sort
}

#-------------------------------------------------------------------------------
method is-expanded ( Str:D $container is copy --> Bool ) {
  my Bool $expanded = False;
  $container = $!current-category.set-container-name($container);
  $expanded = $!categories-config<containers>{$container}<expanded> // False
     if $!categories-config<containers>{$container}:exists;

  $expanded
}

#-------------------------------------------------------------------------------
method set-expand ( Str:D $container is copy, Bool $expanded --> Str ) {
  my Str $message = '';

  $container = $!current-category.set-container-name($container);
  
  if $!categories-config<containers>{$container}:exists {
    $!categories-config<containers>{$container}<expanded> = $expanded;
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

  for $!categories-config<containers>{$container}<categories>.keys -> $category
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

  if $collection-path.IO.d {
    $!current-category.import-collection($collection-path);
    self.update-category-status;
#    self.save-categories-config;
  }

  else {
    $message = 'Collection path does not exist or isn\'t a directory';
  }

  $message
}

#-------------------------------------------------------------------------------
method add-puzzle ( Str:D $puzzle-path --> Str ) {

  my Str $puzzle-id = '';
  if $puzzle-path.IO.r {
    $puzzle-id = $!current-category.add-puzzle($puzzle-path);
    self.update-category-status;
  }

  $puzzle-id
}

#-------------------------------------------------------------------------------
method move-puzzle (
  Str $to-cat is copy, Str:D $to-cont is copy, Str:D $puzzle-id
) {
  $to-cat .= tc;

  # Init the categories initialized
  my PuzzleTable::Config::Category $c-from = $!current-category;
  my PuzzleTable::Config::Category $c-to .= new(
    :category-name($to-cat), :container($to-cont), :$!root-dir
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
  my @ap = $!current-category.archive-puzzles( $puzzle-ids, $archive-trashbin);
  if ! @ap[0] {
    $message = 'One of the puzzle ids is wrong and/or puzzle store not found';
  }

  else {
    self.update-category-status;
#    self.save-categories-config;
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
    $message = 'Archive not found or does not have the proper contents'
      unless $!current-category.restore-puzzles(
        $archive-trashbin, $archive-name
      );
  }

  else {
    my PuzzleTable::Config::Category $cat .= new(
      :category-name($category), :$container, :$!root-dir
    );

    $message = 'Archive not found or does not have the proper contents'
      unless $cat.restore-puzzles( $archive-trashbin, $archive-name);
  }

  $message
}

#-------------------------------------------------------------------------------
method get-puzzle-image ( Str $category, Str $container --> Str ) {

  my PuzzleTable::Config::Category $cat .= new(
    :category-name($category), :$container, :$!root-dir
  );

  my Str $puzzle-id = $cat.get-puzzle-ids.roll;
  return Str unless ?$puzzle-id;

  # Return path to image
  $!root-dir ~ "$category/$puzzle-id/image400.jpg"
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
    my PuzzleTable::Config::Category $cat .= new(
      :category-name($category), :$container, :$!root-dir
    );
    
    $hp = $cat.get-puzzle-ids.elems.Bool;
  }

  $hp
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
# Get the category lockable state. Returns undefined when container/category
# is not found.
method is-category-lockable (
  Str:D $category is copy, Str:D $container is copy --> Bool
) {
  my Bool $lockable;

  $category .= tc;
  $container = $!current-category.set-container-name($container);

  my Hash $cats := $!categories-config<containers>;
  if $cats{$container}<categories>{$category}:exists {
    $lockable = $cats{$container}<categories>{$category}<lockable>.Bool;
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

  # Never any category in the Default container
  if $container ne 'Default_EX_' {
    my Hash $cats := $!categories-config<containers>;
    if $cats{$container}<categories>{$category}:exists {
      $cats{$container}<categories>{$category}<lockable> = $lockable;
    }

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

