use v6.d;
use NativeCall;

use PuzzleTable::Types;
use PuzzleTable::Gui::MenuBar;
use PuzzleTable::Init;

use Gnome::Gio::Application:api<2>;
use Gnome::Gio::T-Ioenums:api<2>;

use Gnome::Gtk4::Application:api<2>;
use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::ApplicationWindow:api<2>;
use Gnome::Gtk4::CssProvider:api<2>;
use Gnome::Gtk4::StyleContext:api<2>;
use Gnome::Gtk4::T-StyleProvider:api<2>;

#use Gnome::Glib::N-MainLoop:api<2>;
use Gnome::Glib::N-Error;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::MainWindow:auth<github:MARTIMM>;

has PuzzleTable::Init $!table-init;

has Gnome::Gtk4::Application $.application;
has Gnome::Gtk4::ApplicationWindow $!application-window;

has Gnome::Gtk4::CssProvider $!css-provider;
has Gnome::Gtk4::Grid ( $!top-grid, $!puzzle-grid );

#`{{
#-------------------------------------------------------------------------------
method new ( ) {
note self.^mro;
  self.new-application( $application-id, G_APPLICATION_DEFAULT_FLAGS);
}
}}

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

#-----------------------------------------------------------------------------
method app-startup ( ) {
say 'startup';

}

#-----------------------------------------------------------------------------
method local-options ( N-Object $n-variant-dict --> Int ) {
say 'local opts';

  # Might need this already when processing arguments
  $!table-init .= new;

  my Int $exit-code = -1;
  
  $exit-code
}

#-----------------------------------------------------------------------------
method remote-options ( N-Object $n-command-line --> Int ) {
say 'remote opts';

  my Int $exit-code = 0;
  
  $exit-code
}

#-----------------------------------------------------------------------------
method app-open-file ( ) {
say 'open a file';

}

#-----------------------------------------------------------------------------
method app-shutdown ( ) {
say 'shutdown';

}

#-----------------------------------------------------------------------------
method puzzle-table-display ( ) {
#  my Gnome::Glib::N-MainLoop $main-loop .= new-mainloop;
say 'display table';

  # Load the style sheet for the application
  $!css-provider .= new-cssprovider;
  $!css-provider.load-from-path(PUZZLE_CSS);

  #---------------------------------------------------------------------------
#  my PuzzleTable::Gui::Helpers $helpers .= new;

  $!top-grid .= new-grid;
  $!puzzle-grid .= new-grid;

  with my Gnome::Gtk4::Frame $frame .= new-frame('Current Puzzle Table') {
    self.set-css( .get-style-context, :css-class<puzzle-table-frame>);

    .set-label-align(0.03);
    .set-margin-top(10);
    .set-margin-bottom(10);
    .set-margin-start(10);
    .set-margin-end(10);
    .set-child($!puzzle-grid);
  }

  my PuzzleTable::Gui::MenuBar $menu-bar .= new(:main-window(self));
  $!application.set-menubar($menu-bar.bar);

  my Gnome::Gtk4::ApplicationWindow $window;
  with $window .= new-applicationwindow($!application) {
    self.set-css(.get-style-context);

    .set-show-menubar(True);
    .set-title('Puzzle Table Display');
    .set-size-request( 1000, 700);
    .set-child($frame);
    .show;
  }
}

#-----------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------
method set-css ( N-Object $context, Str :$css-class = '' ) {

  my Gnome::Gtk4::StyleContext $style-context .= new(:native-object($context));
  $style-context.add-provider(
    $!css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
  );
  $style-context.add-class($css-class) if ?$css-class;
}