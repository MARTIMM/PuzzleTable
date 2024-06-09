use v6.d;

use PuzzleTable::Types;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config:auth<github:MARTIMM>;

has Gnome::Gtk4::CssProvider $!ss-provider;

has Version $.version = v0.5.0;
has Array $.options = [<
  category=s pala-collection=s puzzles lock h help version
>];

has PuzzleTable::Config::Categories $!categories handles( <
      get-password check-password set-password
      is-category-lockable set-category-lockable is-locked lock unlock
      set-palapeli-preference get-palapeli-preference get-palapeli-image-size
      get-palapeli-collection add-category move-category
      add-puzzle
    >);

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

  # Copy images to the data directory
  my Str $png-file;
  for <start-puzzle-64.png edit-puzzle-64.png add-cat.png ren-cat.png
       rem-cat.png move-64.png remove-64.png archive-64.png config-64.png
      > -> $i {
    $png-file = [~] DATA_DIR, 'images/', $i;
    %?RESOURCES{$i}.copy($png-file) unless $png-file.IO.e;
  }

  # Copy style sheet to data directory and load into program
  my Str $css-file = DATA_DIR ~ 'puzzle-data.css';
  %?RESOURCES<puzzle-data.css>.copy($css-file);
  $!css-provider .= new-cssprovider;
  $!css-provider.load-from-path($css-file);

  # Load the categories configuraton from the puzzle data directory
  $!categories .= new(:root-dir(PUZZLE_TABLE_DATA));
}

#-------------------------------------------------------------------------------
method set-css ( N-Object $context, Str :$css-class = '' ) {
  return unless ?$css-class;

  my Gnome::Gtk4::StyleContext $style-context .= new(:native-object($context));
  $style-context.add-provider(
    $css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
  );
  $style-context.add-class($css-class);
}






=finish
#use NativeCall;
use PuzzleTable::Types;
use PuzzleTable::ExtractDataFromPuzzle;

use Gnome::Gtk4::CssProvider:api<2>;
use Gnome::Gtk4::StyleContext:api<2>;
use Gnome::Gtk4::T-styleprovider:api<2>;

#use Gnome::Glib::N-MainContext:api<2>;
#use Gnome::Glib::N-MainLoop:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

use Archive::Libarchive;
use Archive::Libarchive::Constants;
use Digest::SHA256::Native;
use YAMLish;
#use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config:auth<github:MARTIMM>;

my Gnome::Gtk4::CssProvider $css-provider;

has PuzzleTable::ExtractDataFromPuzzle $!extracter;
has Version $.version = v0.5.0;
has Array $.options = [<
  category=s pala-collection=s puzzles lock h help version filter=s
>];

# To get info from other modules
#has Hash $!supply-taps = %();

# To provide info to other modules
#has Suplier $!supplier .= new;

#has Semaphore::ReadersWriters $!semaphore;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

#  $!semaphore .= new;
#  $!semaphore.add-mutex-names('puzzle-data');

  my Str $png-file;
  for <start-puzzle-64.png edit-puzzle-64.png add-cat.png ren-cat.png
       rem-cat.png move-64.png remove-64.png archive-64.png config-64.png
      > -> $i {
    $png-file = [~] DATA_DIR, 'images/', $i;
    %?RESOURCES{$i}.copy($png-file) unless $png-file.IO.e;
  }

  my Str $css-file = DATA_DIR ~ 'puzzle-data.css';
  %?RESOURCES<puzzle-data.css>.copy($css-file);

  unless ?$css-provider {
    $css-provider .= new-cssprovider;
    $css-provider.load-from-path($css-file);
  }

  $!extracter .= new;

  # Raku bug? dynamic not visible within code of .tap(), must copy.
  my Hash $p := $*puzzle-data;
  signal(SIGINT).tap( {
      my $*puzzle-data = $p;
      await self.save-puzzle-admin(:force);
      exit 0;
    }
  );
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
method get-password ( --> Str ) {
#  $!semaphore.reader( 'puzzle-data', {
    $*puzzle-data<settings><password> // ''
#  });
}

#-------------------------------------------------------------------------------
method check-password ( Str $password --> Bool ) {
  my Bool $ok = True;
#  $!semaphore.reader( 'puzzle-data', {
    $ok = (sha256-hex($password) eq $*puzzle-data<settings><password>).Bool
      if $*puzzle-data<settings><password>:exists;
#  });

  $ok
}

#-------------------------------------------------------------------------------
method set-password ( Str $old-password, Str $new-password --> Bool ) {
  my Bool $is-set = False;

  # Return fault when old one is empty while there should be one given.
  return $is-set if $old-password eq '' and ?self.get-password;

#  $!semaphore.writer( 'puzzle-data', {
    # Check if old password matches before a new one is set
    $is-set = self.check-password($old-password);
    $*puzzle-data<settings><password> = sha256-hex($new-password) if $is-set;
#  });

  self.save-puzzle-admin if $is-set;
  $is-set
}

#-------------------------------------------------------------------------------
# Get the category lockable state
method is-category-lockable ( Str:D $category --> Bool ) {
#  $!semaphore.reader( 'puzzle-data', {
    $*puzzle-data<categories>{$category}<lockable>.Bool
#  });
}

#-------------------------------------------------------------------------------
method set-category-lockable ( Str:D $category, Bool:D $lockable ) {
#  $!semaphore.writer( 'puzzle-data', {
    $*puzzle-data<categories>{$category}<lockable> = $lockable;
#  });
  self.save-puzzle-admin;
}

#-------------------------------------------------------------------------------
# Get the puzzle table locking state
method is-locked ( --> Bool ) {
#  $!semaphore.reader( 'puzzle-data', {
    ?$*puzzle-data<settings><locked>.Bool;
#  });
}

#-------------------------------------------------------------------------------
# Set the puzzle table locking state
method lock ( ) {
#  $!semaphore.writer( 'puzzle-data', {
    $*puzzle-data<settings><locked> = True;
#  });
  self.save-puzzle-admin;
}

#-------------------------------------------------------------------------------
# Reset the puzzle table locking state
method unlock ( Str $password --> Bool ) {
  my Bool $ok = self.check-password($password);
#  $!semaphore.writer( 'puzzle-data', {
    $*puzzle-data<settings><locked> = False if $ok;
#  });

  self.save-puzzle-admin;
  $ok
}

#-------------------------------------------------------------------------------
method get-palapeli-preference ( --> Str ) {
#  $!semaphore.reader( 'puzzle-data', {
    $*puzzle-data<palapeli><preference> // 'standard'
#  });
}

#-------------------------------------------------------------------------------
method get-palapeli-image-size ( --> List ) {
#  $!semaphore.reader( 'puzzle-data', {
    $*puzzle-data<palapeli><puzzle-image-width>//300,
    $*puzzle-data<palapeli><puzzle-image-height>//300
#  });
}

#-------------------------------------------------------------------------------
method get-palapeli-collection ( --> Str ) {
  my Str $preference = self.get-palapeli-preference;
  my Str $collection = #$!semaphore.reader( 'puzzle-data', {
    $*puzzle-data<palapeli><collections>{$preference};
#  });

  [~] $*HOME, '/', $collection, '/'
}

#-------------------------------------------------------------------------------
method get-pala-executable ( --> Str ) {
  my Str $exec = '';
  my Hash $h;
  my Str $preference = self.get-palapeli-preference;
  given $preference {
    when 'FlatPak' {
      note "Sorry, does not seem to work!";
      $h = %();
    }

    when 'Snap' {
      $h = #$!semaphore.reader( 'puzzle-data', {
        $*puzzle-data<palapeli><execute><Snap>
#      });
    }

    when 'Standard' {
      $h = #$!semaphore.reader( 'puzzle-data', {
        $*puzzle-data<palapeli><execute><Standard>
#      });
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
method add-category ( Str:D $category, Bool $lock is copy ) {
  $lock = ($lock or $*puzzle-data<categories>{$category}<lockable>.Bool);
#say 'add category';
#  $!semaphore.writer( 'puzzle-data', {
    # Add category to list if not available
    unless $*puzzle-data<categories>{$category}:exists {
      $*puzzle-data<categories>{$category} = %(members => %());

      my $path = PUZZLE_TABLE_DATA ~ $category;
      mkdir $path, 0o700;

    }

    $*puzzle-data<categories>{$category}<lockable> = $lock;
#  });

  self.save-puzzle-admin;
}

#-------------------------------------------------------------------------------
method check-category ( Str:D $category --> Bool ) {
#  say 'check category';
#  $!semaphore.reader( 'puzzle-data', {
    $*puzzle-data<categories>{$category}:exists
#  });
}

#-------------------------------------------------------------------------------
# Return a sorted sequence of categories depending on the filter.
# When filter is 'default' then all categories are returned except 'Default'.
# When filter is 'lockable', all categories are returned except the lockable
# categories when the puzzle table is locked.
method get-categories ( Str :$filter --> Seq ) {
  my @cat = ();
#  $!semaphore.reader( 'puzzle-data', {
    if $filter eq 'default' {
      for $*puzzle-data<categories>.keys -> $category {
  #      next if $category ~~ m/ [Trash | Default] /;
        next if $category eq 'Default';
        @cat.push: $category;
      }
    }

    elsif $filter eq 'lockable' {
      my Bool $locked = self.is-locked;
      for $*puzzle-data<categories>.keys -> $category {
  #      next if $category eq 'Trash';
        next if $locked and self.is-category-lockable($category);
        @cat.push: $category;
      }
    }

    else {
      for $*puzzle-data<categories>.keys -> $category {
  #      next if $category eq 'Trash';
        @cat.push: $category;
      }
    }
#  });

  @cat.sort
}

#-------------------------------------------------------------------------------
method remove-category ( Str:D $category ) {
  say 'remove category';
}

#-------------------------------------------------------------------------------
method move-category ( $cat-from, $cat-to ) {
#  $!semaphore.writer( 'puzzle-data', {
    $*puzzle-data<categories>{$cat-to} =
    $*puzzle-data<categories>{$cat-from}:delete;

    my Str $dir-from = PUZZLE_TABLE_DATA ~ $cat-from;
    my Str $dir-to = PUZZLE_TABLE_DATA ~ $cat-to;
    $dir-from.IO.rename( $dir-to, :createonly);
#  });

  self.save-puzzle-admin;
}

#-------------------------------------------------------------------------------
method add-puzzle (
  Str:D $category, Str:D $puzzle-path,
  Bool :$from-collection = False, Str :$filter = ''
  --> Str
) {
  # Get source file info
  my Str $basename = $puzzle-path.IO.basename;

  # If one is dumping the puzzles in the same dir all the time
  # using the same file names, one can run into a clash with older
  # puzzles, sha256 does not help enough with that.
  my Str $extra-change = DateTime.now.Str;

  my Str $puzzle-id;
  my Hash $cat;
#  $!semaphore.reader( 'puzzle-data', {
    # Get free entry
    $cat := $*puzzle-data<categories>{$category}<members>;
    loop ( my Int $count = 1; $count < 1000; $count++ ) {
      $puzzle-id = $count.fmt('p%03d');
      last unless $cat{$puzzle-id}:exists;
    }
#  });

  my Str $destination = PUZZLE_TABLE_DATA ~ $category ~ "/$puzzle-id";
  mkdir $destination, 0o700;

  # Store the puzzle using a unique filename. It is possible that
  # puzzle name is the same found in other directories.
  my Str $unique-name = sha256-hex($puzzle-path ~ $extra-change) ~ ".puzzle";
  $puzzle-path.IO.copy( "$destination/$unique-name", :createonly)
    unless "$destination/$unique-name".IO.e;

  # Get the image and desktop file from the puzzle file, a tar archive.
  $!extracter.extract( $destination, "$destination/$unique-name");

  # Get some info from the desktop file
  my Hash $info = $!extracter.palapeli-info($destination);

  my Hash $temp-data = %(
    :Filename($unique-name),
    :SourceFile($puzzle-path),
    :Source($info<Source>),
    :Comment($info<Comment>),
    :Name($info<Name>),
    :ImageSize($info<ImageSize>),
    :PieceCount($info<PieceCount>),
    :Slicer($info<Slicer>),
    :SlicerMode($info<SlicerMode>),
  );

  my Bool $accept = True;
  $accept = False if ?$filter and $temp-data<Source> !~~ m/ $filter /;
  if $accept {
#    $!semaphore.writer( 'puzzle-data', {
      # Store data in $*puzzle-data admin
      $cat{$puzzle-id} = $temp-data;
#    });

    note "Add new puzzle: $puzzle-id, name: $temp-data<Name>, $temp-data<ImageSize>, ", "$temp-data<PieceCount> pieces";

    # Convert the image into a smaller one to be displayed on the puzzle table
    run '/usr/bin/convert', "$destination/image.jpg",
        '-resize', '400x400', "$destination/image400.jpg";

    self.check-pala-progress-file(
      $basename, sha256-hex($puzzle-path ~ $extra-change),
      $cat{$puzzle-id}, $puzzle-path, $destination, :$from-collection
    );
    
    # Add some more for the calculation
    my $progress = self.calculate( $cat{$puzzle-id}, $category, $puzzle-id);
    my $p = self.get-palapeli-preference;
#    $!semaphore.writer( 'puzzle-data', {
      $cat{$puzzle-id}<Progress>{$p} = $progress;
#    });

    # Save admin
    self.save-puzzle-admin unless $from-collection;

    CATCH {
      default {
        .message.note;
        .resume;
      }
    }
  }

  # When filtered out, some created data must be removed again
  else {
    self.remove-dir($destination);
    $puzzle-id = '';
  }

  $puzzle-id
}

#-------------------------------------------------------------------------------
method check-pala-progress-file (
  Str $basename, Str $unique-name, Hash $puzzle-info,
  Str $source, Str $destination, Bool :$from-collection = False
) {
  my Hash $collections = #$!semaphore.reader( 'puzzle-data', {
    $*puzzle-data<palapeli><collections>;
#  });

  # Check in pala collections for this name
  my Str $collection-name;

  # When puzzle is in the Palapeli collection, its name 
  # will be like `{hexnums}.save`.
  if $from-collection {
    $collection-name = $basename ~ '.save';
    $collection-name ~~ s/ \. puzzle //;
  }

  # When the puzzle is an exported one, its name
  # is  like `__FSC_name.puzzle_0_.save`.
  else {
    $collection-name = [~] '__FSC_', $basename, '_0_.save';
  }

  # The name it must become in the preferred collection
#  my Str $pref-col = self.get-palapeli-preference;
  my Str $progress-name = [~] '__FSC_', $unique-name, '.puzzle_0_.save';
  my Str $puzzle-progress-path = [~] $destination, '/', $progress-name;
  my Str $col-progress-path = [~] $source.IO.parent,
         '/', $collection-name;

#note "$?LINE $basename, $unique-name, $collection-name, $progress-name";
#note "$?LINE from: $col-progress-path";
#note "$?LINE to:   $puzzle-progress-path";

if $col-progress-path.IO.r {
  $col-progress-path.IO.copy( $puzzle-progress-path, :createonly);
  note "Progress file '$progress-name' saved";
}

#exit;
#`{{
  for $collections.keys -> $col-key {
    my Str $col-path = [~] $*HOME, '/', $collections{$col-key},
           '/', $collection-name;
    if $col-path.IO.r {
      unless $progress-path.IO.e {
        say "$collection-name.IO.basename() found in $col-key collection";
        say "Copy $col-path.IO.basename() to $progress-path.IO.basename()";
#        $!semaphore.writer( 'puzzle-data', {
          $col-path.IO.copy( $progress-path, :createonly);
#        });
      }

      last;
    }
  }
}}
}

#-------------------------------------------------------------------------------
# Called from call-back in Table after playing a puzzle.
# The object holds most of the fields of
# $*puzzle-data<categories>{$category}<members><some puzzle index> added with
# the following fields: Puzzle-index, Category and Image (see get-puzzles()
# below) while Name and SourceFile are removed (see add-puzzle-to-table()
# in Table).
method calculate-progress ( Hash $puzzle --> Str ) {
  my $c = $puzzle<Category>;
  my $i = $puzzle<Puzzle-index>;
  my $p = self.get-palapeli-preference;

  my $progress = self.calculate( $puzzle, $c, $i);
#  $!semaphore.writer( 'puzzle-data', {
    $*puzzle-data<categories>{$c}<members>{$i}<Progress>{$p} = $progress;
#  });

  self.save-puzzle-admin;

  $progress
}

#-------------------------------------------------------------------------------
# Called from check-pala-progress-file()
method calculate ( Hash $puzzle, Str $category, Str $index --> Str ) {

  my Str $filename = #$!semaphore.reader( 'puzzle-data', {
    $puzzle<Filename>;
#  });
  my Str $progress-filename = [~] '__FSC_', $filename, '_0_.save';
#  my Str $progress-path = [~] self.get-pala-collection,
#         '/', $progress-filename;
#note "$?LINE $progress-filename";
#note "$?LINE $puzzle.gist()";
  my Str $progress-path = [~] PUZZLE_TABLE_DATA, '/', $category, '/',
    $index, '/', $progress-filename;

  my Str $progress = "0.0";

  # Puzzle progress admin is maintained by Palapeli in its collection directory
  # When puzzle is never started, this file does not yet exist.
  if $progress-path.IO.r {
    my $nbr-pieces = #$!semaphore.reader( 'puzzle-data', {
      $puzzle<PieceCount>;
#    });
    my Bool $get-lines = False;
    my Hash $piece-coordinates = %();
    for $progress-path.IO.slurp.lines -> $line {
      if $line eq '[XYCo-ordinates]' {
        $get-lines = True;
        next;
      }

      if $get-lines {
        my Str ( $, $piece-coordinate ) = $line.split('=');
        $piece-coordinates{$piece-coordinate} = 1;
      }
    }

    # A puzzle of n pieces has n different pieces at the start and only one
    # when finished. To calculate the progress substract one from the numbers
    # before deviding.
    my Rat $p;
    $p = 100.0 - ($piece-coordinates.elems -1) / ($nbr-pieces -1) * 100.0;
    $progress = $p.fmt('%3.1f');
  }

#`{{
  my $p = self.get-palapeli-preference;
  $!semaphore.writer( 'puzzle-data', {
    $puzzle<Progress>{$p} = $progress;
  });

  # Save admin
  self.save-puzzle-admin;
}}

  $progress
}

#-------------------------------------------------------------------------------
method store-puzzle-info( Hash $pt-puzzle, Str $comment, Str $source) {
  my $c = $pt-puzzle<Category>;
  my $i = $pt-puzzle<Puzzle-index>;
  my Hash $puzzle = #$!semaphore.reader( 'puzzle-data', {
    $*puzzle-data<categories>{$c}<members>{$i};
#  });

  $puzzle<Comment> = $comment;
  $puzzle<Source> = $source;
  self.save-puzzle-admin;
}

#-------------------------------------------------------------------------------
method get-category-status ( Str $category --> Array ) {
  my Array $cat-status = [ 0, 0, 0, 0];
#  $!semaphore.reader( 'puzzle-data', {
    my Str $preference-program = $*puzzle-data<palapeli><preference>;
    my Hash $cat := $*puzzle-data<categories>{$category}<members>;
    $cat-status[0] = $cat.elems;
    for $cat.keys -> $puzzle-id {
#note "$?LINE $category, $puzzle-id, $preference-program, $cat{$puzzle-id}<Progress>{$preference-program}";
      my Num() $progress =
        $cat{$puzzle-id}<Progress>{$preference-program} // 0e0;
      $cat-status[1]++ if $progress == 0e0;
      $cat-status[2]++ if 0e0 < $progress < 1e2;
      $cat-status[3]++ if $progress == 1e2;
    }
#  });

  $cat-status
}

#-------------------------------------------------------------------------------
# Return an array of hashes. Basic info comes from
# $*puzzle-data<categories>{$category}<members> where info of Image and the
# index of the puzzle is added.
method get-puzzles ( Str $category --> Array ) {

  my Str $pi;
  my Int $found-count = 0;
  my Array $cat-puzzle-data = [];
#  $!semaphore.reader( 'puzzle-data', {
    my Hash $cat = $*puzzle-data<categories>{$category}<members>;
    my Int $count = $cat.elems;

    loop ( my Int $i = 1; $i < 1000; $i++) {
      $pi = $i.fmt('p%03d');
      if ?$cat{$pi} {
        #TODO old info seems to stick, must remove for the moment
        $cat{$pi}<Puzzle-index>:delete;
        $cat{$pi}<Category>:delete;
        $cat{$pi}<Image>:delete;

        $cat-puzzle-data.push: %(
          :Puzzle-index($pi),
          :Category($category),
          :Image(PUZZLE_TABLE_DATA ~ "$category/$pi/image400.jpg"),
          |$cat{$pi}
        );

        $found-count++;
      }
      
      last if $found-count >= $count;
    }
#  });

  $cat-puzzle-data
}

#-------------------------------------------------------------------------------
# Return an array of hashes. Basic info comes from
# $*puzzle-data<categories>{$category}<members> where info of Image and the
# index of the puzzle is added.
method get-puzzle ( Str $category, Str $puzzle-id --> Hash ) {

  my Hash $puzzle = %();
#  $!semaphore.reader( 'puzzle-data', {
    $puzzle = $*puzzle-data<categories>{$category}<members>{$puzzle-id}
      if $*puzzle-data<categories>{$category}<members>{$puzzle-id}:exists;
#  });

  $puzzle
}

#-------------------------------------------------------------------------------
# Return an array of hashes. Basic info comes from
# $*puzzle-data<categories>{$category}<members> where info of Image and the
# index of the puzzle is added.
method get-puzzle-image ( Str $category --> Str ) {

  my Str $pi;
  my Str $puzzle-image;
#  $!semaphore.reader( 'puzzle-data', {
    my Hash $cat := $*puzzle-data<categories>{$category}<members>;

    loop ( my Int $i = 1; $i < 1000; $i++) {
      $pi = $i.fmt('p%03d');
      if ?$cat{$pi} {
        $puzzle-image = PUZZLE_TABLE_DATA ~ "$category/$pi/image400.jpg";
        last;
      }
    }
#  });

  $puzzle-image
}

#-------------------------------------------------------------------------------
method move-puzzle ( Str $from-cat, Str $to-cat, Str $puzzle-id ) {
  for 1..999 -> $count {
    my Str $p-id = $count.fmt('p%03d');
    next if #$!semaphore.reader( 'puzzle-data', {
      $*puzzle-data<categories>{$to-cat}<members>{$p-id}:exists;
    #});

    #$!semaphore.writer( 'puzzle-data', {
      my Hash $puzzle =
        $*puzzle-data<categories>{$from-cat}<members>{$puzzle-id}:delete;

      ##TODO should not have come into the $*puzzle-data hash
      # Taken care of elsewhere
      #$puzzle<Category>:delete;
      #$puzzle<Image>:delete;
      #$puzzle<Puzzle-index>:delete;

      $*puzzle-data<categories>{$to-cat}<members>{$p-id} = $puzzle;


      my Str $from-dir = [~] PUZZLE_TABLE_DATA, $from-cat, '/', $puzzle-id;
      my Str $to-dir = [~] PUZZLE_TABLE_DATA, $to-cat, '/', $p-id;
      $from-dir.IO.rename( $to-dir, :createonly);
    #});

    self.save-puzzle-admin;

    # Puzzle is moved to other category spot
    last;
  }
}

#-------------------------------------------------------------------------------
method remove-puzzle ( Str $from-cat, Str $puzzle-id ) {

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

#-------------------------------------------------------------------------------
method remove-dir ( $path ) {

  note "\nremove path $path";
  for dir $path -> $f {
    say "delete $f.IO.basename()";
  }

  say "delete $path.IO.basename()";
}

#-------------------------------------------------------------------------------
method save-puzzle-admin ( Bool :$force = False --> Promise ) {
  state $save-count = 0;
  state $lock = Lock.new;
  my Promise $promise;

  # If $save-count == 0 and $force == True then there were no changes to save
  # It was done before or there weren't any.
  # $force is only used at the end of the program on exit.
  return start {} if $save-count == 0 and $force;

  if $save-count++ > 5 or $force {

    # Save it to disk using a thread
    $promise = start {
      note "Save puzzle admin";
      my $t0 = now;
      $lock.protect: {
        # Make a deep copy first
        my Hash $puzzle-data-clone = $*puzzle-data.deepmap(-> $c is copy {$c});

        PUZZLE_DATA.IO.spurt(save-yaml($puzzle-data-clone));
        
        # Nake sure the memory is freed beforehand
        $puzzle-data-clone = %();
      }

      note "Done saving puzzle admin. Needed {(now - $t0).fmt('%.1f sec')}.";
    }

    # Always set to 0, even if $force triggered the save.
    $save-count = 0;
  }
  
  $promise
}

