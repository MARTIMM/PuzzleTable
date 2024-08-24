

use v6.d;

use PuzzleTable::Gui::MessageDialog;
use PuzzleTable::Gui::Category;

use Gnome::Gtk4::ShortcutController:api<2>;
use Gnome::Gtk4::Shortcut:api<2>;
#use Gnome::Gtk4::ShortcutTrigger:api<2>;
use Gnome::Gtk4::KeyvalTrigger:api<2>;
use Gnome::Gtk4::CallbackAction:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

use Gnome::Gio::SimpleAction:api<2>;

#use Gnome::Gdk4::T-enums:api<2>;
#use Gnome::Gdk4::T-keysyms:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Shortcut:auth<github:MARTIMM>;

has $!main is required;
has PuzzleTable::Gui::Category $!cat;
has Gnome::Gtk4::ShortcutController $!controller;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!cat .= new(:$!main);

  $!controller .= new-shortcutcontroller;
  $!controller.set-scope(GTK_SHORTCUT_SCOPE_GLOBAL);
  $!main.application-window.add-controller($!controller);
}

#-------------------------------------------------------------------------------
method set-shortcut-keys ( ) {

  # Create a trigger
  my Str $shortcut-string = '<Ctrl>q';
  my Gnome::Gtk4::KeyvalTrigger $trigger .= parse-string($shortcut-string);
  unless $trigger.is-valid {
    my PuzzleTable::Gui::MessageDialog $message .= new(
      :$!main, :message("Invalid shortcut string: $shortcut-string"), :no-statusbar
    );

    $message.show;

    return
  }

 #   new-keyvaltrigger( GDK_KEY_Q, GDK_CONTROL_MASK);

  # And an action which will stop the application
  my Gnome::Gtk4::CallbackAction $action .= new-callbackaction(
    sub ( N-Object $no-widget, N-Object $, gpointer $ ) {
      $!main.quit-application;
    },
    gpointer,
    N-Object
  );

  # Bind the trigger to the action
  my Gnome::Gtk4::Shortcut $shortcut .= new-shortcut( $trigger, $action);

  $!controller.add-shortcut($shortcut);
}

#-------------------------------------------------------------------------------
method set-shortcut-key ( Str $shortcut-string, $object, $method --> Bool ) {
  my PuzzleTable::Gui::MessageDialog $message;
  my Bool $set-key = False;

  if ! $object.^can($method) {
    $message .= new(
      :$!main, :no-statusbar,
      :message("Invalid shortcut string: $shortcut-string"),
    );

    $message.show;
  }

  # Create a trigger
  my Gnome::Gtk4::KeyvalTrigger $trigger .= parse-string($shortcut-string);
  unless $trigger.is-valid {
    $message .= new(
      :$!main, :no-statusbar,
      :message("Invalid shortcut string: $shortcut-string"),
    );

    $message.show;
  }

  # And an action which will stop the application
  my Gnome::Gtk4::CallbackAction $action .= new-callbackaction(
    sub ( N-Object $no-widget, N-Object $, gpointer $ ) {
      $!main.quit-application;
    },
    gpointer,
    N-Object
  );

  # Bind the trigger to the action
  my Gnome::Gtk4::Shortcut $shortcut .= new-shortcut( $trigger, $action);

  $!controller.add-shortcut($shortcut);
  
  $set-key
}

=finish
#-------------------------------------------------------------------------------
method bind-action (
  Str $shortcut-string, Mu $object, Str $entry-name,
  Str :$icon, Str :$path, Str :$tooltip, Bool :$shortcut = False
) {
  my PuzzleTable::Config $config .= instance;

  my Gnome::Gtk4::KeyvalTrigger $trigger .= parse-string($shortcut-string);
  unless $trigger.is-valid {
    my PuzzleTable::Gui::MessageDialog $message .= new(
      :$!main, :message("There are no puzzles selected"), :no-statusbar
    );

    $message.show;

    return
  }


  # Make a method and action name
  my Str $method = [~] $menu-name, ' ', $entry-name;
  $method .= lc;
  $method ~~ s:g/ \s+ /-/;

  my Str $action-name = 'app.' ~ $method;
#note "$?LINE $menu-name, '$entry-name', $method, $action-name";

  # Use the method name
  my Gnome::Gio::SimpleAction $action .= new-simpleaction( $method, Pointer);
  $!application.add-action($action);
  $action.register-signal( $object, $method, 'activate');
  my Gnome::Gtk4::Shortcut $shortcut .= new-shortcut( $trigger, $action);
}
