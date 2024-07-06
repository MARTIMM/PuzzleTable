use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::MenuBar;
use PuzzleTable::Gui::Sidebar;
use PuzzleTable::Gui::Table;
use PuzzleTable::Gui::Statusbar;

use Gnome::Gio::Application:api<2>;
use Gnome::Gio::T-ioenums:api<2>;
use Gnome::Gio::ApplicationCommandLine:api<2>;

use Gnome::Gtk4::Application:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::ApplicationWindow:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

use Gnome::Glib::N-Error;
use Gnome::Glib::T-error;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

use Getopt::Long;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::MainWindow:auth<github:MARTIMM>;

has Gnome::Gtk4::Application $.application;
has Gnome::Gtk4::ApplicationWindow $.application-window;
has Gnome::Gtk4::Grid $!top-grid;
has Gnome::Gtk4::Box $.toolbar;
has Bool $!table-is-displayed = False;

has PuzzleTable::Config $.config;
has PuzzleTable::Gui::Table $.table;
has PuzzleTable::Gui::Sidebar $.sidebar;
has PuzzleTable::Gui::Statusbar $.statusbar;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

  $!application .= new-application(
    APP_ID, G_APPLICATION_HANDLES_COMMAND_LINE
  );

  # Load the gtk resource file and register resource to make data global to app
#  my Gnome::Gio::Resource $r .= new(:load(%?RESOURCES<library.gresource>));
#  $r.register;

  # Startup signal fired after registration of app
  $!application.register-signal( self, 'app-startup', 'startup');

  # Fired after g_application_quit
  $!application.register-signal( self, 'app-shutdown', 'shutdown');

  # Fired to proces local options
  $!application.register-signal( self, 'local-options', 'handle-local-options');

  # Fired to proces remote options
  $!application.register-signal( self, 'remote-options', 'command-line');

  # Fired after g_application_run
  $!application.register-signal( self, 'puzzle-table-display', 'activate');

  # Now we can register the application.
  my $e = CArray[N-Error].new(N-Error);
  $!application.register( N-Object, $e);
  die $e[0].message if ?$e[0];
}

#-------------------------------------------------------------------------------
method app-startup ( ) {
#say 'startup';
}

#-------------------------------------------------------------------------------
method local-options ( N-Object $n-variant-dict --> Int ) {
#say 'local opts';

  # Management and admin
  $!config .= new;

  my Int $exit-code = -1;

  # All faulty and wrong arguments thrown by Getopt::Long are caught here.
  CATCH {
    default {
      .message.note;
      self.usage;

      $exit-code = 1;
      return $exit-code;
    }
  }

  my Capture $o = get-options(|$!config.options);

  # Handle the simple options here which do not require the primary instance
  if $o<version> {
    note "Version of puzzle table; $!config.version()";
    $exit-code = 0;
  }

  if $o<h> or $o<help> {
    self.usage;
    $exit-code = 0;
  }

  $exit-code
}

#-------------------------------------------------------------------------------
method remote-options (
  Gnome::Gio::ApplicationCommandLine() $command-line --> Int
) {
#say 'remote opts';

  # We need the table and category management here already
  $!statusbar .= new-statusbar(:context<puzzle-table>) unless ?$!statusbar;
  $!table .= new-scrolledwindow(:main(self)) unless ?$!table;
  $!sidebar .= new-scrolledwindow(:main(self)) unless $!sidebar;

  my Int $exit-code = 0;
#  my Gnome::Gio::ApplicationCommandLine $command-line .= new(
#    :native-object($n-command-line)
#  );

  my Capture $o = get-options-from(
    $command-line.get-arguments(Pointer), |$!config.options
  );
  my @args = $o.list;

  my Bool $lockable = False;
  if $o<lock>:exists {
    $lockable = $o<lock>;
  }

  # Process category option. It is set to 'Default' otherwise.
  my Str $opt-category = 'Default';

  if $o<category>:exists {
    $opt-category = $o<category>.tc;
    # Create category if does not exist. Keep lockable property of the category
    # True when it is set to True
    $!config.add-category( $opt-category, :$lockable);
  }

#TODO select category if registered
  $!sidebar.set-category($opt-category);
  my Str $category-container = $!config.find-container($opt-category);
  if ?$category-container {
    $!config.select-category( $opt-category, :$category-container);
  }

  else {
    $!config.select-category($opt-category);
  }

  if $o<puzzles>:exists {
    for @args[1..*-1] -> $puzzle-path {
      $puzzle-path ~~ s@^ '~/' @$*HOME/@;
      unless $puzzle-path ~~ m/ \. puzzle $/ and $puzzle-path.IO.r {
        note "Puzzle $puzzle-path not found or is not a puzzle file";
        next;
      }

      #my Str $puzzle-id = $!config.add-puzzle( $opt-category, $puzzle-path);
      my Str $puzzle-id = $!config.add-puzzle($puzzle-path);

      $!table.add-puzzle-to-table( $opt-category, $puzzle-id)
        if ?$puzzle-id and $!table-is-displayed;
    }
  }

  if $o<pala-collection>:exists {
    $!table.get-pala-puzzles( $opt-category, $o<pala-collection>);
  }

  if $o<restore>:exists {
    my Str $archive-dir = $o<restore>.IO.parent.Str ~ '/';
    my Str $archive-name = $o<restore>.IO.basename.Str;
    my Str $message = $!config.restore-puzzles( $archive-dir, $archive-name);
    note "Error: $message" if ?$message;
  }

  # Activate unless table is already displayed
  $!application.activate unless $!table-is-displayed;
  $command-line.set-exit-status($exit-code);
  $command-line.done;
  $command-line.clear-object;

  # Refill the sidebar unless there is no change
  #$!sidebar.fill-sidebar unless $!table-is-displayed;
#note "$?LINE exit with code $exit-code";
  $exit-code
}

#`{{
#-------------------------------------------------------------------------------
method app-open-file ( ) {
say 'open a file';
}
}}

#-------------------------------------------------------------------------------
method app-shutdown ( ) {
  $!config.save-categories-config;
}

#-------------------------------------------------------------------------------
method puzzle-table-display ( ) {

  $!toolbar .= new-box( GTK_ORIENTATION_HORIZONTAL, 2);

  with $!top-grid .= new-grid {
    $!config.set-css( .get-style-context, :css-class<main-view>);

    .set-margin-top(10);
    .set-margin-bottom(10);
    .set-margin-start(10);
    .set-margin-end(10);

    .attach( $!toolbar, 0, 0, 1, 1);
    .attach( $!sidebar, 0, 1, 1, 2);
    .attach( $!table, 1, 2, 1, 1);
    .attach( $!statusbar, 1, 3, 1, 1);
  }

  with $!application-window .= new-applicationwindow($!application) {
    my PuzzleTable::Gui::MenuBar $menu-bar .= new(:main(self));
    $!application.set-menubar($menu-bar.bar);
    $!config.set-css( .get-style-context, :css-class<main-puzzle-table>);

    .register-signal( self, 'quit-application', 'destroy');
    .set-show-menubar(True);
    .set-title('Puzzle Table Display - Default');
    .set-size-request( 1700, 1000);
    .set-child($!top-grid);
    .set-visible(True);
  }

  $!sidebar.fill-sidebar;
  $!table-is-displayed = True;
}

#-------------------------------------------------------------------------------
method go-ahead ( ) {
  my Int $argc = 1 + @*ARGS.elems;

  my $arg_arr = CArray[Str].new();
  $arg_arr[0] = $*PROGRAM.Str;
  my Int $arg-count = 1;
  for @*ARGS -> $arg {
    $arg_arr[$arg-count++] = $arg;
  }

  my $argv = CArray[Str].new($arg_arr);

  $!application.run( $argc, $argv);
}

#-------------------------------------------------------------------------------
method quit-application ( ) {
  $!config.save-categories-config;
  $!application.quit;
}

#-------------------------------------------------------------------------------
method usage ( ) {
  say qq:to/EOUSAGE/;

  Program to show a puzzle table.

  Usage:
    puzzle-table --version
    puzzle-table --help
    puzzle-table --puzzles [--category=<name>] [--lock] <puzzle-path> …
    puzzle-table --pala-collection=<collection-path>
    puzzle-table --restore=<archive>

  Options:
    --category <name>
      By default `Default`. Select the category to work
      with. The category is created if not available. When `--import` or
      `--puzzle` is used, the imported puzzles are placed in that category.

    -h --help
      Show this information. This is also shown, with an error, when there are
      faulty arguments or options.
    
    --lock
      Set the category lockable.

    --pala-collection <path to palapeli collection>
      Get puzzles from a Palapeli collection into a category. The puzzles in
      Palapeli collection are not removed because Palapelli has its own
      administration. To remove from Palapeli, one must use the delete option
      in that program.

    --puzzles.
      Import one or more puzzles. The paths to the puzzles are given as the
      arguments.
    
    --restore <archive>
      Restore a previously archived set of puzzles in original category
      and container. When container and category are deleted, these will be
      created in this restore proces.

    --version
      Show current version of distribution.

  EOUSAGE
}