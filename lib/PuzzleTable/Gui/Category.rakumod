use v6.d;

use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::ComboBoxText:api<2>;
use Gnome::Gtk4::Dialog:api<2>;
use Gnome::Gtk4::T-Dialog:api<2>;
#use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::T-Enums:api<2>;
use Gnome::Gtk4::Statusbar:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Category:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
has $!application is required;
has $!main is required;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!application = $!main.application;
}

#-------------------------------------------------------------------------------
method category-add ( N-Object $parameter ) {
  say 'category add';

  my Gnome::Gtk4::Label $label .= new-label('Specify a new category');
  my Gnome::Gtk4::Entry $entry .= new-entry;
  my Gnome::Gtk4::Statusbar $statusbar .= new-statusbar;

  my Gnome::Gtk4::Dialog $dialog .= new-with-buttons(
    'Add Category dialog', $!main.application-window,
    GTK_DIALOG_MODAL,
    'Add', GEnum, GTK_RESPONSE_ACCEPT, Str, 'Cancel', GEnum, GTK_RESPONSE_CANCEL
  );

  with my Gnome::Gtk4::Box $box .= new(
    :native-object($dialog.get-content-area)
  ) {
    .set-orientation(GTK_ORIENTATION_VERTICAL);
    .set-margin-top(10);
    .set-margin-bottom(10);
    .set-margin-start(10);
    .set-margin-end(10);
    .append($label);
    .append($entry);
    .append($statusbar);
  }

  with $dialog {
    .set-size-request( 400, 200);
    .register-signal( self, 'do-category-add', 'response', :$entry, :$statusbar);
    my $r = .show;
  }
}

#-------------------------------------------------------------------------------
method do-category-add (
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::Entry :$entry, Gnome::Gtk4::Statusbar :$statusbar
) {
  my Bool $sts-ok = False;
  $statusbar.remove-all;

  my GtkResponseType() $response-type = $response-id;
  note 'return code: ', $response-id, ', ', $response-type;
  given $response-type {
    when GTK_RESPONSE_DELETE_EVENT {
      #ignore
      $sts-ok = True;
    }

    when GTK_RESPONSE_ACCEPT {
      my Str $cat-text = $entry.get-text;
note "New cat: $cat-text";

      if !$cat-text {
        self.set-status('No category name specified');
      }

      elsif $cat-text.lc eq 'default' {
        self.set-status(
          'Category \'default\' is fixed in any form of text-case'
        );
      }

      elsif $*puzzle-data<category>{$cat-text}:exists {
        self.set-status('Category already defined');
      }

      else {
        $*puzzle-data<category>{$cat-text} = %();
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
method category-rename ( N-Object $parameter ) {
  say 'category rename';

  my Gnome::Gtk4::Label $label1 .= new-label('Select category from list');
  my Gnome::Gtk4::Label $label2 .= new-label('Text to rename category');
  my Gnome::Gtk4::Entry $entry .= new-entry;
  my Gnome::Gtk4::Statusbar $statusbar .= new-statusbar;
  my Gnome::Gtk4::ComboBoxText $combobox.= new-comboboxtext;

  for $*puzzle-data<category>.keys -> $key {
    $combobox.append-text($key);
  }
  $combobox.set-active(0);

  my Gnome::Gtk4::Dialog $dialog .= new-with-buttons(
    'Add Category dialog', $!main.application-window,
    GTK_DIALOG_MODAL,
         'Rename', GEnum, GTK_RESPONSE_ACCEPT,
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
    .append($label1);
    .append($combobox);
    .append($label2);
    .append($entry);
    .append($statusbar);
  }

  with $dialog {
    .set-size-request( 400, 200);
    .register-signal(
      self, 'do-category-rename', 'response', :$entry, :$combobox, :$statusbar
    );
    .show;
  }
}

#-------------------------------------------------------------------------------
method do-category-rename (
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::Entry :$entry, Gnome::Gtk4::ComboBoxText :$combobox,
  Gnome::Gtk4::Statusbar :$statusbar
) {
  my Bool $sts-ok = False;
  $statusbar.remove-all;


  my GtkResponseType() $response-type = $response-id;
  note 'return code: ', $response-id, ', ', $response-type;
  given $response-type {
    when GTK_RESPONSE_DELETE_EVENT {
      #ignore
      $sts-ok = True;
    }

    when GTK_RESPONSE_ACCEPT {
      my Str $cat-text = $entry.get-text;
note "New cat: $cat-text";

      if !$cat-text {
        self.set-status( $statusbar, 'No category name specified');
      }

      elsif $cat-text.lc eq 'default' {
        self.set-status(
           $statusbar, 'Category \'default\' is fixed in any form of text-case'
        );
      }

      elsif $*puzzle-data<category>{$cat-text}:exists {
        self.set-status( $statusbar, 'Category already defined');
      }

      elsif $cat-text eq $combobox.get-active-text {
        self.set-status( $statusbar, 'Category text same as selected');
      }

      else {
        $*puzzle-data<category>{$cat-text} =
          $*puzzle-data<category>{$combobox.get-active-text}:delete;
        
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
method category-remove ( N-Object $parameter ) {
  say 'category remove';
}

#-------------------------------------------------------------------------------
method set-status ( Gnome::Gtk4::Statusbar $statusbar, Str $text ) {
  $statusbar.push( $statusbar.get-context-id('category'), $text);
}