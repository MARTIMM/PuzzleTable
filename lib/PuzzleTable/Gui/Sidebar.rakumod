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

has $!main is required;
has PuzzleTable::Config $!config;

#-------------------------------------------------------------------------------
# Initialize from main page
submethod BUILD ( :$!main ) {
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
method fill-sidebar ( Bool :$init = False ) {
#note "$?LINE fill sidebar";

  # Get the child from the scrollbar which is a grid and clear it.
  my Gnome::Gtk4::Grid() $cat-grid = self.get-child;
  $cat-grid.clear-object;

  # Create new sidebar
  my $row-count = 0;

  $cat-grid .= new-grid;
  $cat-grid.set-name('sidebar');
  $cat-grid.set-size-request( 200, 100);
  $!config.set-css( $cat-grid.get-style-context, :css-class<pt-sidebar>);

  my Gnome::Gtk4::Label $l;
  my Array $totals = [ 0, 0, 0, 0];
  my Str $prev-root-dir;
  my Int $expander-color-count;
  my Str $root-dir;
  my Str $container;

  for $!config.get-roots -> $root-dir {
    my @containers = $!config.get-containers($root-dir);
    for @containers -> $container {
      if !$prev-root-dir {
        $prev-root-dir = $root-dir;
        $expander-color-count = 0;
      }

      elsif $prev-root-dir ne $root-dir {
        $prev-root-dir = $root-dir;
        $expander-color-count++;
      }

      my Int $cat-row-count = 0;
      my Gnome::Gtk4::Grid $category-grid .= new-grid;

      my @categories = $!config.get-categories( $container, $root-dir);
      for @categories -> $category {
        my Gnome::Gtk4::Button $category-button =
          self.category-button( $category, $container, :$root-dir);

        $category-grid.attach( $category-button, 0, $cat-row-count, 1, 1);

        # Get information of each subcategory
        self.sidebar-status(
          $category, $container, $root-dir, $category-grid,
          $cat-row-count, $totals
        );

        $cat-row-count++;
      }

      my Gnome::Gtk4::Expander $expander = self.sidebar-expander(
        $container, $root-dir, $expander-color-count
      );

      $expander.set-child($category-grid);
      $expander.set-expanded($!config.is-expanded( $container, $root-dir));
      $cat-grid.attach( $expander, 0, $row-count, 5, 1);

      $row-count++;
    }
  }

  # Display gathered information in a tooltip
  $cat-grid.set-tooltip-text(Q:qq:to/EOTT/);
    Number of puzzles
    Untouched puzzles
    Unfinished puzzles
    Finished puzzles

    Totals
    [ $totals.join(', ') ]
    EOTT

  self.set-child($cat-grid);
  self.select-category(
    :category<Default>, :container<Default>, :$root-dir
  ) if $init;
}

#-------------------------------------------------------------------------------
method category-button (
  Str:D $category, Str:D $container, Str :$root-dir --> Gnome::Gtk4::Button
) {
  with my Gnome::Gtk4::Button $cat-button .= new-button {
    $!config.set-css(
      .get-style-context,
      :css-class('pt-sidebar-container-button')
    );

    given my Gnome::Gtk4::Label $l .= new-label {
      .set-text($category);
      .set-hexpand(True);
      .set-halign(GTK_ALIGN_START);
      .set-max-width-chars(25);
#      .set-ellipsize(True);

      $!config.set-css(
        .get-style-context,
        :css-class('pt-sidebar-category-label')
      );
    }

    .set-child($l);
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_FILL);
    .set-has-tooltip(True);

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
method sidebar-expander (
  Str $container, Str $root-dir, Int $expander-color-count
  --> Gnome::Gtk4::Expander
) {
  with my Gnome::Gtk4::Expander $expander .= new-expander(Str) {
    my Str $css-class = "pt-sidebar-expander-ptr$expander-color-count";
#note "$?LINE $container, $css-class";

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

    .register-signal( self, 'expand', 'activate', :$container, :$root-dir);
  }
  
  $expander
}

#-------------------------------------------------------------------------------
method expand (
  Gnome::Gtk4::Expander() :_native-object($expander), Str :$container,
  Str :$root-dir
) {
  $!config.set-expand(
    $container, $root-dir, $expander.get-expanded ?? False !! True
  );
}

#-------------------------------------------------------------------------------
method sidebar-status (
  Str:D $category, Str:D $container, $root-dir,
  Gnome::Gtk4::Grid $grid, Int $row-count, Array $totals,
) {
  my Gnome::Gtk4::Label $l;

  my Array $cat-status =
     $!config.get-category-status( $category, $container, $root-dir);

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
  Str:D :$category, Str:D :$container, Str :$root-dir
) {
#  $!current-category = $category;
  my $root-text = (?$root-dir and $*multiple-roots) ?? "- $root-dir -" !! '';
  my Str $title = "Puzzle Table Display: $root-text $category in $container";
  $!main.application-window.set-title($title) if ?$!main.application-window;

  # Clear the puzzle table before showing the puzzles of this category
  $!main.table.clear-table;

  # Get the puzzles and send them to the table
  $!config.select-category( $category, $container, :$root-dir);
  my Seq $puzzles = $!config.get-puzzles;

  # Fill the puzzle table with new puzzles
  $!main.table.add-puzzles-to-table($puzzles);
}

#-------------------------------------------------------------------------------
# Method to handle a category selection
method set-category ( Str:D $category, Str:D $container, Str :$root-dir ) {

  # Fill the sidebar in case there is a new entry
  self.fill-sidebar;
  self.select-category( :$category, :$container, :$root-dir);
}
