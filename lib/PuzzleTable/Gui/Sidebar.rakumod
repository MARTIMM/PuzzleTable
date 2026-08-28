=begin pod

=head1 

Combobox widget to display the categories of puzzles. The widget is shown on
the main window. The actions to change the list are triggered from the
'category' menu. All changes are directly visible in the combobox on the main
page.

=end pod


use v6.d;

use PuzzleTable::Config;
use PuzzleTable::Config::DragInfo;
use PuzzleTable::Config::Category;

use PuzzleTable::Gui::Category;

use GnomeTools::Gtk::DND;

use Gnome::GObject::T-value:api<2>;

use Gnome::Gdk4::T-enums:api<2>;

use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Tooltip:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Expander:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::DropTarget:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Sidebar:auth<github:MARTIMM>;
#also is Gnome::Gtk4::ScrolledWindow;

# Make readable because the mainwindow wants to put it in a grid
has Gnome::Gtk4::ScrolledWindow $.scrolled-window;

has PuzzleTable::Config $!config;

has Array $!totals;
has Bool $!done-totals;
has Gnome::Gtk4::Grid() $!sidebar-grid;
has PuzzleTable::Config::DragInfo $!drag-info;

#-------------------------------------------------------------------------------
# Initialize from main page
submethod BUILD ( ) {
  $!config .= instance;
  $!drag-info .= instance;

  $!scrolled-window .= new-scrolledwindow;
#  $!scrolled-window.set-halign(GTK_ALIGN_FILL);
  $!scrolled-window.set-valign(GTK_ALIGN_FILL);
#  $!scrolled-window.set-vexpand(True);
  $!scrolled-window.set-propagate-natural-width(True);

#  $!scrolled-window.set-min-content-width(200);
  $!scrolled-window.set-max-content-width(450);

  self.fill-sidebar(:init);
}

#-------------------------------------------------------------------------------
# TODO $recalculate is not used ==> sidebar-status() not called with True for it
method fill-sidebar ( Bool :$init = False, Bool :$recalculate = False ) {
#`{{
Construction of the sidebar:

  The view is a ScrolledWindow with a grid as its child.
    The grid has rows for expanders holding a puzzle root. At the start, there
    is only one root at '~/.config/io.github.martimm.puzzle-table/'.
    Each expander has a grid.
      The grid has rows for expanders holding category containers.
      Each grid row has 5 columns for each category in the container.
        a button to show the puzzles in the category.
        and 4 numbers; nbr puzzles, nbr unplayed, nbr unfinished, nbr finished.
}}

  my $t0 = now;

  $!totals = [ 0, 0, 0, 0];
  $!done-totals = False;

#  my Gnome::Gtk4::Label $l;
  my Int $expander-color-count = 0; # used to change color of expanders in css
#  my Str $container;

  # Create a new sidebar grid
  $!sidebar-grid .= new-grid;
  $!sidebar-grid.set-name('sidebar');
  $!sidebar-grid.set-size-request( 200, 100);
  $!config.set-css( $!sidebar-grid.get-style-context, :css-class<pt-sidebar>);

  # Loop through all puzzle root directories
  my $nbr-roots = $!config.get-nbr-roots;
  for ^$nbr-roots -> $root-nbr {
    my Str $root-dir = $!config.get-root-path($root-nbr);
#note "$?LINE $nbr-roots, $root-nbr, $root-dir";

    my $row-count = 0;
    my Gnome::Gtk4::Grid $container-grid .= new-grid;

    # Make the puzzle root expander and set the $container-grid as its child
    my Gnome::Gtk4::Expander $root-expander =
      self.sidebar-root-expander( $root-nbr, $root-dir, $container-grid);

    # Loop through all containers and make expanders for each of them
    my @containers = $!config.get-containers($root-dir);
    for @containers -> $container {
      # Fill a grid with categories in $container and $root-dir
      my Gnome::Gtk4::Grid $category-grid = self.set-category-grid(
        $container, $root-dir, $expander-color-count
      );

      my Gnome::Gtk4::Expander $cat-expander = self.sidebar-category-expander(
        $container, $root-dir, $expander-color-count, $category-grid
      );

      # Setup DND tae=rget on the button
      my GnomeTools::Gtk::DND $dnd .= new;
      $dnd.set-droptarget(
        self, $cat-expander, :$dnd, :type<category-expander>
      );
#`{{
      $dnd.set-droptarget-event(
        self, 'cat-expander-drop-accept', 'accept', :$dnd
      );
}}
      $dnd.set-droptarget-event(
        self, 'cat-expander-drop', 'drop', :$dnd, :$container, :$root-dir
      );

      $container-grid.attach( $cat-expander, 0, $row-count, 5, 1);
      $row-count++;
    }

    $expander-color-count++;

    $!sidebar-grid.attach( $root-expander, 0, $root-nbr, 1, 1);
  }

  # Display gathered information in a tooltip
  $!done-totals = True;
  $!sidebar-grid.set-tooltip-text(Q:qq:to/EOTT/);
    Number of puzzles
    Untouched puzzles
    Unfinished puzzles
    Finished puzzles

    Totals
    [ $!totals.join(', ') ]
    EOTT

  # The scroll window widget will always cleanup the child if there was
  # a grid installed before
  $!scrolled-window.set-child($!sidebar-grid);
#note "$?LINE $!sidebar-grid.gist(), ", $!scrolled-window.get-child.gist;
my Gnome::Gtk4::Grid() $sg = $!scrolled-window.get-child;
#note "$?LINE ", $sg.gist;
#note "$?LINE ", $!sidebar-grid.get-child-at( 0, 0).gist;
my Gnome::Gtk4::Expander() $ex = $!sidebar-grid.get-child-at( 0, 0);
#note "$?LINE ", $ex.gist;

  if $init {
#    my Str $root-dir = @roots[0];
    my Str $root-dir = $!config.get-root-path(0);
    self.select-category( :category<Default>, :container<Default>, :$root-dir);
  }

  $!config.log("Time to fill sidebar: {(now - $t0).fmt('%.1f sec.')}.");
}

#`{{
#-------------------------------------------------------------------------------
method cat-expander-drop-accept (
  Gnome::Gdk4::Drop() $drop, GnomeTools::Gtk::DND :$dnd --> Bool
) {
  my Bool $accept = $dnd.check-accept( $drop, 'text');
  $!config.log("Drop on category expander can be accepted: $accept");
  $accept
}
}}

#-------------------------------------------------------------------------------
method cat-expander-drop (
  N-Value() $n-value, Rat() $x, Rat() $y,
  Gnome::Gtk4::DropTarget() :_native-object($dt),
  GnomeTools::Gtk::DND :$dnd, Str :$container, Str :$root-dir
  --> Bool
) {

#note "\n$?LINE drop, x, y = $x, $y";
  my ( Bool $internal, Str $value );
  ( $internal, $value ) = $dnd.get-dropped-value( $n-value, $dt);

  my Bool $drop-ok = False;
  if $internal {
    my ( $from-root, $from-container, $from-category, $from-puzzles ) =
       $value.split("_||_");
    $drop-ok = ?$from-puzzles;

#note "Internal drop: $internal\nDropped value:";
#note "  $drop-ok, $from-root, $from-container, $from-category: $from-puzzles";

    # Add category to list. The category is a used to drop puzzles in.
    # Message gets defined if something is wrong.
    my Str $category = 'Drop';
    my Str $msg = $!config.add-category(
      $category, $container, :$root-dir,
      :lockable(
        $!config.is-category-lockable(
          $from-category, $from-container, $from-root
        )
      )
    );

#note $from-puzzles.split(/\s+/).gist;
    # Convert indices to puzzle ids
    my @puzzles = ();
    for $from-puzzles.split(/\s+/)>>.Int -> $item-pos {
      @puzzles.push: $*main-window.table.puzzle-objects.get-string($item-pos);
    }

    # Move puzzle to new category
    for @puzzles -> $puzzle-id {
#note "move puzzle $puzzle-id";

      my PuzzleTable::Config::Category $from-config-category .= new(
        :category-name($from-category),
        :container($from-container),
        :root-dir($from-root)
      );

      $!config.move-puzzle(
        $from-config-category, $category, $container, $root-dir, $puzzle-id
      );
    }

    $*main-window.sidebar.update-sidebar(
      $from-container, $!config.get-root-title($from-root)
    );
    $*main-window.sidebar.update-sidebar(
      $container, $!config.get-root-title($root-dir)
    );

    # Select the source category again to display the changes
    $*main-window.sidebar.select-category(
      :category($from-category), :container($from-container),
      :root-dir($from-root)
    );

    my PuzzleTable::Gui::Category $category-menu .= new;
    $category-menu.category-rename2( $category, $container, $root-dir);
  }

  else {
    note "Dropping $value not accepted";
  }

  $drop-ok
}

#-------------------------------------------------------------------------------
method set-category-grid (
  Str $container, Str $root-dir, Int $expander-color-count
  --> Gnome::Gtk4::Grid
) {
  my Int $cat-row-count = 0;
  my Gnome::Gtk4::Grid $category-grid .= new-grid;

  # Get categories in for $container and $root-dir.
  my @categories = $!config.get-categories( $container, $root-dir);
  for @categories -> $category {
    # Each category is a button. When clicked, it shows the puzzles
    # of this category on the puzzle table
    my Gnome::Gtk4::Button $category-button = self!category-button(
      $category, $container, $root-dir, $expander-color-count
    );

    $category-grid.attach( $category-button, 0, $cat-row-count, 1, 1);

    # Setup DND tae=rget on the button
    my GnomeTools::Gtk::DND $dnd .= new;
    $dnd.set-droptarget( self, $category-button, :$dnd, :type<category>);
#    $dnd.set-droptarget-event( self, 'category-drop-accept', 'accept', :$dnd);
    $dnd.set-droptarget-event(
      self, 'category-drop', 'drop', :$dnd, :$category, :$container, :$root-dir
    );

    # Get information of each subcategory
    self.sidebar-status(
      $category, $container, $root-dir, $category-grid,
      $cat-row-count
      #, :$recalculate
    );

    $cat-row-count++;
  }

  $category-grid
}

#-------------------------------------------------------------------------------
method category-drop (
  N-Value() $n-value, Rat() $x, Rat() $y,
  Gnome::Gtk4::DropTarget() :_native-object($dt),
  GnomeTools::Gtk::DND :$dnd, Str :$category, Str :$container, Str :$root-dir
  --> Bool
) {
#note "\n$?LINE drop, x, y = $x, $y";
  my ( Bool $internal, Str $value );
  ( $internal, $value ) = $dnd.get-dropped-value( $n-value, $dt);

  my Bool $drop-ok = False;
  if $internal {
    my ( $from-root, $from-container, $from-category, $from-puzzles ) =
       $value.split("_||_");
    $drop-ok = ?$from-puzzles;

#note "Internal drop: $internal\nDropped value:";
#note "  $drop-ok, $from-root, $from-container, $from-category: $from-puzzles";

#note $from-puzzles.split(/\s+/).gist;
    my @puzzles = ();
    for $from-puzzles.split(/\s+/)>>.Int -> $item-pos {
      @puzzles.push: $*main-window.table.puzzle-objects.get-string($item-pos);
    }

    for @puzzles -> $puzzle-id {
#note "move puzzle $puzzle-id";

      my PuzzleTable::Config::Category $from-config-category .= new(
        :category-name($from-category),
        :container($from-container),
        :root-dir($from-root)
      );

      $!config.move-puzzle(
        $from-config-category, $category, $container, $root-dir, $puzzle-id
      );
    }

    $*main-window.sidebar.update-sidebar(
      $from-container, $!config.get-root-title($from-root)
    );
    $*main-window.sidebar.update-sidebar(
      $container, $!config.get-root-title($root-dir)
    );

    # Select the source category again to display the changes
    $*main-window.sidebar.select-category(
      :category($from-category), :container($from-container),
      :root-dir($from-root)
    );
  }

  else {
    # Puzzles from disk
    note "Dropping $value not accepted";
  }

  $drop-ok
}

#-------------------------------------------------------------------------------
method drop-accept (
  Gnome::Gdk4::Drop() $drop, GnomeTools::Gtk::DND :$dnd, Str :$type --> Bool
) {
  my Bool $accept = $dnd.check-accept( $drop, 'text');
  $!config.log("Drop on $type can be accepted: $accept");
  $accept
}

#-------------------------------------------------------------------------------
# Notion for all drop targets
method drop-enter ( Rat() $x, Rat() $y --> UInt ) {
note "Enter dropzone at $x, $y";
  GDK_ACTION_MOVE;
}

#-------------------------------------------------------------------------------
# Make a category button to display the puzzles in this category
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
        .get-style-context, :css-class<sidebar-root-expander-label>
      );
    }

    .set-label-widget($l);
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_FILL);

    .set-expanded($!config.is-root-expanded($root-nbr));
    .set-child($container-grid);

#    $!config.set-css( .get-style-context, :css-class<root-expander>);

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
        .get-style-context, :css-class<sidebar-container-expander-label>
      );
    }

    .set-label-widget($l);
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_FILL);

    .set-child($category-grid);
    .set-expanded($!config.is-expanded( $container, $root-dir));

    $!config.set-css( .get-style-context, :css-class<category-expander>);

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
  Gnome::Gtk4::Grid $grid, Int $row-count,
  Bool :$recalculate = False,
) {
  my Gnome::Gtk4::Label $l;

  my Array $cat-status = $!config.get-category-status(
    $category, $container, $root-dir, :$recalculate
  );
#note "$?LINE $row-count, $cat-status.gist()";

  $l .= new-label; $l.set-text($cat-status[0].fmt('%3d'));
  $grid.attach( $l, 1, $row-count, 1, 1);
  $!totals[0] += $cat-status[0] unless $!done-totals;

  $l .= new-label; $l.set-text($cat-status[1].fmt('%3d'));
  $grid.attach( $l, 2, $row-count, 1, 1);
  $!totals[1] += $cat-status[1] unless $!done-totals;

  $l .= new-label; $l.set-text($cat-status[2].fmt('%3d'));
  $grid.attach( $l, 3, $row-count, 1, 1);
  $!totals[2] += $cat-status[2] unless $!done-totals;

  $l .= new-label; $l.set-text($cat-status[3].fmt('%3d'));
  $l.set-margin-end(10);
  $grid.attach( $l, 4, $row-count, 1, 1);
  $!totals[3] += $cat-status[3] unless $!done-totals;
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
  my $t0 = now;

  my Str $root-title = $!config.get-root-title($root-dir);
  my Str $title = "Category $category in $container at $root-title";
  $*main-window.application.application-window.set-title($title)
    if ?$*main-window.application.application-window;

  # Clear the puzzle table before showing the puzzles of this category
  $*main-window.table.clear-table;

  # Get the puzzles and send them to the table
  $!config.select-category( $category, $container, $root-dir);
  my Seq $puzzles = $!config.get-puzzles;

  # Fill the puzzle table with new puzzles
  $*main-window.table.add-puzzles-to-table($puzzles);

  $!config.log( "Select category: $category - $container - $root-title", :$t0);
}

#-------------------------------------------------------------------------------
# Method to handle a category selection
method set-category ( Str:D $category, Str:D $container, Str :$root-dir ) {

#  # Fill the sidebar in case there is a new entry
#  self.fill-sidebar;
  self.select-category( :$category, :$container, :$root-dir);
}

#-------------------------------------------------------------------------------
multi method update-sidebar ( Str:D $container ) {
  self.update-sidebar( $container, $!config.get-current-root, :!root-is-title);
}

#-------------------------------------------------------------------------------
multi method update-sidebar (
  Str:D $container, Str:D $root, Bool :$root-is-title = True
) {
  my $t0 = now;
  my Str $root-title;
  my Str $root-dir;
  if $root-is-title {
    $root-title = $root;
    $root-dir = $!config.get-root-path($root-title);
  }

  else {
    $root-title = $!config.get-root-title($root);
    $root-dir = $root;
  }

  # Get the child from the scrolled window which is a grid holding expanders
  # for the root directories.
#  $!sidebar-grid = $!scrolled-window.get-child;
note "$?LINE ", $!sidebar-grid.get-child-at( 0, 0).gist;
  # Get the expander of the particular root
  my Int $row-count = $!config.get-root-nbr($root-title);
  my Gnome::Gtk4::Expander() $root-expander =
    $!sidebar-grid.get-child-at( 0, $row-count);

  # Find the container where the categories need to be updated.
note "$?LINE $row-count, $root-title, ", $root-expander.gist;
  my Gnome::Gtk4::Grid() $container-grid = $root-expander.get-child;
  my $c-count = 0;
  my @containers = $!config.get-containers($root-dir);
  for @containers -> $c {
note "$?LINE $root-dir, container $c ~~ $container";
    if $container ~~ m/^ $c '_EX_'? $/ {
      my Gnome::Gtk4::Expander() $container-expander =
        $container-grid.get-child-at( 0, $c-count);
      my Gnome::Gtk4::Grid() $category-grid = self.set-category-grid(
        $container, $root-dir, $row-count
      );

      $container-expander.set-child($category-grid);

      last;
    }

    $c-count++;
  }
  $!config.log( "Time to update sidebar for $container at $root-title", :$t0);
}
