#`{{
Combobox widget to display the categories of puzzles. The widget is shown on
the main window. The actions to change the list are triggered from the
'category' menu. All changes are directly visible in the combobox on the main
page.
}}

use v6.d;

use PuzzleTable::Config;
use PuzzleTable::Gui::Dialog;

#use Gnome::Gtk4::Entry:api<2>;
#use Gnome::Gtk4::PasswordEntry:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Tooltip:api<2>;
#use Gnome::Gtk4::CheckButton:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Grid:api<2>;
#use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Expander:api<2>;
#use Gnome::Gtk4::ComboBoxText:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::DropDown:api<2>;
use Gnome::Gtk4::StringList:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Sidebar:auth<github:MARTIMM>;
also is Gnome::Gtk4::ScrolledWindow;

has $!main is required;
has PuzzleTable::Config $!config;
#has Gnome::Gtk4::Grid $!cat-grid;
#has Str $!current-category;

#-------------------------------------------------------------------------------
# Initialize from main page
submethod BUILD ( :$!main ) {
  $!config = $!main.config;

  self.set-halign(GTK_ALIGN_FILL);
  self.set-valign(GTK_ALIGN_FILL);
  self.set-vexpand(True);
  self.set-propagate-natural-width(True);

  self.set-min-content-width(0);
  self.set-max-content-width(450);

  self.fill-sidebar(:init);
}

#-------------------------------------------------------------------------------
method fill-sidebar ( Bool :$init = False ) {
  my Gnome::Gtk4::Grid() $cat-grid = self.get-child;
  $cat-grid.clear-object;

  # Remove all buttons and info from sidebar
#  if ?$!cat-grid and $!cat-grid.is-valid {
#    $!cat-grid.clear-object;
#  }

  # Create new sidebar
  my $row-count = 0;
  #with $!cat-grid .= new-grid {
    $cat-grid .= new-grid;
    $cat-grid.set-name('sidebar');
    $cat-grid.set-size-request( 200, 100);
    $!config.set-css(
      $cat-grid.get-style-context, :css-class<pt-sidebar>
    );

    my Gnome::Gtk4::Label $l;

    my Array $totals = [ 0, 0, 0, 0];
    for $!config.get-categories -> $category {
#note "$?LINE $category";
      if $category ~~ m/ '_EX_' $/ {
        my Str $category-container = $category;
        $category-container ~~ s/ '_EX_' $//;
        my Int $subcat-row-count = 0;
        my Gnome::Gtk4::Grid $subcat-grid .= new-grid;
        for $!config.get-categories(:$category-container) -> $sub-category {
          my Gnome::Gtk4::Button $subcat-button =
             self.sidebar-button( $sub-category, $category-container);

          $subcat-grid.attach( $subcat-button, 0, $subcat-row-count, 1, 1);

          # Get information of each subcategory
          self.sidebar-status(
            $sub-category, $subcat-grid, $subcat-row-count, $totals,
            :$category-container
          );

          $subcat-row-count++;
        }

        # Only show container if there are any categories visible
        if $subcat-row-count {
          my Gnome::Gtk4::Expander $expander =
            self.sidebar-expander($category-container);
          $expander.set-child($subcat-grid);
          $cat-grid.attach( $expander, 0, $row-count, 5, 1);
        }
      }

      else {
        my Gnome::Gtk4::Button $cat-button = self.sidebar-button($category);
        $cat-grid.attach( $cat-button, 0, $row-count, 1, 1);

        # Get information of each category
        self.sidebar-status( $category, $cat-grid, $row-count, $totals);
      }

      $row-count++;
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
  #}

  self.set-child($cat-grid);
  self.select-category(:category<Default>) if $init;
}

#-------------------------------------------------------------------------------
method sidebar-button (
  Str $category, Str $category-container = '' --> Gnome::Gtk4::Button
) {
  with my Gnome::Gtk4::Button $cat-button .= new-button {
    $!config.set-css(
      .get-style-context,
      :css-class( ? $category-container
                  ?? 'pt-sidebar-container-button'
                  !! 'pt-sidebar-category-button'
                )
    );

    my Str $catname = ?$category-container ?? $category-container !! $category;

    given my Gnome::Gtk4::Label $l .= new-label {
      .set-text($category);
      .set-hexpand(True);
      .set-halign(GTK_ALIGN_START);
#      .set-max-width-chars(? $category-container ?? 23 !! 25 );
#      .set-ellipsize(True);

      $!config.set-css(
        .get-style-context,
        :css-class(
          ? $category-container
            ?? 'pt-sidebar-container-label'
            !! 'pt-sidebar-category-label'
        )
      );
    }

    .set-child($l);
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_FILL);
    .set-has-tooltip(True);

    .register-signal(
      self, 'show-tooltip', 'query-tooltip', :$category
    );
    .register-signal(
      self, 'select-category', 'clicked', :$category, :$category-container
    );
  }
  
  $cat-button
}

#-------------------------------------------------------------------------------
method sidebar-expander ( Str $category --> Gnome::Gtk4::Expander ) {
  with my Gnome::Gtk4::Expander $cat-expander .= new-expander(Str) {
    $!config.set-css( .get-style-context, :css-class<pt-sidebar-expander>);

    given my Gnome::Gtk4::Label $l .= new-label {
      .set-text($category);
      .set-hexpand(True);
      .set-halign(GTK_ALIGN_START);
      $!config.set-css(
        .get-style-context, :css-class('sidebar-expander-label')
      );
    }

    .set-label-widget($l);
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_FILL);
  }
  
  $cat-expander
}

#-------------------------------------------------------------------------------
method sidebar-status (
  Str $category,
  Gnome::Gtk4::Grid $grid, Int $row-count, Array $totals,
  Str :$category-container = ''
) {
  my Gnome::Gtk4::Label $l;

  my Array $cat-status =
     $!config.get-category-status( $category, :$category-container);

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
  Str :$category
  --> gboolean
) {
  my Str $puzzle-image-name = $!config.get-puzzle-image($category);
  if ?$puzzle-image-name {
    my Gnome::Gtk4::Picture $p .= new-picture;
    $p.set-filename($puzzle-image-name);
    $tooltip.set-custom($p);
  }

  True
}

#-------------------------------------------------------------------------------
# Method to handle a category selection
method select-category ( Str :$category, Str :$category-container = '' ) {
#  $!current-category = $category;
  $!main.application-window.set-title("Puzzle Table Display - $category")
    if ?$!main.application-window;

  # Clear the puzzle table before showing the puzzles of this category
  $!main.table.clear-table;

  # Get the puzzles and send them to the table
  $!config.select-category( $category, :$category-container);
  my Seq $puzzles = $!config.get-puzzles;

  # Fill the puzzle table with new puzzles
  $!main.table.add-puzzles-to-table($puzzles);
}

#-------------------------------------------------------------------------------
# Method to handle a category selection
method set-category ( Str $category ) {

  # Fill the sidebar in case there is a new entry
  self.fill-sidebar;
  self.select-category(:$category);
}

#-------------------------------------------------------------------------------
method fill-categories (
  Bool :$skip-default = False --> Gnome::Gtk4::DropDown
) {
  my Gnome::Gtk4::StringList $category-list .= new-stringlist([]);
  my Gnome::Gtk4::DropDown $dropdown .= new-dropdown($category-list);

  for $!config.get-categories -> $category {
    next if $skip-default and $category eq 'Default';

    if $category ~~ m/ '_EX_' $/ {
      for $!config.get-categories(:category-container($category)) -> $subcat {
        $category-list.append($subcat);
      }
    }

    else {
      $category-list.append($category);
    }
  }

  $dropdown
}

#-------------------------------------------------------------------------------
method fill-containers ( Bool :$no-enpty = False --> Gnome::Gtk4::DropDown ) {
  my Gnome::Gtk4::StringList $category-list .= new-stringlist([]);
  my Gnome::Gtk4::DropDown $dropdown .= new-dropdown($category-list);

  # Add an entry to be able to select a category at toplevel
  $category-list.append('--') unless $no-enpty;

  # Add the container strings
  for $!config.get-containers -> $container {
    $category-list.append($container);
  }

  $dropdown
}

#-------------------------------------------------------------------------------
method get-dropdown-text ( Gnome::Gtk4::DropDown $dropdown --> Str ) {
  my Gnome::Gtk4::StringList() $string-list = $dropdown.get-model;
  $string-list.get-string($dropdown.get-selected)
}
