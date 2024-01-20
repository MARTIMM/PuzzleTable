use v6.d;
#use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::ExtractDataFromPuzzle;

use Gnome::Gtk4::CssProvider:api<2>;
use Gnome::Gtk4::StyleContext:api<2>;
use Gnome::Gtk4::T-StyleProvider:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

use Digest::SHA1::Native;
use YAMLish;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config:auth<github:MARTIMM>;

my Gnome::Gtk4::CssProvider $css-provider;

has PuzzleTable::ExtractDataFromPuzzle $!extracter;
has Version $.version = v0.3.1; 
has Array $.options = [<
  category=s pala-export=s puzzles lock h help version
>];

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  unless ?$css-provider {
    # Create css file
    (PUZZLE_CSS).IO.spurt(q:to/EOCSS/);
      #password-dialog {
        background-color: #b0b0b0;
      }

      #dialog-label {
        color: black;
      }

      #category-dialog {
        background-color: #b0b0b0;
        color: black;
      }

      .puzzle-table {
        border-width: 3px;
        border-style: outset;
        border-color: #ffee00;
        padding: 5px;
      	border-style: inset;
      }

      /*
      .puzzle-grid {
        padding: 5px;
      }
      */

      .puzzle-object {
        padding: 5px;
        background-color: #c0c0c0;
        /*color: white;*/
        border-width: 3px;
        border-style: outset;
        border-color: #ffee00;
      }

      .puzzle-object:hover {
        background-color: #a0a0a0;
        color: white;
      }

      /*
      .puzzle-object:selected {
        background-color: #f0a080;
        color: white;
      }
      */

      #puzzle-image {
        /*
        border-width: 30px;
        border-radius: 5px;
        border-style: solid;
        border-color: #ffee00;
        */
        background-color: #f0a080;
      }

      #puzzle-item-label {
        /*background-color: #606060;*/
        color: #202020;
        padding: 0px;
        padding-left: 10px;
      }

      #puzzle-item-comment {
        /*background-color: #606060;*/
        color: white;
        padding: 0px;
        margin-left: 0px;
        margin-bottom: 5px;
      }

      .puzzle-object picture {
        /*background-color: #a0a0a0;*/
        padding: 10px;
      }


      EOCSS

    $css-provider .= new-cssprovider;
    $css-provider.load-from-path(PUZZLE_CSS);
  }

  my Str $png-file = DATA_DIR ~ 'icons8-run-64.png';
  %?RESOURCES<icons8-run-64.png>.copy($png-file) unless $png-file.IO.e;
  $!extracter .= new;
}

#-------------------------------------------------------------------------------
method set-css ( N-Object $context, Str :$css-class = '' ) {

  my Gnome::Gtk4::StyleContext $style-context .= new(:native-object($context));
  $style-context.add-provider(
    $css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
  );
  $style-context.add-class($css-class) if ?$css-class;
}

#-------------------------------------------------------------------------------
method find-palapeli-info ( ) {

}

#-------------------------------------------------------------------------------
method get-password ( --> Str ) {
  $*puzzle-data<settings><password> // '';
}

#-------------------------------------------------------------------------------
method check-password ( Str $password --> Bool ) {
  my Bool $ok = True;
  $ok = (sha1-hex($password) eq $*puzzle-data<settings><password>).Bool
    if $*puzzle-data<settings><password>:exists;

  $ok
}

#-------------------------------------------------------------------------------
method set-password ( Str $old-password, Str $new-password --> Bool ) {
  my Bool $is-set;

  # Throw an error if called with an empty string while there is a password set
  die 'Coding error, password is available yet old password is empty'
    if $old-password eq '' and ?self.get-password;

  # Check if old password matches before a new one is set
  $*puzzle-data<settings><password> = sha1-hex($new-password)
    if $is-set = self.check-password($old-password);

  self.save-puzzle-admin;

  $is-set
}

#-------------------------------------------------------------------------------
# Get the category lockable state
method is-category-lockable ( Str:D $category --> Bool ) {
  $*puzzle-data<categories>{$category}<lockable>.Bool
}

#-------------------------------------------------------------------------------
method set-category-lockable (
  Str:D $category, Bool:D $lockable, Str $password --> Bool
) {
  my Bool $ok;
  $*puzzle-data<categories>{$category}<lockable> = $lockable
    if $ok = self.check-password($password);

  $ok
}

#-------------------------------------------------------------------------------
# Get the puzzle table locking state
method is-locked ( --> Bool ) {
  ?$*puzzle-data<settings><locked>.Bool;
}

#-------------------------------------------------------------------------------
# Set the puzzle table locking state
method lock ( Str $password --> Bool ) {
  my Bool $ok;
  $*puzzle-data<settings><locked> = True
    if $ok = self.check-password($password);

  $ok
}

#-------------------------------------------------------------------------------
# Reset the puzzle table locking state
method unlock ( Str $password --> Bool ) {
  my Bool $ok;
  $*puzzle-data<settings><locked> = False
    if $ok = self.check-password($password);

  $ok
}

#-------------------------------------------------------------------------------
method get-pala-collection ( InstallType $type --> Str ) {
  my Str $collection = '';
  given $type {
    when FlatPak {
      $collection = $*puzzle-data<palapeli><collections><flatpak>;
    }

    when Snap {
      $collection = $*puzzle-data<palapeli><collections><snap>;
    }

    when Standard {
      $collection = $*puzzle-data<palapeli><collections><standard>;
    }
  }
  
  [~] $*HOME, '/', $collection, '/'
}

#-------------------------------------------------------------------------------
method get-pala-executable ( InstallType $type --> Str ) {
  my Str $exec = '';
  my Hash $h;
  given $type {
    when FlatPak {
      note "Sorry, does not seem to work!";
      $h = %();
    }

    when Snap {
      $h = $*puzzle-data<palapeli><execute><snap>;
    }

    when Standard {
      $h = $*puzzle-data<palapeli><execute><standard>;
    }
  }

  $exec = $h<exec>;
  if $h<env>:exists {
    for $h<env>.keys -> $k {
      %*ENV{$k} = $h<env>{$k};
    }
  }

  $exec
}

#-------------------------------------------------------------------------------
method add-category ( Str:D $category, Bool $lock ) {
#say 'add category';
  # Add category to list if not available
  unless $*puzzle-data<categories>{$category}:exists {
    $*puzzle-data<categories>{$category} = %(members => %());

    my $path = PUZZLE_TABLE_DATA ~ $category;
    mkdir $path, 0o700;

    self.save-puzzle-admin;
  }

  $*puzzle-data<categories>{$category}<lockable> = $lock;
}

#-------------------------------------------------------------------------------
method rename-category ( Str:D $category-from, Str:D $category-to ) {
  say 'rename category';
}

#-------------------------------------------------------------------------------
method remove-category ( Str:D $category ) {
  say 'remove category';
}

#-------------------------------------------------------------------------------
method check-category ( Str:D $category --> Bool ) {
#  say 'check category';
  $*puzzle-data<categories>{$category}:exists
}

#-------------------------------------------------------------------------------
method get-categories ( --> Seq ) {
  $*puzzle-data<categories>.keys.sort;
}

#-------------------------------------------------------------------------------
method move-category ( $cat-from, $cat-to ) {
  $*puzzle-data<categories>{$cat-to} =
    $*puzzle-data<categories>{$cat-from}:delete;

  my Str $dir-from = PUZZLE_TABLE_DATA ~ $cat-from;
  my Str $dir-to = PUZZLE_TABLE_DATA ~ $cat-to;
  $dir-from.IO.rename( $dir-to, :createonly);
}

#-------------------------------------------------------------------------------
method add-puzzle ( Str:D $category, Str:D $puzzle-path ) {
#say 'add puzzle';
  # Get source file info
  my Str $basename = $puzzle-path.IO.basename;
#  my Str $import-from = $puzzle-path.IO.parent.Str;

  # Check if source file is copied before
  my Hash $cat := $*puzzle-data<categories>{$category}<members>;
  for $cat.keys -> $puzzle-count {
    if $puzzle-path eq $cat{$puzzle-count}<SourceFile> {
      note "Puzzle '$basename' already added in category '$category'";
      self.check-pala-progress-file(
        $basename, sha1-hex($puzzle-path) ~ ".puzzle", $cat{$puzzle-count}
      );
      self.save-puzzle-admin;
      return;
    }
  }

  # Get number of keys to get count for next puzzle
  my Int $count = $cat.elems + 1;
  my Str $puzzle-count = $count.fmt('p%03d');
  my Str $destination = PUZZLE_TABLE_DATA ~ $category ~ "/$puzzle-count";
  mkdir $destination, 0o700;

  # Store the puzzle using a unique filename. It is possible that
  # puzzle name is the same found in other directories.
  my Str $unique-name = sha1-hex($puzzle-path) ~ ".puzzle";
  $puzzle-path.IO.copy( "$destination/$unique-name", :createonly);

  # Get the image and desktop file from the puzzle file, a tar archive.
  $!extracter.extract( $destination, "$destination/$unique-name");

  # Get some info from the desktop file
  my Hash $info = $!extracter.palapeli-info($destination);

  # Store data in $*puzzle-data admin
  $cat{$puzzle-count} = %(
    :Filename($unique-name),
    :SourceFile($puzzle-path),
    :Source(''),
    :Comment($info<Comment>),
    :Name($info<Name>),
    :Width($info<Width>),
    :Height($info<Height>),
    :PieceCount($info<PieceCount>),
  );

  # Convert the image into a smaller one to be displayed on the puzzle table
  run '/usr/bin/convert', "$destination/image.jpg",
      '-resize', '400x400', "$destination/image400.jpg";

  self.check-pala-progress-file(
    $basename, sha1-hex($puzzle-path), $cat{$puzzle-count}
  );

  # Save admin
  self.save-puzzle-admin;

  CATCH {
    default {
      .message.note;
      .resume;
    }
  }
}

#-------------------------------------------------------------------------------
method check-pala-progress-file (
  Str $basename, Str $unique-name, Hash $puzzle-info
) {
  my Str $col-unique-path = '';
  my Hash $collections := $*puzzle-data<palapeli><collections>;

  # Check in pala collections for this name
  my Str $collection-name = [~] '__FSC_', $basename, '_0_.save';

  for $collections.keys -> $col-key {
    my Str $col-path = [~] $collections{$col-key}, '/', $collection-name;
    if $col-path.IO.r {
      say "$collection-name found in $col-key collection";

      # Check for the name it must become
      my Str $collection-unique = [~] '__FSC_', $unique-name, '_0_.save';
      $col-unique-path = [~] $collections{$col-key}, '/', $collection-unique;

      say "Copy $col-path to $col-unique-path, ", $col-unique-path.IO.e;
      $col-path.IO.copy( $col-unique-path, :createonly)
        unless $col-unique-path.IO.e;

#      $puzzle-info<progress-files>{$col-key} = $col-unique-path;
    }
  }
}

#-------------------------------------------------------------------------------
# Called from call-back in Table after playing a puzzle.
# The object holds most of the fields of
# $*puzzle-data<categories>{$category}<members><some puzzle index> added with
# the following fields: Puzzle-index,
# Category and Image (see get-puzzles() below) while Name and SourceFile are
# removed (see add-puzzle-to-table() in Table).
method calculate-progress ( Hash $object, InstallType $type --> Str) {
#note "$?LINE $object.gist()";

  my Hash $puzzle := $*puzzle-data<categories>{$object<Category>}<members>{$object<Puzzle-index>};

  my Str $filename = $puzzle<Filename>;
  my Str $collection-filename = [~] '__FSC_', $filename, '_0_.save';
  my Str $collection-path = [~] self.get-pala-collection($type),
         '/', $collection-filename;

  my $nbr-pieces = $puzzle<PieceCount>;
  my Bool $get-lines = False;
  my Hash $piece-coordinates = %();
  for $collection-path.IO.slurp.lines -> $line {
    if $line eq '[XYCo-ordinates]' {
      $get-lines = True;
      next;
    }

    if $get-lines {
      my Str ( $, $piece-coordinate ) = $line.split('=');
      $piece-coordinates{$piece-coordinate} //= 0;
      $piece-coordinates{$piece-coordinate}++;
    }
  }

  my Str $progress = (
    100.0 - $piece-coordinates.elems / $nbr-pieces * 100.0
  ).fmt('%3.1f');
  my Str $key = $type ~~ Snap ?? 'Snap' !! 'Standard';
  $puzzle<Progress>{$key} = $progress;

note "$?LINE $progress, $piece-coordinates.elems(), $nbr-pieces";

  # Save admin
  self.save-puzzle-admin;

  $progress
}

#-------------------------------------------------------------------------------
method save-puzzle-admin ( ) {
say 'save puzzle admin in ', PUZZLE_DATA;
  PUZZLE_DATA.IO.spurt(save-yaml($*puzzle-data));
}

#-------------------------------------------------------------------------------
# Return an array of hashes. Basic info comes from
# $*puzzle-data<categories>{$category}<members> where info of Image and the
# index of the puzzle is added.
method get-puzzles ( Str $category --> Array ) {

  my Str $pi;
  my Hash $cat := $*puzzle-data<categories>{$category}<members>;
  my Int $count = $cat.elems;
  my Array $cat-puzzle-data = [];
  loop ( my Int $i = 0; $i < $count; $i++ ) {
    $pi = ($i+1).fmt('p%03d');
    $cat-puzzle-data.push: %(
      :Puzzle-index($pi),
      :Category($category),
      :Image(PUZZLE_TABLE_DATA ~ "$category/$pi/image400.jpg"),
      |$cat{$pi}
    );
  }

  $cat-puzzle-data
}

#-------------------------------------------------------------------------------
method export-pala-puzzles ( Str $category, Str $pala-collection-path) {
  for $pala-collection-path.IO.dir -> $collection-file {
    next if $collection-file.d;

    # The puzzle is started from outside the Palapeli. This is only a saved file
    # to keep track of progress of puzzle. Ends always in '.save'. Must be
    # checked when --puzzles option is used.
    next if $collection-file.Str ~~ m/^ __FSC_ /;
  }
}
