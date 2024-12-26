use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::MenuBar;
use PuzzleTable::Gui::Sidebar;
use PuzzleTable::Gui::Table;
use PuzzleTable::Gui::Statusbar;
use PuzzleTable::Gui::Shortcut;

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

#  my PuzzleTable::Config $config .= instance;

  # Management and admin
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

  my Capture $o = get-options(| $PuzzleTable::Config::options);

  # This option can be used multiple times
  my Str $root-tables = PUZZLE_TABLE_DATA;
  if $o<root-tables>:exists {
    $root-tables = $o<root-tables>;
  }

  # Prepare initialization of the config module
  my PuzzleTable::Config $config;
  my Str $root-global = GLOBAL_CONFIG;
  if $o<root-global>:exists {
    $root-global = $o<root-global>;
  }

  $config .= instance( $root-global, $root-tables);

  # Handle the simple options here which do not require the primary instance
  if $o<version> {
    note "Version of puzzle table; $PuzzleTable::Type::version";
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

  my Int $exit-code = 0;
#  my Gnome::Gio::ApplicationCommandLine $command-line .= new(
#    :native-object($n-command-line)
#  );

  my Capture $o = get-options-from(
    $command-line.get-arguments(Pointer), | $PuzzleTable::Config::options
  );
  my @args = $o.list;

  my PuzzleTable::Config $config .= instance;

#`{{
  # This option can be used multiple times but only checked when called remotely
  # First time it is called in local-options() above.
  if $!table-is-displayed and $o<root-tables>:exists {
    $config.add-table-root($o<root-tables>);
  }
}}

#note "$?LINE $config.gist()";

  # We need the table and category management here already
  $!statusbar .= new-statusbar(:context<puzzle-table>) unless ?$!statusbar;
  $!table .= new-scrolledwindow(:main(self)) unless ?$!table;
  $!sidebar .= new-scrolledwindow(:main(self)) unless $!sidebar;

  my Bool $lockable = False;
  if $o<lock>:exists {
    $lockable = $o<lock>;
  }

  if $o<unlock>:exists {
    $config.unlock($o<unlock>);
  }

  # Process category option. It is set to 'Default' otherwise.
  my Str $opt-category = 'Default';
  my Str $opt-container = 'Default';

  if $o<container>:exists {
    $opt-container = $o<container>;
    $config.add-container($opt-container);
  }

  if $o<category>:exists {
    $opt-category = $o<category>;
    # Create category if does not exist. Keep lockable property of the category
    # True when it is set to True
    $config.add-category( $opt-category, $opt-container, :$lockable);
  }

  $config.select-category(
    $opt-category, $config.get-current-container,
    :root-dir($config.get-current-root)
  );
  $!sidebar.set-category(
    $opt-category, $opt-container, :root-dir($config.get-current-root)
  );

  if $o<puzzles>:exists {
    for @args[1..*-1] -> $puzzle-path {
      $puzzle-path ~~ s@^ '~/' @$*HOME/@;
      unless $puzzle-path ~~ m/ \. puzzle $/ and $puzzle-path.IO.r {
        note "Puzzle $puzzle-path not found or is not a puzzle file";
        next;
      }

      my Str $puzzle-id = $config.add-puzzle($puzzle-path);
      $!table.add-puzzle-to-table( $opt-category, $puzzle-id);
    }

    $!sidebar.fill-sidebar;
  }

  if $o<pala-collection>:exists {
    $!table.get-pala-puzzles( $opt-category, $o<pala-collection>);
  }

  if $o<restore>:exists {
    my Str $archive-dir = $o<restore>.IO.parent.Str ~ '/';
    my Str $archive-name = $o<restore>.IO.basename.Str;
    my Str $message = $config.restore-puzzles( $archive-dir, $archive-name);
    note "Error: $message" if ?$message;
  }

  # Activate unless table is already displayed
  $!application.activate unless $!table-is-displayed;
  $command-line.set-exit-status($exit-code);
  $command-line.done;
  $command-line.clear-object;

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
  my PuzzleTable::Config $config .= instance;
  $config.save-categories-config;
}

#-------------------------------------------------------------------------------
method puzzle-table-display ( ) {
#say 'puzzle start';

  my PuzzleTable::Config $config .= instance;
  $config.store-main-window(self);

  $!toolbar .= new-box( GTK_ORIENTATION_HORIZONTAL, 2);

  with $!top-grid .= new-grid {
    $config.set-css( .get-style-context, :css-class<main-view>);

    .set-margin-top(10);
    .set-margin-bottom(10);
    .set-margin-start(10);
    .set-margin-end(10);

    .attach( $!toolbar, 0, 0, 2, 1);
    .attach( $!sidebar, 0, 1, 1, 3);
    .attach( $!table, 1, 2, 1, 1);
    .attach( $!statusbar, 1, 3, 1, 1);
  }

  with $!application-window .= new-applicationwindow($!application) {
    my PuzzleTable::Gui::Shortcut $shortcut .= new(:main(self));
    $shortcut.set-shortcut-keys;

    my PuzzleTable::Gui::MenuBar $menu-bar .= new(:main(self));
    $!application.set-menubar($menu-bar.bar);
    $config.set-css( .get-style-context, :css-class<main-puzzle-table>);

    .register-signal( self, 'quit-application', 'destroy');
    .set-show-menubar(True);
    .set-title('Puzzle Table Display - Default');
    .set-size-request( 1700, 1000);
    .set-child($!top-grid);
    .set-visible(True);
  }

  $!sidebar.fill-sidebar;
  $!table-is-displayed = True;
#  Gnome::N::debug(:on);
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
  my PuzzleTable::Config $config .= instance;
  $config.save-categories-config;
  $!application.quit;
}

#-------------------------------------------------------------------------------
method usage ( ) {
  say qq:to/EOUSAGE/;

  Program to show a puzzle table.

  Usage:
    puzzle-table --version
    puzzle-table --help
    puzzle-table --puzzles [--container=<name>] [--category=<name>] [--lock] <puzzle-path> …
    puzzle-table --pala-collection=<collection-path>
    puzzle-table --restore=<archive>·

  Options:
    --container <name>
      By default `Default`. Select the container to work
      with. The container is created if not available.

    --category <name>
      By default `Default`. Select the category to work
      with. The category is created if not available. When 
      `--puzzle` is used, 

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
      arguments. The imported puzzles are placed in the selected category in
      the container.

    --restore <archive>
      Restore a previously archived set of puzzles in original category
      and container. When container and category are deleted, these will be
      created in this restore proces.

    --version
      Show current version of distribution.

  EOUSAGE
}