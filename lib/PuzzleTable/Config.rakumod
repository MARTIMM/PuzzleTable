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

has Version $.version = v0.3.1; 
has Array $.options = [<category=s import=s puzzles h help version>];
has PuzzleTable::ExtractDataFromPuzzle $!extracter;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  unless ?$css-provider {
    # Create css file
    (PUZZLE_CSS).IO.spurt(q:to/EOCSS/);
      window {
      }

      .puzzle-table {
        border-width: 3px;
        border-style: outset;
        border-color: #ffee00;
        padding: 5px;
      /*	border-style: inset; */
      /*	border-style: solid; */
      /*	border-style: none; */
      }

      .puzzle-grid {
        padding: 5px;
      }

      .puzzle-object {
        padding: 5px;
        background-color: #c0c0c0;
        color: white;
        border-width: 3px;
        border-style: outset;
        border-color: #ffee00;
      }

      .puzzle-object label {
        background-color: #606060;
        color: #202020;
        padding: 0px;
        padding-left: 10px;
      }

      .puzzle-object-comment {
        background-color: #606060;
        color: #202020;
        padding-left: 0px;
        padding-bottom: 5px;
      }

      .puzzle-object picture {
        background-color: #a0a0a0;
        padding: 10px;
      }


      EOCSS

    $css-provider .= new-cssprovider;
    $css-provider.load-from-path(PUZZLE_CSS);
  }
  
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
method file-import ( N-Object $parameter ) {
  say 'file import';
}

#-------------------------------------------------------------------------------
method check-category ( Str $category ) {
  say 'check category';
}

#-------------------------------------------------------------------------------
method add-category ( Str:D $category ) {
#say 'add category';
  # Add category to list if not available
  unless $*puzzle-data<categories>{$category}:exists {
    $*puzzle-data<categories>{$category} = %(members => %());

    my $path = PUZZLE_TABLE_DATA ~ $category;
    mkdir $path, 0o700;

    self.save-puzzle-admin;
  }

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
method add-puzzle ( Str:D $category, Str:D $puzzle-path ) {
#say 'add puzzle';
  # Get source file info
  my Str $basename = $puzzle-path.IO.basename;
#  my Str $import-from = $puzzle-path.IO.parent.Str;

  # Check if source file is copied before
  my Hash $cat := $*puzzle-data<categories>{$category}<members>;
  for $cat.keys -> $p {
    if $puzzle-path eq $cat{$p}<SourceFile> {
      note "Puzzle '$basename' already added in category '$category'";
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
  my $unique-name = sha1-hex($puzzle-path) ~ ".puzzle";
  $puzzle-path.IO.copy( "$destination/$unique-name", :createonly);

  # Get the image and desktop file from the puzzle file, a tar archive.
  $!extracter.extract( $destination, "$destination/$unique-name");

  # Get some info from the desktop file
  my Hash $info = $!extracter.palapeli-info($destination);

  # Store data in $*puzzle-data admin
  $cat{$puzzle-count} = %(
    :Filename($unique-name),
    :SourceFile($puzzle-path),
    :Comment($info<Comment>),
    :Name($info<Name>),
    :Width($info<Width>),
    :Height($info<Height>),
    :PieceCount($info<PieceCount>),
  );

  # Save admin
  self.save-puzzle-admin;

  # Convert the image into a smaller one to be displayed on the puzzle table
  run '/usr/bin/convert', "$destination/image.jpg",
      '-resize', '400x400', "$destination/image400.jpg";

  CATCH {
    default {
      .message.note;
      .resume;
    }
  }
}

#-------------------------------------------------------------------------------
method save-puzzle-admin ( ) {
  PUZZLE_DATA.IO.spurt(save-yaml($*puzzle-data));
}

#-------------------------------------------------------------------------------
method get-puzzles ( Str $category --> Array ) {

  my Str $pi;
  my Hash $cat := $*puzzle-data<categories>{$category}<members>;
  my Int $count = $cat.elems;
  my Array $cat-puzzle-data = [];
  loop ( my Int $i = 0; $i < $count; $i++ ) {
    $pi = ($i+1).fmt('p%03d');
    $cat-puzzle-data.push: %(
      :Puzzle-index($pi),
      :Image(PUZZLE_TABLE_DATA ~ "$category/$pi/image400.jpg"),
      |$cat{$pi}
    );
  }

  $cat-puzzle-data
}
