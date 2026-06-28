use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::MenuBar;
use PuzzleTable::Gui::Sidebar;
use PuzzleTable::Gui::Table;
use PuzzleTable::Gui::Statusbar;
use PuzzleTable::Gui::Shortcut;

use GnomeTools::Gtk::Application;
#use Gnome::Gtk::Application;
use Gnome::Gio::Menu;

use Gnome::Gio::Application:api<2>;
use Gnome::Gio::T-ioenums:api<2>;
use Gnome::Gio::ApplicationCommandLine:api<2>;

use Gnome::Gtk4::Application:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::ApplicationWindow:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Widget:api<2>;

use Gnome::Glib::N-Error;
use Gnome::Glib::T-error;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

use Getopt::Long;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::MainWindow:auth<github:MARTIMM>;

#constant LocalOptions = [<version help|h>];
#constant RemoteOptions = [ |<verbose|v> ];

has GnomeTools::Gtk::Application $.application handles <add-action>;
has Int $.exit-code = 0;



#has Gnome::Gtk4::Application $.application;
#has Gnome::Gtk4::ApplicationWindow $.application-window;
has Gnome::Gtk4::Grid $!top-grid;
has Gnome::Gtk4::Box $.toolbar;
has Bool $!table-is-displayed = False;

has PuzzleTable::Gui::Table $.table;
has PuzzleTable::Gui::Sidebar $.sidebar;
has PuzzleTable::Gui::Statusbar $.statusbar;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $*main-window = self;

  with $!application .= new(
    :app-id(APP_ID), :app-flags(G_APPLICATION_HANDLES_COMMAND_LINE)
  ) {
    .set-activate( self, 'puzzle-table-display');
#    .set-startup( self, 'app-startup');
    .set-shutdown( self, 'app-shutdown');
    .process-local-options( self, 'local-options');
    .process-remote-options( self, 'remote-options');

    $!exit-code = .run;
  }

#`{{
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
}}
}

#-------------------------------------------------------------------------------
#method app-startup ( ) {
#say 'startup';
#}

#-------------------------------------------------------------------------------
method local-options ( --> Int ) {
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

  # Test verbosity option
  $*verbose-output = ?$o<v>;

  # Clear logfile if verbose is True
  $*log-file.spurt('');

  # This option is a comma separated list of paths
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
    note "Version of puzzle table; $PuzzleTable::Types::version";
    $exit-code = 0;
  }

  if $o<h> or $o<help> {
    self.usage;
    $exit-code = 0;
  }

  $exit-code
}

#-------------------------------------------------------------------------------
method remote-options ( Array $args, Bool :$is-remote --> Int ) {
  my Int $exit-code = 0;
#  my Gnome::Gio::ApplicationCommandLine $command-line .= new(
#    :native-object($n-command-line)
#  );

  my Capture $o = get-options-from( $args, | $PuzzleTable::Config::options);
  my @args = $o.list;

  my PuzzleTable::Config $config .= instance;

#`{{
  # This option can be used multiple times but only checked when called remotely
  # First time it is called in local-options() above.
  if $!table-is-displayed and $o<root-tables>:exists {
    $config.add-table-root($o<root-tables>);
  }
}}


  # We need the table and category management here already
  $!statusbar .= new-statusbar(:context<puzzle-table>) unless ?$!statusbar;
  $!table .= new-scrolledwindow unless ?$!table;
  $!sidebar .= new-scrolledwindow unless $!sidebar;

  my Bool $lockable = False;
  if $o<lock>:exists {
    $lockable = $o<lock>;
  }

  if $o<unlock>:exists {
    $config.unlock($o<unlock>);
  }

  # Process container option. It is set to 'Default' otherwise.
  my Str $opt-container = 'Default';
  if $o<container>:exists {
    $opt-container = $o<container>;
    $config.add-container($opt-container);
  }

  # Process category option. It is also set to 'Default' otherwise.
  my Str $opt-category = 'Default';
  if $o<category>:exists {
    $opt-category = $o<category>;
    # Create category if does not exist. Keep lockable property of the category
    # True when it is set to True
    $config.add-category( $opt-category, $opt-container, :$lockable);
  }

  $config.select-category(
    $opt-category, $config.get-current-container, $config.get-current-root
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

    $!sidebar.set-category(
      $opt-category, $opt-container, :root-dir($config.get-current-root)
    );
  }

  if $o<pala-collection>:exists {
    $!table.get-pala-puzzles( $opt-category, $o<pala-collection>);
  }

  if $o<restore>:exists {
#    my Str $archive-name = $o<restore>.IO.basename.Str;
    my Str ( $message, $container, $category ) =
      $config.restore-puzzles($o<restore>);

    if ?$message {
      note "Error: $message";
    }

    else {
      $!sidebar.set-category(
        $category, $container, :root-dir($config.get-current-root)
      );
    }
  }

#`{{
  # Activate unless table is already displayed
  $!application.activate unless $!table-is-displayed;
  $command-line.set-exit-status($exit-code);
  $command-line.done;
  $command-line.clear-object;
}}
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
say 'puzzle start';

  $!application.set-window-content(
    self, 'window-content',
    self, 'menu',
  )
}

#-------------------------------------------------------------------------------
method window-content ( --> Gnome::Gtk4::Widget ) {
  my PuzzleTable::Config $config .= instance;

  $!toolbar .= new-box( GTK_ORIENTATION_HORIZONTAL, 2);

  with $!top-grid .= new-grid {
    $config.set-css( .get-style-context, :css-class<main-view>);

    .set-hexpand(False);

    .set-margin-top(10);
    .set-margin-bottom(10);
    .set-margin-start(10);
    .set-margin-end(10);

    .attach( $!toolbar, 0, 0, 2, 1);
    .attach( $!sidebar, 0, 1, 1, 3);
    .attach( $!table, 1, 2, 1, 1);
    .attach( $!statusbar, 1, 3, 1, 1);

    .set-size-request( 1000, 1000);
  }

  $!sidebar.fill-sidebar;
  $!table-is-displayed = True;

  my PuzzleTable::Gui::Shortcut $shortcut .= new;
  $shortcut.set-shortcut-keys;

  $!top-grid;

#`{{
  with $!application-window .= new-applicationwindow($!application) {

    my PuzzleTable::Gui::MenuBar $menu-bar .= new(:main(self));
    $!application.set-menubar($menu-bar.bar);
    .set-show-menubar(True);

    $config.set-css( .get-style-context, :css-class<main-puzzle-table>);

    .register-signal( self, 'quit-application', 'destroy');
    .set-title('Puzzle Table Display - Default');
    .set-size-request( 1700, 1000);
    .set-child($!top-grid);
    .set-visible(True);

    .present;
  }

  $!sidebar.fill-sidebar;
  $!table-is-displayed = True;
#  Gnome::N::debug(:on);
}}
}

#-------------------------------------------------------------------------------
method menu ( --> GnomeTools::Gio::Menu ) {
  my PuzzleTable::Gui::MenuBar $menu-bar .= new;

  $menu-bar.make-menu
}

#`{{
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
}}

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