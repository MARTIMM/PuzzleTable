use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Init;
use PuzzleTable::Gui::MenuBar;
use PuzzleTable::Gui::Category;

use Gnome::Gio::Application:api<2>;
use Gnome::Gio::T-Ioenums:api<2>;

use Gnome::Gtk4::Application:api<2>;
use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::ApplicationWindow:api<2>;
use Gnome::Gtk4::CssProvider:api<2>;
use Gnome::Gtk4::StyleContext:api<2>;
use Gnome::Gtk4::T-StyleProvider:api<2>;

use Gnome::Glib::N-Error;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

use YAMLish;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::MainWindow:auth<github:MARTIMM>;

has PuzzleTable::Init $!table-init;

has Gnome::Gtk4::Application $.application;
has Gnome::Gtk4::ApplicationWindow $.application-window;

has Gnome::Gtk4::CssProvider $!css-provider;
has Gnome::Gtk4::Grid ( $!top-grid, $!puzzle-grid );

has PuzzleTable::Gui::Category $.combobox;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

  $!application .= new-application( APP_ID, G_APPLICATION_DEFAULT_FLAGS);

  # Load the gtk resource file and register resource to make data global to app
#  my Gnome::Gio::Resource $r .= new(:load(%?RESOURCES<library.gresource>.Str));
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

  # Fired after detecting a file on commandline
  $!application.register-signal( self, 'app-open-file', 'open');

  # Now we can register the application.
  my $e = CArray[N-Error].new(N-Error);
  note 'register: ', $!application.register( N-Object, $e);
  die $e[0].message if ?$e[0];
}

#-------------------------------------------------------------------------------
method app-startup ( ) {
say 'startup';

}

#-------------------------------------------------------------------------------
method local-options ( N-Object $n-variant-dict --> Int ) {
say 'local opts';

  # Might need this already when processing arguments
  $!table-init .= new;

  my Int $exit-code = -1;
  
  $exit-code
}

#-------------------------------------------------------------------------------
method remote-options ( N-Object $n-command-line --> Int ) {
say 'remote opts';

  my Int $exit-code = 0;
  
  $exit-code
}

#-------------------------------------------------------------------------------
method app-open-file ( ) {
say 'open a file';

}

#-------------------------------------------------------------------------------
method app-shutdown ( ) {
say 'shutdown';
  PUZZLE_DATA.IO.spurt(save-yaml($*puzzle-data));
}

#-------------------------------------------------------------------------------
method puzzle-table-display ( ) {
say 'display table';

  # Load the style sheet for the application
  $!css-provider .= new-cssprovider;
  $!css-provider.load-from-path(PUZZLE_CSS);

  #-----------------------------------------------------------------------------
  $!puzzle-grid .= new-grid;

  with my Gnome::Gtk4::Frame $frame .= new-frame('Current Puzzle Table') {
    self.set-css( .get-style-context, :css-class<puzzle-table-frame>);
    .set-label-align(0.03);
    .set-child($!puzzle-grid);
    .set-hexpand(True);
    .set-vexpand(True);
  }

  with $!combobox.= new-comboboxtext(:main(self)) {
    for $*puzzle-data<category>.keys.sort -> $key {
      .append-text($key);
    }
    .set-active(0);
  }

  with $!top-grid .= new-grid {
    self.set-css( .get-style-context, :css-class<main-view>);
    .set-margin-top(10);
    .set-margin-bottom(10);
    .set-margin-start(10);
    .set-margin-end(10);
    .attach( $!combobox, 0, 0, 1, 1);
    .attach( $frame, 0, 1, 1, 1);
  }

  with $!application-window .= new-applicationwindow($!application) {
    my PuzzleTable::Gui::MenuBar $menu-bar .= new(:main(self));
    $!application.set-menubar($menu-bar.bar);

    self.set-css(.get-style-context);

    .set-show-menubar(True);
    .set-title('Puzzle Table Display');
    .set-size-request( 1000, 700);
    .set-child($!top-grid);
    .show;
  }
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
method set-css ( N-Object $context, Str :$css-class = '' ) {

  my Gnome::Gtk4::StyleContext $style-context .= new(:native-object($context));
  $style-context.add-provider(
    $!css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
  );
  $style-context.add-class($css-class) if ?$css-class;
}