use v6.d;

use PuzzleTable::Types;
use PuzzleTable::Config::Categories;

use Gnome::Gtk4::CssProvider:api<2>;
use Gnome::Gtk4::StyleContext:api<2>;
use Gnome::Gtk4::T-styleprovider:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config:auth<github:MARTIMM>;

has Gnome::Gtk4::CssProvider $!css-provider;

has Version $.version = v0.5.0;
has Array $.options = [<
  category=s pala-collection=s puzzles lock h help version verbose
>];

has PuzzleTable::Config::Categories $!categories handles( <
      get-password check-password set-password
      is-category-lockable set-category-lockable is-locked lock unlock
      set-palapeli-preference get-palapeli-preference get-palapeli-image-size
      get-palapeli-collection run-palapeli
      get-categories add-category move-category select-category find-container
      get-containers add-container delete-container
      save-categories-config get-current-category get-category-status
      add-puzzle move-puzzle update-puzzle get-puzzles get-puzzle
      remove-puzzle get-puzzle-image
    >);

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

  # Copy images to the data directory
  my Str $png-file;
  for <start-puzzle-64.png edit-puzzle-64.png
       add-cat.png add-cont.png ren-cat.png rem-cat.png
       move-64.png remove-64.png archive-64.png config-64.png
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

  # Save when an interrupt arrives
  signal(SIGINT).tap( {
      self.save-categories-config;
      exit 0;
    }
  );
}

#-------------------------------------------------------------------------------
method set-css ( N-Object $context, Str :$css-class = '' ) {
  return unless ?$css-class;

  my Gnome::Gtk4::StyleContext $style-context .= new(:native-object($context));
  $style-context.add-provider(
    $!css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
  );
  $style-context.add-class($css-class);
}

