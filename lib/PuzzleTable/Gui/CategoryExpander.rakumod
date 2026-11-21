use v6.d;

use Gnome::Gtk4::Tooltip:api<2>;
use Gnome::Gtk4::Expander:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::DropTarget:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Button:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use Gnome::GObject::T-value:api<2>;

use Gnome::Gdk4::T-enums:api<2>;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::Category;
#use PuzzleTable::Config::DragInfo;
use PuzzleTable::Config::Category;

use GnomeTools::Gtk::DND;

=begin pod
=TITLE PuzzleTable::Gui::CategoryExpander

=head1 Description

Purpose is to hold a part of the categories from a root/container and
displayes it in an Expander.

=end pod

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::CategoryExpander;
also is Gnome::Gtk4::Expander;

has Str $!container;
has Str $!root-dir;
has PuzzleTable::Config $!config;
#has PuzzleTable::Config::DragInfo $!drag-info;

#-------------------------------------------------------------------------------
submethod new ( |c ) {
  self.new-expander( Str, |c);
}

#-------------------------------------------------------------------------------
submethod BUILD (
  Str :$!container, Str :$!root-dir, UInt :$expander-color-count
) {
  $!config .= instance;
#  $!drag-info .= instance;

  with self {
    # Set CSS classes for the expander
    my Str $css-class = "pt-sidebar-expander-ptr$expander-color-count";
#note "$?LINE $container, $css-class";
#$root-dir.IO.basename
    $!config.set-css( .get-style-context, :$css-class);
    $!config.set-css( .get-style-context, :css-class<category-expander>);

    # Make a label to use as a title in the expander
    given my Gnome::Gtk4::Label $l .= new-label {
      .set-text($!container);
      .set-hexpand(True);
      .set-halign(GTK_ALIGN_START);
      $!config.set-css(
        .get-style-context, :css-class<sidebar-container-expander-label>
      );
    }

    # Set the title with the label
    .set-label-widget($l);

    # Stretch and fill the expander in the parent widget
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_FILL);

    # Create and place the catagory grid in the expander
#    my Gnome::Gtk4::Grid $category-grid = self.set-category-grid(
#      $expander-color-count
#    );
#    .set-child($category-grid);
    self.set-category-grid($expander-color-count);

    # Expand the widget if opened.
    .set-expanded($!config.is-expanded( $!container, $!root-dir));

    # Open or close the expander widget
    .register-signal( self, 'expand-category-container', 'activate');
  }

  # Setup DND target on the expander
  my GnomeTools::Gtk::DND $dnd .= new;
  $dnd.set-droptarget(
    self, self, :$dnd, :type<category-expander>
  );

#  $dnd.set-droptarget-event( self, 'cat-expander-drop-accept', 'accept', :$dnd);
  $dnd.set-droptarget-event( self, 'cat-expander-drop', 'drop', :$dnd);
}

#-------------------------------------------------------------------------------
method expand-category-container ( ) {
  $!config.set-expand(
    $!container, $!root-dir, self.get-expanded ?? False !! True
  );
}

#-------------------------------------------------------------------------------
#method set-category-grid ( Int $expander-color-count --> Gnome::Gtk4::Grid ) {
method set-category-grid ( Int $expander-color-count ) {
  my Int $cat-row-count = 0;
  my Gnome::Gtk4::Grid $category-grid .= new-grid;

  # Get categories for $!container and $!root-dir.
  my @categories = $!config.get-categories( $!container, $!root-dir);
  for @categories -> $category {

    # Each category is a button. When clicked, it shows the puzzles
    # of this category on the puzzle table
    my Gnome::Gtk4::Button $category-button = self!category-button(
      $category, $expander-color-count
    );

    $category-grid.attach( $category-button, 0, $cat-row-count, 1, 1);

    # Setup DND target on the button
    my GnomeTools::Gtk::DND $dnd .= new;
    $dnd.set-droptarget( self, $category-button, :$dnd, :type<category>);
    $dnd.set-droptarget-event(
      self, 'category-drop', 'drop', :$dnd, :$category
    );

    # Get information of each subcategory
    $*main-window.sidebar.sidebar-status(
      $category, $!container, $!root-dir, $category-grid,
      $cat-row-count
    );

    $cat-row-count++;
  }

  self.set-child($category-grid);
}

#-------------------------------------------------------------------------------
# Make a category button to display the puzzles in this category
method !category-button (
  Str:D $category, Int $expander-color-count --> Gnome::Gtk4::Button
) {
#note "$?LINE $category, $category, $!container, $!root-dir";

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
      self, 'show-tooltip', 'query-tooltip', :$category,
      :$!container, :$!root-dir
    );

    .register-signal(
      self, 'select-category-in-sidebar', 'clicked', :$category, :$cat-button
    );
  }

  $cat-button
}

#-------------------------------------------------------------------------------
method category-drop (
  N-Value() $n-value, Rat() $x, Rat() $y,
  Gnome::Gtk4::DropTarget() :_native-object($dt),
  GnomeTools::Gtk::DND :$dnd, Str :$category
  --> Bool
) {
#note "\n$?LINE drop, x, y = $x, $y";
  my ( Bool $internal, Str $value );
  ( $internal, $value ) = $dnd.get-dropped-value( $n-value, $dt);

  my Bool $drop-ok = False;

  # Are we moving puzzles around?
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
        $from-config-category, $category, $!container, $!root-dir, $puzzle-id
      );
    }

    $*main-window.sidebar.update-sidebar(
      $from-container, $!config.get-root-title($from-root)
    );
    $*main-window.sidebar.update-sidebar(
      $!container, $!config.get-root-title($!root-dir)
    );

    # Select the source category again to display the changes
    $*main-window.sidebar.select-category(
      :category($from-category), :container($from-container),
      :root-dir($from-root)
    );
  }

  # Or are they from abroad, i.e. imported puzzles?
  else {
    # Recalculate the status because there are added puzzles
    my Array $status-before = $!config.get-category-status(
      $category, $!container, $!root-dir
    );

    # Importing puzzles from disk using DND
    $!config.select-category( $category, $!container, $!root-dir);

    my regex puzzle-regex { $<puzzle-path> = ['/' .*? '.puzzle'] };
    while $value ~~ m/ <puzzle-regex> / {
      my Str $puzzle-path = $/<puzzle-regex><puzzle-path>.Str;
      note "$?LINE $puzzle-path";
      $value ~~ s/$puzzle-path//;

      my Str $puzzle-id = $!config.add-puzzle($puzzle-path);
      $*main-window.table.add-puzzle-to-table( $category, $puzzle-id);
    }

    # Recalculate the status because there are added puzzles
    my Array $status-after = $!config.get-category-status(
      $category, $!container, $!root-dir
    );

    # The images come from outside so only the total and untouched puzzles
    # must be updated
#note "$?LINE $status-before[0] -> $status-after[0]";

    my UInt $t = $status-after[0] - $status-before[0];
    my Bool $v = self.process-totals( :set, :a( $t, $t, 0, 0), :receive);
    $!config.log("Totals check after set [ $t, $t, 0, 0]: $v");

#note "$?LINE update DND: $category, $!container, $!root-dir";
    $*main-window.sidebar.select-category(
      :$category, :$!container, :$!root-dir
    );
    $*main-window.sidebar.update-sidebar(
      $!container, $!root-dir, :!root-is-title
    );

    $drop-ok = True;
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
note "$?LINE Enter dropzone at $x, $y";
  GDK_ACTION_COPY;
}

#`{{
#-------------------------------------------------------------------------------
method cat-expander-drop-accept (
  Gnome::Gdk4::Drop() $drop, GnomeTools::Gtk::DND :$dnd --> Bool
) {
  my Bool $accept = $dnd.check-accept( $drop, 'text');
#  my ( Bool $internal, Str $value );
#  ( $internal, $value ) = $dnd.get-dropped-value( $n-value, $dt);
note "$?LINE internal?: ";
  $!config.log("Drop on category expander can be accepted: $accept");
  $accept
}
}}

#-------------------------------------------------------------------------------
method cat-expander-drop (
  N-Value() $n-value, Rat() $x, Rat() $y,
  Gnome::Gtk4::DropTarget() :_native-object($dt), GnomeTools::Gtk::DND :$dnd
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
      $category, $!container, :$!root-dir,
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
        $from-config-category, $category, $!container, $!root-dir, $puzzle-id
      );
    }

    $*main-window.sidebar.update-sidebar(
      $from-container, $!config.get-root-title($from-root)
    );
    $*main-window.sidebar.update-sidebar(
      $!container, $!config.get-root-title($!root-dir)
    );

    # Select the source category again to display the changes
    $*main-window.sidebar.select-category(
      :category($from-category), :container($from-container),
      :root-dir($from-root)
    );

    my PuzzleTable::Gui::Category $category-menu .= new;
    $category-menu.category-rename2( $category, $!container, $!root-dir);
  }

  else {
    note "Dropping $value not accepted";

  }

  $drop-ok
}

#-------------------------------------------------------------------------------
method show-tooltip (
  Int $x, Int $y, gboolean $kb-mode, Gnome::Gtk4::Tooltip() $tooltip,
  Str :$category
  --> gboolean
) {
  my Str $puzzle-image-name = $!config.get-puzzle-image(
    $category, $!container, $!root-dir
  );
  if ?$puzzle-image-name {
    my Gnome::Gtk4::Picture $p .= new-picture;
    $p.set-filename($puzzle-image-name);
    $tooltip.set-custom($p);
  }

  True
}

#-------------------------------------------------------------------------------
method select-category-in-sidebar (
  Str:D :$category, Gnome::Gtk4::Button :$cat-button
) {
  $*main-window.sidebar.select-category(
    :$category, :$!container, :$!root-dir, :$cat-button
  );
}

#-------------------------------------------------------------------------------
method process-totals (|c) {
  $!config.emit-data( :code(PROCESS_TOTALS), |c);
}
