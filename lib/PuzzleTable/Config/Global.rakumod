use v6.d;

use YAMLish;
use Digest::SHA256::Native;

use PuzzleTable::Types;
use PuzzleTable::Config::Puzzle;
use PuzzleTable::Config::Category;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Global:auth<github:MARTIMM>;

has Hash $.global-config;

has Str $!root-dir;
has Str $!puzzle-trash;
has Hash $.categories-config;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$!root-dir ) {

  $!puzzle-trash = "$!root-dir/puzzle-trash/";
  mkdir( $!puzzle-trash, 0o700) unless $!puzzle-trash.IO.e;

  if "$!root-dir/global-config.yaml".IO.r {
    # Only need to load it once
    $!global-config = load-yaml("$!root-dir/global-config.yaml".IO.slurp)
      unless ?$!global-config;
  }

  else {
    $!global-config<password> = '';

    given $!global-config<palapeli><Flatpak> {
      .<collection> = '.var/app/org.kde.palapeli/data/palapeli/collection';
      .<exec> = "/usr/bin/flatpak run --filesystem={$!root-dir.IO.absolute}:ro --branch=stable --arch=x86_64 --command=palapeli --file-forwarding org.kde.palapeli";
    }

    given $!global-config<palapeli><Snap> {
      .<collection> = 'snap/palapeli/current/.local/share/palapeli/collection';
      .<exec> = '/var/lib/snapd/snap/bin/palapeli';
      .<env> = %(
        :BAMF_DESKTOP_FILE_HINT</var/lib/snapd/desktop/applications/palapeli_palapeli.desktop>,
        :GDK_BACKEND<x11>,
      )
    }

    given $!global-config<palapeli><Standard> {
      .<collection> = '.local/share/palapeli/collection';
      .<exec> = '/usr/bin/palapeli';
      .<env> = %(
        :GDK_BACKEND<x11>,
      )
    }

    $!global-config<palapeli><preference> = 'Snap';

    # Default width and height of displayed puzzle image
    $!global-config<puzzle-image-width> = 300;
    $!global-config<puzzle-image-height> = 300;
  }

  # Always lock at start
  $!global-config<locked> = True;
}

#-------------------------------------------------------------------------------
# Called after adding, removing, or other changes are made on a category
method save-global-config ( ) {

  my $t0 = now;

  # Save categories config
  "$!root-dir/global-config.yaml".IO.spurt(save-yaml($!global-config));

  note "Time needed to save categories: {(now - $t0).fmt('%.1f sec')}."
       if $*verbose-output;
}

#-------------------------------------------------------------------------------
method set-palapeli-preference ( Str $preference ) {
  if $preference ~~ any(<Snap Flatpak Standard>) {
    $!global-config<palapeli><preference> = $preference;
  }

  else {
    $!global-config<palapeli><preference> = 'Standard';
  }

  self.save-global-config;
}

#-------------------------------------------------------------------------------
method get-palapeli-preference ( --> Str ) {
  $!global-config<palapeli><preference>
}

#-------------------------------------------------------------------------------
method set-palapeli-image-size ( Int() $width, Int() $height ) {
  $!global-config<puzzle-image-width> = $width;
  $!global-config<puzzle-image-height> = $height;
  self.save-global-config;
}

#-------------------------------------------------------------------------------
method get-palapeli-image-size ( --> List ) {
  $!global-config<puzzle-image-width>, $!global-config<puzzle-image-height>
}

#-------------------------------------------------------------------------------
method get-palapeli-collection ( --> Str ) {
  my $preference = $!global-config<palapeli><preference>;
  $!global-config<palapeli>{$preference}<collection>
}

#-------------------------------------------------------------------------------
method set-palapeli-env ( ) {
  my $preference = $!global-config<palapeli><preference>;
  for $!global-config<palapeli>{$preference}<env>.kv -> $env-key, $env-val {
    %*ENV{$env-key} = $env-val;
  }
}

#-------------------------------------------------------------------------------
method unset-palapeli-env ( ) {
  my $preference = $!global-config<palapeli><preference>;
  for $!global-config<palapeli>{$preference}<env>.keys -> $env-key {
    %*ENV{$env-key}:delete;
  }
}

#-------------------------------------------------------------------------------
method get-palapeli-exec ( --> Str ) {
  my $preference = $!global-config<palapeli><preference>;
  $!global-config<palapeli>{$preference}<exec>
}

#-------------------------------------------------------------------------------
method get-password ( --> Str ) {
  $!global-config<password> // ''
}

#-------------------------------------------------------------------------------
method check-password ( Str $password --> Bool ) {
  my Bool $ok = True;
  $ok = ( sha256-hex($password) eq $!global-config<password> ).Bool
    if ? $!global-config<password>;

  $ok
}

#-------------------------------------------------------------------------------
method set-password ( Str $old-password, Str $new-password --> Bool ) {
  my Bool $is-set = False;

  # Return fault when old one is empty while there should be one given.
  return $is-set if $old-password eq '' and ?self.get-password;

  # Check if old password matches before a new one is set
  $is-set = self.check-password($old-password);
  if $is-set {
    $!global-config<password> = sha256-hex($new-password);
    self.save-global-config;
  }

  $is-set
}

#-------------------------------------------------------------------------------
# Get the puzzle table locking state
method is-locked ( --> Bool ) {
  ? $!global-config<locked>.Bool;
}

#-------------------------------------------------------------------------------
# Set the puzzle table locking state
method lock ( ) {
  $!global-config<locked> = True;
  self.save-global-config;
}

#-------------------------------------------------------------------------------
# Reset the puzzle table locking state
method unlock ( Str $password --> Bool ) {
  my Bool $ok = self.check-password($password);
  $!global-config<locked> = False if $ok;
  self.save-global-config;
  $ok
}

#-------------------------------------------------------------------------------
method get-puzzle-trash ( --> Str ) {
  $!puzzle-trash
}