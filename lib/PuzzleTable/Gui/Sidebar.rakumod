=begin pod

=head1 

Combobox widget to display the categories of puzzles. The widget is shown on
the main window. The actions to change the list are triggered from the
'category' menu. All changes are directly visible in the combobox on the main
page.

=end pod


use v6.d;

use PuzzleTable::Config;

use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Tooltip:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Expander:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Sidebar:auth<github:MARTIMM>;
also is Gnome::Gtk4::ScrolledWindow;

has PuzzleTable::Config $!config;

#-------------------------------------------------------------------------------
# Initialize from main page
submethod BUILD ( ) {
  $!config .= instance;

#  self.set-halign(GTK_ALIGN_FILL);
  self.set-valign(GTK_ALIGN_FILL);
#  self.set-vexpand(True);
  self.set-propagate-natural-width(True);

#  self.set-min-content-width(200);
  self.set-max-content-width(450);

  self.fill-sidebar(:init);
}

#-------------------------------------------------------------------------------
# TODO $recalculate is not used ==> sidebar-status() not called with True for it
method fill-sidebar ( Bool :$init = False, Bool :$recalculate = False ) {
#`{{
Construction of the sidebar:

  The view is a ScrolledWindow with a grid as its child
    The grid has rows for expanders holding a puzzle root. At the start, there
    is only one at '~/.config/io.github.martimm.puzzle-table/'.
    Each expander has a grid.
      The grid has rows for expanders holding category containers
      Each grid row has 5 columns for each category in the container
        a button to show the puzzles in the category
        and 4 numbers; nbr puzzles, nbr unplayed, nbr unfinished, nbr finished
}}

  my $t0 = now;

#  my Gnome::Gtk4::Label $l;
  my Array $totals = [ 0, 0, 0, 0];
  my Int $expander-color-count = 0; # used to change color of expanders in css
#  my Str $container;

  # Create a new sidebar grid
  my Gnome::Gtk4::Grid() $sidebar-grid .= new-grid;
  $sidebar-grid.set-name('sidebar');
  $sidebar-grid.set-size-request( 200, 100);
  $!config.set-css( $sidebar-grid.get-style-context, :css-class<pt-sidebar>);


#  my @roots = $!config.get-roots;
#  for @roots -> $root-dir {

  # Loop through all puzzle root directories
  my $nbr-roots = $!config.get-nbr-roots;
  for ^$nbr-roots -> $root-nbr {
    my Str $root-dir = $!config.get-root-path($root-nbr);

    my $row-count = 0;
    my Gnome::Gtk4::Grid $container-grid .= new-grid;

    # Make the puzzle root expander and set the $container-grid as its child
    my Gnome::Gtk4::Expander $root-expander =
      self.sidebar-root-expander( $root-nbr, $root-dir, $container-grid);

    # Loop through all containers and make expanders for each of them
    my @containers = $!config.get-containers($root-dir);
    for @containers -> $container {
      # Fill a grid with category rows in $container and $root-dir
      my Gnome::Gtk4::Grid $category-grid = self.set-category-grid(
        $container, $root-dir, $expander-color-count, $totals
      );

      my Gnome::Gtk4::Expander $cat-expander = self.sidebar-category-expander(
        $container, $root-dir, $expander-color-count, $category-grid
      );

      $container-grid.attach( $cat-expander, 0, $row-count, 5, 1);
      $row-count++;
    }

    $expander-color-count++;

    $sidebar-grid.attach( $root-expander, 0, $root-nbr, 1, 1);
  }

  # Display gathered information in a tooltip
  $sidebar-grid.set-tooltip-text(Q:qq:to/EOTT/);
    Number of puzzles
    Untouched puzzles
    Unfinished puzzles
    Finished puzzles

    Totals
    [ $totals.join(', ') ]
    EOTT

  # The scroll window widget will alway cleanup the child if there was
  # a grid installed before
  self.set-child($sidebar-grid);
  if $init {
#    my Str $root-dir = @roots[0];
    my Str $root-dir = $!config.get-root-path(0);
    self.select-category( :category<Default>, :container<Default>, :$root-dir);
  }

  $*log-file.spurt(
    "Time to fill sidebar: {(now - $t0).fmt('%.1f sec.')}.\n",
    :append
  ) if $*verbose-output;
}

#-------------------------------------------------------------------------------
method set-category-grid (
  Str $container, Str $root-dir, Int $expander-color-count, Array $totals
  --> Gnome::Gtk4::Grid
) {
  my Int $cat-row-count = 0;
  my Gnome::Gtk4::Grid $category-grid .= new-grid;

  # In each expander the categories are placed
  my @categories = $!config.get-categories( $container, $root-dir);
  for @categories -> $category {
    my Gnome::Gtk4::Button $category-button = self!category-button(
      $category, $container, $root-dir, $expander-color-count
    );

    $category-grid.attach( $category-button, 0, $cat-row-count, 1, 1);

    # Get information of each subcategory
    self.sidebar-status(
      $category, $container, $root-dir, $category-grid,
      $cat-row-count, $totals
      #, :$recalculate
    );

    $cat-row-count++;
  }
  
  $category-grid
}

#-------------------------------------------------------------------------------
method !category-button (
  Str:D $category, Str:D $container, Str:D $root-dir, Int $expander-color-count
  --> Gnome::Gtk4::Button
) {
#note "$?LINE $category, $category, $container, $root-dir";

  with my Gnome::Gtk4::Button $cat-button .= new-button {
    $!config.set-css(
      .get-style-context,
      :css-class('pt-sidebar-container-button')
    );

    with my Gnome::Gtk4::Label $l .= new-label {
      .set-text($category);
#      .set-halign(GTK_ALIGN_START);
#      .set-justify(GTK_JUSTIFY_LEFT);
      .set-hexpand(True);
      .set-max-width-chars(25);
#      .set-ellipsize(True);

#        :css-class('pt-sidebar-category-label')
      $!config.set-css(
        .get-style-context,
        :css-class("pt-sidebar-expander-ptr$expander-color-count")
      );
    }

    .set-child($l);
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_FILL);
    .set-has-tooltip(True);

    $!config.set-css(
      .get-style-context, :css-class('pt-sidebar-expander-button')
    );

    .register-signal(
      self, 'show-tooltip', 'query-tooltip', :$category, :$container, :$root-dir
    );
    .register-signal(
      self, 'select-category', 'clicked', :$category, :$container, :$root-dir
    );
  }

  $cat-button
}

#-------------------------------------------------------------------------------
method sidebar-root-expander (
  Int $root-nbr, Str $root-dir, Gnome::Gtk4::Grid $container-grid
  --> Gnome::Gtk4::Expander
) {
  with my Gnome::Gtk4::Expander $expander .= new-expander(Str) {
    given my Gnome::Gtk4::Label $l .= new-label {
      .set-text($!config.get-root-title($root-nbr));
      .set-hexpand(True);
      .set-halign(GTK_ALIGN_START);
      $!config.set-css(
        .get-style-context, :css-class<sidebar-expander-label>
      );
    }

    .set-label-widget($l);
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_FILL);

    .set-expanded($!config.is-root-expanded($root-nbr));
    .set-child($container-grid);

    .register-signal( self, 'expand-root', 'activate', :$root-nbr);
  }

  $expander
}

#-------------------------------------------------------------------------------
method expand-root (
  Gnome::Gtk4::Expander() :_native-object($expander), Int :$root-nbr
) {
  $!config.set-root-expanded(
    $root-nbr, $expander.get-expanded ?? False !! True
  );
#  $!config.set-expand(
#    $container, $root-dir, $expander.get-expanded ?? False !! True
#  );
#note "$?LINE expand root $root-dir";
}

#-------------------------------------------------------------------------------
method sidebar-category-expander (
  Str $container, Str $root-dir, Int $expander-color-count,
  Gnome::Gtk4::Grid $category-grid
  --> Gnome::Gtk4::Expander
) {
  with my Gnome::Gtk4::Expander $expander .= new-expander(Str) {
    my Str $css-class = "pt-sidebar-expander-ptr$expander-color-count";
#note "$?LINE $container, $css-class";
#$root-dir.IO.basename
    $!config.set-css( .get-style-context, :$css-class);

    given my Gnome::Gtk4::Label $l .= new-label {
      .set-text($container);
      .set-hexpand(True);
      .set-halign(GTK_ALIGN_START);
      $!config.set-css(
        .get-style-context, :css-class<sidebar-expander-label>
      );
    }

    .set-label-widget($l);
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_FILL);

    .set-child($category-grid);
    .set-expanded($!config.is-expanded( $container, $root-dir));

    .register-signal( self, 'expand-category-container', 'activate', :$container, :$root-dir);
  }
  
  $expander
}

#-------------------------------------------------------------------------------
method expand-category-container (
  Gnome::Gtk4::Expander() :_native-object($expander), Str :$container,
  Str :$root-dir
) {
  $!config.set-expand(
    $container, $root-dir, $expander.get-expanded ?? False !! True
  );
}

#-------------------------------------------------------------------------------
method sidebar-status (
  Str:D $category, Str:D $container, Str:D $root-dir,
  Gnome::Gtk4::Grid $grid, Int $row-count, Array $totals,
  Bool :$recalculate = False,
) {
  my Gnome::Gtk4::Label $l;

  my Array $cat-status = $!config.get-category-status(
    $category, $container, $root-dir, :$recalculate
  );

  $l .= new-label; $l.set-text($cat-status[0].fmt('%3d'));
  $grid.attach( $l, 1, $row-count, 1, 1);
  $totals[0] += $cat-status[0];

  $l .= new-label; $l.set-text($cat-status[1].fmt('%3d'));
  $grid.attach( $l, 2, $row-count, 1, 1);
  $totals[1] += $cat-status[1];

  $l .= new-label; $l.set-text($cat-status[2].fmt('%3d'));
  $grid.attach( $l, 3, $row-count, 1, 1);
  $totals[2] += $cat-status[2];

  $l .= new-label; $l.set-text($cat-status[3].fmt('%3d'));
  $l.set-margin-end(10);
  $grid.attach( $l, 4, $row-count, 1, 1);
  $totals[3] += $cat-status[3];
}

#-------------------------------------------------------------------------------
method show-tooltip (
  Int $x, Int $y, gboolean $kb-mode, Gnome::Gtk4::Tooltip() $tooltip,
  Str :$category, Str :$container, Str :$root-dir
  --> gboolean
) {
  my Str $puzzle-image-name = $!config.get-puzzle-image(
    $category, $container, $root-dir
  );
  if ?$puzzle-image-name {
    my Gnome::Gtk4::Picture $p .= new-picture;
    $p.set-filename($puzzle-image-name);
    $tooltip.set-custom($p);
  }

  True
}

#-------------------------------------------------------------------------------
# Method to handle a category selection
method select-category (
  Str:D :$category, Str:D :$container, Str:D :$root-dir
) {
#  $!current-category = $category;
  my $root-text =
    (?$root-dir and $*multiple-roots) ?? "Root path $root-dir, " !! '';
  my Str $title = "Puzzle Table Display: {$root-text}Container $container, Category $category";
  $*main-window.application.application-window.set-title($title)
    if ?$*main-window.application.application-window;

  # Clear the puzzle table before showing the puzzles of this category
  $*main-window.table.clear-table;

  # Get the puzzles and send them to the table
  $!config.select-category( $category, $container, $root-dir);
  my Seq $puzzles = $!config.get-puzzles;

  # Fill the puzzle table with new puzzles
  $*main-window.table.add-puzzles-to-table($puzzles);
}

#-------------------------------------------------------------------------------
# Method to handle a category selection
method set-category ( Str:D $category, Str:D $container, Str :$root-dir ) {

#  # Fill the sidebar in case there is a new entry
#  self.fill-sidebar;
  self.select-category( :$category, :$container, :$root-dir);
}

#-------------------------------------------------------------------------------
method update-sidebar ( Str:D $container, Str:D $root-dir ) {
  my $t0 = now;

  # Get the child from the scrollbar which is a grid.
  my Gnome::Gtk4::Grid() $cat-grid = self.get-child;

  $*log-file.spurt(
    "Time to update sidebar: {(now - $t0).fmt('%.1f sec.')}.\n",
    :append
  ) if $*verbose-output;
}
