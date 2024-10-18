use v6.d;

use PuzzleTable::Types;
use PuzzleTable::Config::Global;
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

# PuzzleTable::Gui::MainWindow
has $!main-window;

has Gnome::Gtk4::CssProvider $!css-provider;

our $options = [<
  category=s container=s pala-collection=s puzzles lock h help version verbose
  restore=s unlock=s root-global=s root-table=s
>];

has PuzzleTable::Config::Global $!global-settings handles( <
      get-password check-password set-password
      is-locked lock unlock
      run-palapeli
      get-palapeli-preference set-palapeli-preference
      get-palapeli-image-size set-palapeli-image-size
      get-palapeli-collection
    >);

has PuzzleTable::Config::Categories $!categories handles( <
      is-category-lockable set-category-lockable
      get-categories add-category delete-category move-category
      select-category find-container get-current-container
      get-containers add-container delete-container is-expanded set-expand
      save-categories-config get-current-category get-category-status
      add-puzzle move-puzzle update-puzzle get-puzzles get-puzzle
      archive-puzzles get-puzzle-image restore-puzzles has-puzzles
    >);

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$root-global, Str:D :$root-table ) {
note "$?LINE $root-global, $root-table";

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

  # Load the global and default categories configuraton
  # from the puzzle data directory
  $!global-settings .= new( :root-dir($root-global));
  $!categories .= new(:root-dir($root-table), :config(self));

  # Save when an interrupt arrives
  signal(SIGINT).tap( {
      self.save-categories-config;
      exit 0;
    }
  );
}

#-------------------------------------------------------------------------------
my PuzzleTable::Config $instance;
multi method instance (
  Str:D $root-global, Str:D $root-table --> PuzzleTable::Config
) {
note "$?LINE $root-global, $root-table";
  $instance = self.bless( :$root-global, :$root-table);

  $instance
}

multi method instance ( --> PuzzleTable::Config ) {
  die "No instance of Config" unless ?$instance;
  $instance
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

#-------------------------------------------------------------------------------
method store-main-window ( $main ) {
  $!main-window = $main;
}

#-------------------------------------------------------------------------------
method get-main-window ( --> Mu ) {
  $!main-window
}

#-------------------------------------------------------------------------------
method add-table-root ( Str $root-table ) {
}