use v6.d;

# Dialog seems to be deprecated since 4.10 so here we have our own

use PuzzleTable::Config;
use PuzzleTable::Gui::DialogLabel;
use PuzzleTable::Gui::Statusbar;
use PuzzleTable::Gui::Category;

use Gnome::Gtk4::Window:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::T-Enums:api<2>;

use Gnome::Glib::N-MainLoop:api<2>;

use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::Dialog:auth<github:MARTIMM>;
also is Gnome::Gtk4::Window;

has $!main is required;
has Gnome::Gtk4::Grid $!content;
has Int $!content-count;

has Gnome::Gtk4::Box $!button-row;
has PuzzleTable::Gui::Statusbar $!statusbar;
has Gnome::Glib::N-MainLoop $!main-loop;

#-------------------------------------------------------------------------------
method new ( |c ) {
#note "$?LINE ", c.gist;
  self.new-window(|c);
}

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main, Str :$dialog-header = '' ) {
  $!main-loop .= new-mainloop( N-Object, True);

  $!content-count = 0;
  $!content .= new-grid;

  $!button-row .= new-box( GTK_ORIENTATION_HORIZONTAL, 4);
  with my Gnome::Gtk4::Label $button-row-strut .= new-label {
    .set-text(' ');
    .set-halign(GTK_ALIGN_FILL);
    .set-hexpand(True);
    .set-wrap(False);
    .set-visible(True);
  }
  $!button-row.append($button-row-strut);

  $!statusbar .= new-statusbar(:context<dialog>);

  my Gnome::Gtk4::Label $header .= new-label;
  $header.set-text($dialog-header);
  with my Gnome::Gtk4::Box $box .= new-box( GTK_ORIENTATION_VERTICAL, 0) {
    .append($header);
    .append($!content);
    .append($!button-row);
    .append($!statusbar);
    .set-visible(True);
  }

  with self {
    $!main.config.set-css( .get-style-context, :css-class<puzzle-dialog>);
    .set-transient-for($!main.application-window);
    .set-destroy-with-parent(True);
    .set-modal(True);
    .set-size-request( 400, 100);
    .set-title($dialog-header);
    .register-signal( self, 'close-dialog', 'destroy');
    .set-child($box);
  }
}

#-------------------------------------------------------------------------------
method add-content ( Str $text, Mu $widget ) {
  with my Gnome::Gtk4::Label $label .= new-label {
    .set-text($text);
    .set-hexpand(True);
    .set-halign(GTK_ALIGN_START);
    .set-margin-end(5);
  }

  $!content.attach( $label, 0, $!content-count, 1, 1);
  $!content.attach( $widget, 1, $!content-count, 1, 1);
  $!content-count++;
}

#-------------------------------------------------------------------------------
method add-button ( Mu $object, Str $method, Str $button-label, *%options ) {
  my Gnome::Gtk4::Button $button .= new-button;
  $button.set-label($button-label);
  $button.register-signal( $object, $method, 'clicked', |%options);
  $!button-row.append($button);
}

#-------------------------------------------------------------------------------
method clear-status ( ) {
  $!statusbar.remove-message;
}

#-------------------------------------------------------------------------------
method set-status ( Str $message ) {
  $!statusbar.remove-message;
  $!statusbar.set-status($message);
}

#-------------------------------------------------------------------------------
method show-dialog ( ) {
  self.set-visible(True);
  $!main-loop.run;
}

#-------------------------------------------------------------------------------
method destroy-dialog ( ) {
  $!main-loop.quit;
  self.destroy;
  self.clear-object;
}
