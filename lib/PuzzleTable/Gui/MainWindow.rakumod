use v6.d;
use NativeCall;

use PuzzleTable::Types;
#use PuzzleTable::Gui::Helpers;

use Gnome::Gio::Application:api<2>;
use Gnome::Gio::T-Ioenums:api<2>;

use Gnome::Gtk4::Application:api<2>;
use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::ApplicationWindow:api<2>;

#use Gnome::Glib::N-MainLoop:api<2>;
use Gnome::Glib::N-Error;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::MainWindow:auth<github:MARTIMM>;
#also is Gnome::Gtk4::Application;

has Gnome::Gtk4::Application $!application;
has Gnome::Gtk4::ApplicationWindow $!application-window;

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
  #$!application.register-signal( self, 'app-shutdown', 'shutdown');

  # Fired to proces local options
  $!application.register-signal( self, 'local-options', 'handle-local-options');

  # Fired to proces remote options
  $!application.register-signal( self, 'remote-options', 'command-line');

  # Fired after g_application_run
  $!application.register-signal( self, 'puzzle-table-display', 'activate');

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
method app-shutdown ( ) {
say 'shutdown';

}

#-----------------------------------------------------------------------------
method local-options ( N-Object $n-variant-dict --> Int ) {
say 'local opts';

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
method puzzle-table-display ( ) {
#  my Gnome::Glib::N-MainLoop $main-loop .= new-mainloop;
say 'display table';


  #---------------------------------------------------------------------------
#  my PuzzleTable::Gui::Helpers $helpers .= new;

  my Gnome::Gtk4::Grid $grid .= new-grid;

  with my Gnome::Gtk4::Frame $frame .= new-frame('Current Puzzle Table') {
    .set-label-align(0.03);
    .set-margin-top(10);
    .set-margin-bottom(10);
    .set-margin-start(10);
    .set-margin-end(10);
    .set-child($grid);
  }

  with my Gnome::Gtk4::ApplicationWindow $window .=
       new-applicationwindow($!application) {

#    .register-signal( $helpers, 'stopit', 'close-request', :$main-loop);
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
