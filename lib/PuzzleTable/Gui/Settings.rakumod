
use v6.d;

use PuzzleTable::Config;
use PuzzleTable::Gui::Table;
use PuzzleTable::Gui::Sidebar;
use PuzzleTable::Gui::Dialog;

use Gnome::Gtk4::PasswordEntry:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::ShortcutController:api<2>;
use Gnome::Gtk4::Shortcut:api<2>;
use Gnome::Gtk4::KeyvalTrigger:api<2>;
use Gnome::Gtk4::CallbackAction:api<2>;

use Gnome::Gdk4::T-enums:api<2>;
use Gnome::Gdk4::T-keysyms:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;

#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Settings:auth<github:MARTIMM>;

has $!main is required;
has PuzzleTable::Config $!config;
has PuzzleTable::Gui::Table $!table;
#has PuzzleTable::Gui::Statusbar $!statusbar;
has PuzzleTable::Gui::Sidebar $!sidebar;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!config = $!main.config;
  $!table = $!main.table;
  $!sidebar = $!main.sidebar;

  self.set-shortcut-keys;
}

#-------------------------------------------------------------------------------
method set-shortcut-keys ( ) {
  my Gnome::Gtk4::ShortcutController $controller .= new-shortcutcontroller;
  $controller.set-scope(GTK_SHORTCUT_SCOPE_GLOBAL);
  $!main.application-window.add-controller($controller);

  # Create 
  my Gnome::Gtk4::KeyvalTrigger $trigger .=
    new-keyvaltrigger( GDK_KEY_Q, GDK_CONTROL_MASK);
  my Gnome::Gtk4::CallbackAction $action .= new-callbackaction(
    sub ( N-Object $no-widget, N-Object $, gpointer $ ) {
      $!main.quit-application;
    }
  );

  my Gnome::Gtk4::Shortcut $shortcut .= new-shortcut( $trigger, $action);

  $controller.add-shortcut($shortcut);
}

#-------------------------------------------------------------------------------
method settings-set-password ( N-Object $parameter ) {
#  say 'set password';
  my Str $password = $!config.get-password;
  if ?$password {
    self.show-dialog-with-old-entry();
  }

  else {
    self.show-dialog-first-entry();
  }
}

#-------------------------------------------------------------------------------
method settings-unlock-categories ( N-Object $parameter ) {
#  say 'unlock';
  if $!config.is-locked {
    my Str $password = $!config.get-password;
    if ?$password {
      self.show-dialog-password();
    }

    else {
      $!config.unlock(Str);
      $!sidebar.fill-sidebar;
    }
  }
}

#-------------------------------------------------------------------------------
method settings-lock-categories ( N-Object $parameter ) {
#  say 'lock';
  $!config.lock;
  $!sidebar.fill-sidebar;
}

#-------------------------------------------------------------------------------
method show-dialog-with-old-entry ( ) {
  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Password Change Dialog')
  ) {
    .add-content(
      'Type old password',
      my Gnome::Gtk4::PasswordEntry $entry-oldpw .= new-passwordentry
    );

    .add-content(
      'Type new password',
      my Gnome::Gtk4::PasswordEntry $entry-newpw .= new-passwordentry
    );

    .add-content(
      'Repeat new password',
      my Gnome::Gtk4::PasswordEntry $entry-reppw .= new-passwordentry
    );

    .add-button(
      self, 'do-password-check-with-old', 'Change',
      :$entry-oldpw, :$entry-newpw, :$entry-reppw, :$dialog
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-password-check-with-old (
  PuzzleTable::Gui::Dialog :$dialog,
  Gnome::Gtk4::PasswordEntry :$entry-oldpw,
  Gnome::Gtk4::PasswordEntry :$entry-newpw,
  Gnome::Gtk4::PasswordEntry :$entry-reppw
) {

  my Bool $sts-ok = False;
  my Str $opw = $entry-oldpw.get-text;
  my Str $npw = $entry-newpw.get-text;
  my Str $rpw = $entry-reppw.get-text;

  if $npw ne $rpw {
    $dialog.set-status('New password not equal to repeated one');
  }

  # If returned False, the password is not set
  elsif !$!config.set-password( $opw, $npw) {
    $dialog.set-status('Old password does not match');
  }

  else {
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method show-dialog-first-entry ( ) {

  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Password Change Dialog')
  ) {
    .add-content(
      'Type password',
      my Gnome::Gtk4::PasswordEntry $entry-newpw .= new-passwordentry
    );

    .add-content(
      'Repeat password',
      my Gnome::Gtk4::PasswordEntry $entry-reppw .= new-passwordentry
    );

    .add-button(
      self, 'do-password-check', 'Set Password',
      :$entry-newpw, :$entry-reppw, :$dialog
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-password-check (
  PuzzleTable::Gui::Dialog :$dialog,
  Gnome::Gtk4::PasswordEntry :$entry-newpw,
  Gnome::Gtk4::PasswordEntry :$entry-reppw
) {
  my Bool $sts-ok = False;

  my Str $npw = $entry-newpw.get-text;
  my Str $rpw = $entry-reppw.get-text;

  if $npw ne $rpw {
    $dialog.set-status('Password not equal to repeated one');
  }

  # If returned False, the password is not set
  else {
    $!config.set-password( '', $npw);
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method show-dialog-password ( ) {
  with my PuzzleTable::Gui::Dialog $dialog .= new(
    :$!main, :dialog-header('Password Change Dialog')
  ) {
    my Gnome::Gtk4::PasswordEntry $entry-pw .= new-passwordentry;
    $entry-pw.register-signal(
      self, 'do-password-unlock-check-button', 'activate', :$entry-pw, :$dialog
    );

    .add-content( 'Type password', $entry-pw);

    .add-button(
      self, 'do-password-unlock-check-button', 'Unlock', :$entry-pw, :$dialog
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-password-unlock-check-button (
  PuzzleTable::Gui::Dialog :$dialog,
  Gnome::Gtk4::PasswordEntry :$entry-pw,
) {
  my Bool $sts-ok = False;

  my Str $pw = $entry-pw.get-text;
  if ! $!config.check-password($pw) {
    $dialog.set-status('Password not correct');
  }

  # If returned True, the password is accepted
  else {
    $sts-ok = True;
    $!config.unlock($pw);
    $!sidebar.fill-sidebar;
  }

  $dialog.destroy-dialog if $sts-ok;
}
