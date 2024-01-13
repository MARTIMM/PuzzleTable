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
        border-width: 3px;
        border-style: outset;
        border-color: #ffee00;
      }

      .puzzle-object label {
        /*background-color: #606060;*/
        color: #202020;
        padding: 0px;
        padding-left: 10px;
      }

      .puzzle-object-comment {
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

#`{{
#-------------------------------------------------------------------------------
method file-import ( N-Object $parameter ) {
  say 'file import';
}

#-------------------------------------------------------------------------------
method check-category ( Str $category ) {
  say 'check category';
}
}}

#-------------------------------------------------------------------------------
method get-password ( --> Str ) {
  $*puzzle-data<settings><password> // '';
}

#-------------------------------------------------------------------------------
method check-password ( Str $old-password --> Bool ) {
  my Bool $ok = True;
  $ok = (sha1-hex($old-password) eq $*puzzle-data<settings><password>).Bool
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
method is-locked ( --> Bool ) {
  ?$*puzzle-data<settings><locked>.Bool;
}

#-------------------------------------------------------------------------------
method lock ( ) {
  $*puzzle-data<settings><locked> = True;
}

#-------------------------------------------------------------------------------
method unlock ( ) {
  $*puzzle-data<settings><locked> = False;
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
say 'save puzzle admin in ', PUZZLE_DATA;
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
