
use v6.d;

use PuzzleTable::Config;
use PuzzleTable::Gui::Table;
use PuzzleTable::Gui::Statusbar;
use PuzzleTable::Gui::DialogLabel;
use PuzzleTable::Gui::Category;
use PuzzleTable::Gui::Dialog;

use Gnome::Gtk4::PasswordEntry:api<2>;
use Gnome::Gtk4::Box:api<2>;
#use Gnome::Gtk4::ComboBoxText:api<2>;
use Gnome::Gtk4::Dialog:api<2>;
use Gnome::Gtk4::T-Dialog:api<2>;
use Gnome::Gtk4::T-Enums:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Settings:auth<github:MARTIMM>;

has $!main is required;
has PuzzleTable::Config $!config;
has PuzzleTable::Gui::Table $!table;
has PuzzleTable::Gui::Statusbar $!statusbar;
has PuzzleTable::Gui::Category $!category;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!config = $!main.config;
  $!table = $!main.table;
  $!category = $!main.category;
}

#-------------------------------------------------------------------------------
method settings-set-password ( N-Object $parameter ) {
  say 'set password';
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
  say 'unlock';
  if $!config.is-locked {
    my Str $password = $!config.get-password;
    self.show-dialog-password() if ?$password;
  }
}

#-------------------------------------------------------------------------------
method settings-lock-categories ( N-Object $parameter ) {
  say 'lock';
  $!config.lock;
  $!category.fill-sidebar;
}

#`{{
#-------------------------------------------------------------------------------
method show-dialog-with-old-entry ( ) {

  my DialogLabel $label-oldpw .= new( 'Type old password', :$!config);
  my DialogLabel $label-newpw .= new( 'Type new password', :$!config);
  my DialogLabel $label-reppw .= new( 'Repeat new password', :$!config);

  my Gnome::Gtk4::PasswordEntry $entry-oldpw .= new-passwordentry;
  my Gnome::Gtk4::PasswordEntry $entry-newpw .= new-passwordentry;
  my Gnome::Gtk4::PasswordEntry $entry-reppw .= new-passwordentry;

  $!statusbar .= new-statusbar(:context<password>);

  my Gnome::Gtk4::Dialog $dialog .= new-with-buttons(
    'Password Change Dialog', $!main.application-window,
    GTK_DIALOG_MODAL +| GTK_DIALOG_DESTROY_WITH_PARENT,
         'Change', GEnum, GTK_RESPONSE_ACCEPT,
    Str, 'Cancel', GEnum, GTK_RESPONSE_CANCEL
  );

  with my Gnome::Gtk4::Box $box .= new(
    :native-object($dialog.get-content-area)
  ) {
    .set-orientation(GTK_ORIENTATION_VERTICAL);
    .set-margin-top(10);
    .set-margin-bottom(10);
    .set-margin-start(10);
    .set-margin-end(10);

    .append($label-oldpw);
    .append($entry-oldpw);
    .append($label-newpw);
    .append($entry-newpw);
    .append($label-reppw);
    .append($entry-reppw);
    .append($!statusbar);

    .set-name('password-dialog');
  }

  with $dialog {
    .set-size-request( 400, 100);
    .register-signal(
      self, 'do-password-check-with-old', 'response', :$entry-oldpw,
      :$entry-newpw, :$entry-reppw
    );

    .register-signal( self, 'destroy-dialog', 'destroy');
    $!config.set-css( .get-style-context, :css-class<dialog>);
    my $r = .show;
  }
}
}}
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
#Gnome::N::debug(:on);

  my Bool $sts-ok = False;
#  while !$sts-ok {
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
#  }

  $dialog.destroy-dialog if $sts-ok;
#Gnome::N::debug(:off);
}

#`{{
#-------------------------------------------------------------------------------
method do-password-check-with-old (
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::PasswordEntry :$entry-oldpw,
  Gnome::Gtk4::PasswordEntry :$entry-newpw,
  Gnome::Gtk4::PasswordEntry :$entry-reppw
) {
  my Bool $sts-ok = False;
  $!statusbar.remove-message;

  my GtkResponseType() $response-type = $response-id;  
  given $response-type {
    when GTK_RESPONSE_DELETE_EVENT {
      #ignore
      $sts-ok = True;
    }

    when GTK_RESPONSE_ACCEPT {
      my Str $opw = $entry-oldpw.get-text;
      my Str $npw = $entry-newpw.get-text;
      my Str $rpw = $entry-reppw.get-text;

      if $npw ne $rpw {
        $!statusbar.set-status('New password not equal to repeated one');
      }

      # If returned False, the password is not set
      elsif !$!config.set-password( $opw, $npw) {
        $!statusbar.set-status('Old password does not match');
      }

      else {
        $sts-ok = True;
      }
    }

    when GTK_RESPONSE_CANCEL {
      $sts-ok = True;
    }
  }

  $dialog.destroy if $sts-ok;
}
}}

#-------------------------------------------------------------------------------
method show-dialog-first-entry ( ) {

  my DialogLabel $label-newpw .= new( 'Type password', :$!config);
  my DialogLabel $label-reppw .= new( 'Repeat password', :$!config);

  my Gnome::Gtk4::PasswordEntry $entry-newpw .= new-passwordentry;
  my Gnome::Gtk4::PasswordEntry $entry-reppw .= new-passwordentry;

  $!statusbar .= new-statusbar(:context<password>);

  my Gnome::Gtk4::Dialog $dialog .= new-with-buttons(
    'Password Change Dialog', $!main.application-window,
    GTK_DIALOG_MODAL +| GTK_DIALOG_DESTROY_WITH_PARENT,
         'Change', GEnum, GTK_RESPONSE_ACCEPT,
    Str, 'Cancel', GEnum, GTK_RESPONSE_CANCEL
  );

  with my Gnome::Gtk4::Box $box .= new(
    :native-object($dialog.get-content-area)
  ) {
    .set-orientation(GTK_ORIENTATION_VERTICAL);
    .set-margin-top(10);
    .set-margin-bottom(10);
    .set-margin-start(10);
    .set-margin-end(10);

    .append($label-newpw);
    .append($entry-newpw);
    .append($label-reppw);
    .append($entry-reppw);
    .append($!statusbar);

    .set-name('password-dialog');
  }

  with $dialog {
    .set-size-request( 400, 100);
    .register-signal(
      self, 'do-password-check', 'response',
      :$entry-newpw, :$entry-reppw
    );

    .register-signal( self, 'destroy-dialog', 'destroy');
    $!config.set-css( .get-style-context, :css-class<dialog>);
    my $r = .show;
  }
}

#-------------------------------------------------------------------------------
method do-password-check (
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::PasswordEntry :$entry-newpw,
  Gnome::Gtk4::PasswordEntry :$entry-reppw
) {
  my Bool $sts-ok = False;
  $!statusbar.remove-message;

  my GtkResponseType() $response-type = $response-id;  
  given $response-type {
    when GTK_RESPONSE_DELETE_EVENT {
      #ignore
      $sts-ok = True;
    }

    when GTK_RESPONSE_ACCEPT {
      my Str $npw = $entry-newpw.get-text;
      my Str $rpw = $entry-reppw.get-text;

      if $npw ne $rpw {
        $!statusbar.set-status('Password not equal to repeated one');
      }

      # If returned False, the password is not set
      else {
        $!config.set-password( '', $npw);
        $sts-ok = True;
      }
    }

    when GTK_RESPONSE_CANCEL {
      $sts-ok = True;
    }
  }

  $dialog.destroy if $sts-ok;
}

#-------------------------------------------------------------------------------
method show-dialog-password ( ) {

  my DialogLabel $label-pw .= new( 'Type password', :$!config);
  my Gnome::Gtk4::PasswordEntry $entry-pw .= new-passwordentry;
  $!statusbar .= new-statusbar(:context<password>);

  my Gnome::Gtk4::Dialog $dialog .= new-with-buttons(
    'Password Change Dialog', $!main.application-window,
    GTK_DIALOG_MODAL +| GTK_DIALOG_DESTROY_WITH_PARENT,
         'Change', GEnum, GTK_RESPONSE_ACCEPT,
    Str, 'Cancel', GEnum, GTK_RESPONSE_CANCEL
  );

  with my Gnome::Gtk4::Box $box .= new(
    :native-object($dialog.get-content-area)
  ) {
    .set-orientation(GTK_ORIENTATION_VERTICAL);
    .set-margin-top(10);
    .set-margin-bottom(10);
    .set-margin-start(10);
    .set-margin-end(10);

    .append($label-pw);
    .append($entry-pw);
    .append($!statusbar);

    .set-name('password-dialog');
  }

  with $dialog {
    .set-size-request( 400, 100);
    .register-signal( self, 'do-password-unlock-check', 'response', :$entry-pw);
    .register-signal( self, 'destroy-dialog', 'destroy');
    $!config.set-css( .get-style-context, :css-class<dialog>);
    my $r = .show;
  }
}

#-------------------------------------------------------------------------------
method do-password-unlock-check (
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::PasswordEntry :$entry-pw,
) {
  my Bool $sts-ok = False;
  $!statusbar.remove-message;

  my GtkResponseType() $response-type = $response-id;  
  given $response-type {
    when GTK_RESPONSE_DELETE_EVENT {
      #ignore
      $sts-ok = True;
    }

    when GTK_RESPONSE_ACCEPT {
      my Str $pw = $entry-pw.get-text;
      if ! $!config.check-password($pw) {
        $!statusbar.set-status('Password not correct');
      }

      # If returned True, the password is accepted
      else {
        $sts-ok = True;
        $!config.unlock($pw);
        $!category.fill-sidebar;
      }
    }

    when GTK_RESPONSE_CANCEL {
      $sts-ok = True;
    }
  }

  $dialog.destroy if $sts-ok;
}

#-------------------------------------------------------------------------------
method destroy-dialog ( Gnome::Gtk4::Dialog :_widget($dialog) ) {
#  say 'destroy pw dialog';
  $dialog.destroy;
}
