use v6.d;

use PuzzleTable::Gui::Statusbar;

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
has PuzzleTable::Gui::Statusbar $!statusbar;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!application = $!main.application;

  # Must be done later when dialog is created. It gets invalidated when
  # dialog is destroyed.
  #$!statusbar .= new-statusbar(:context<category>);
}

#-------------------------------------------------------------------------------
method category-add ( N-Object $parameter ) {
  say 'category add';

  my Gnome::Gtk4::Label $label .= new-label('Specify a new category');
  my Gnome::Gtk4::Entry $entry .= new-entry;
  $!statusbar .= new-statusbar(:context<category>);

  my Gnome::Gtk4::Dialog $dialog .= new-with-buttons(
    'Add Category dialog', $!main.application-window,
    GTK_DIALOG_MODAL +| GTK_DIALOG_DESTROY_WITH_PARENT,
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
    .append($!statusbar.get-native-object);
  }

  with $dialog {
    .set-size-request( 400, 200);
    .register-signal( self, 'do-category-add', 'response', :$entry);
    my $r = .show;
  }
}

#-------------------------------------------------------------------------------
method do-category-add (
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::Entry :$entry
) {
  my Bool $sts-ok = False;
  $!statusbar.remove-message;

  my GtkResponseType() $response-type = $response-id;  

note 'return code: ', $response-id, ', ', $response-type;
  given $response-type {
    when GTK_RESPONSE_DELETE_EVENT {
      #ignore
      $sts-ok = True;
    }

    when GTK_RESPONSE_ACCEPT {
      my Str $cat-text = $entry.get-text;

      if !$cat-text {
        $!statusbar.set-status('No category name specified');
      }

      elsif $cat-text.lc eq 'default' {
        $!statusbar.set-status(
          'Category \'default\' is fixed in any form of text-case'
        );
      }

      elsif $*puzzle-data<category>{$cat-text}:exists {
        $!statusbar.set-status('Category already defined');
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
  my Gnome::Gtk4::ComboBoxText $combobox.= new-comboboxtext;
  $!statusbar .= new-statusbar(:context<category>);

  for $*puzzle-data<category>.keys -> $key {
    $combobox.append-text($key);
  }
  $combobox.set-active(0);

  my Gnome::Gtk4::Dialog $dialog .= new-with-buttons(
    'Add Category dialog', $!main.application-window,
    GTK_DIALOG_MODAL +| GTK_DIALOG_DESTROY_WITH_PARENT,
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
    .append($!statusbar);
  }

  with $dialog {
    .set-size-request( 400, 200);
    .register-signal(
      self, 'do-category-rename', 'response', :$entry, :$combobox
    );
    .show;
  }
}

#-------------------------------------------------------------------------------
method do-category-rename (
  Int $response-id, Gnome::Gtk4::Dialog :_widget($dialog),
  Gnome::Gtk4::Entry :$entry, Gnome::Gtk4::ComboBoxText :$combobox,
) {
  my Bool $sts-ok = False;
  $!statusbar.remove-message;

  my GtkResponseType() $response-type = $response-id;

  given $response-type {
    when GTK_RESPONSE_DELETE_EVENT {
      note 'deleted';
      #ignore
      $sts-ok = True;
    }

    when GTK_RESPONSE_ACCEPT {
      my Str $cat-text = $entry.get-text;

      if !$cat-text {
        $!statusbar.set-status('No category name specified');
      }

      elsif $cat-text.lc eq 'default' {
        $!statusbar.set-status(
           'Category \'default\' is fixed in any form of text-case'
        );
      }

      elsif $*puzzle-data<category>{$cat-text}:exists {
        $!statusbar.set-status('Category already defined');
      }

      elsif $cat-text eq $combobox.get-active-text {
        $!statusbar.set-status('Category text same as selected');
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

