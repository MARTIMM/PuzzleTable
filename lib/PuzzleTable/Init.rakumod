
use v6.d;

use PuzzleTable::Types;

use Gnome::Gtk4::CssProvider:api<2>;
use Gnome::Gtk4::StyleContext:api<2>;
use Gnome::Gtk4::T-StyleProvider:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class PuzzleTable::Init:auth<github:MARTIMM>;

my Gnome::Gtk4::CssProvider $css-provider;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  unless ?$css-provider {
    # Create css file
    (PUZZLE_CSS).IO.spurt(q:to/EOCSS/);
      window {
      }

      .puzzle-table-frame {
        border-width: 3px;
        border-style: outset;
        border-color: #ffee00;
        padding: 3px;
      /*	border-style: inset; */
      /*	border-style: solid; */
      /*	border-style: none; */
      }

      .puzzle-grid child {
        border-width: 1px;
        border-style: inset;
        border-color: #8800ff;
        padding: 0px;
      /*
        min-width: 300px;
        min-height: 300px;
        max-width: 300px;
        max-height: 300px;
      */
      }

      EOCSS

    $css-provider .= new-cssprovider;
    $css-provider.load-from-path(PUZZLE_CSS);
  }
}

#-------------------------------------------------------------------------------
method set-css ( N-Object $context, Str :$css-class = '' ) {

  my Gnome::Gtk4::StyleContext $style-context .= new(:native-object($context));
  $style-context.add-provider(
    $css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
  );
  $style-context.add-class($css-class) if ?$css-class;
}
