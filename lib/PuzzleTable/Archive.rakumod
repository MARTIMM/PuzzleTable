use v6.d;

use Archive::Libarchive;
use Archive::Libarchive::Constants;
use YAMLish;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Archive:auth<github:MARTIMM>;

my Str $puzzle-file;
my regex extract-regex {^ [ image \. | pala \. desktop ] };

#-------------------------------------------------------------------------------
#submethod BUILD ( ) { }

#-------------------------------------------------------------------------------
# Extract image and desktop file from $puzzle-file, a tar file, and
# store the data at $store-path.
method extract ( Str:D $store-path, Str:D $puzzle-file ) {
  unless $puzzle-file ~~ m/ '.puzzle' $/ {
    note "'$puzzle-file' does not have proper extension, should be .puzzle";
    return;
  }

  unless $puzzle-file.IO.r {
    note "file '$puzzle-file' not found";
    return;
  }

  my Archive::Libarchive $archive .= new(
    operation => LibarchiveExtract,
    file => $puzzle-file,
    flags => ARCHIVE_EXTRACT_TIME +| ARCHIVE_EXTRACT_PERM +|
             ARCHIVE_EXTRACT_ACL +|  ARCHIVE_EXTRACT_FFLAGS
  );

  try {
    $archive.extract( &extract, $store-path);
    CATCH {
      say "Can't extract files: $_";
    }
  }

  $archive.close;
}

#-------------------------------------------------------------------------------
sub extract ( Archive::Libarchive::Entry $e --> Bool ) {
  $e.pathname ~~ m/ <extract-regex> /.Bool
}

#-------------------------------------------------------------------------------
method palapeli-info( Str:D $store-path --> Hash ) {

  my Hash $h = %();
  my Int $piece-count = 0;
  my Bool $do-count = False;
  for "$store-path/pala.desktop".IO.slurp.lines -> $line {
    $do-count = True if $line eq '[PieceOffsets]';
    $do-count = False if $line eq '[Relations]';

    next unless $line ~~ m/ '=' /;
    $piece-count++ if $do-count;

    my Str $slicer = '';
    my ( $name, $val) = $line.split('=');
#note "$?LINE $name, $val" if $name !~~ m/^ \d+ $/;
    given $name {
      when 'Comment' {
        $h<Comment> = $val // '';
      }

      when 'Name' {
        $h<Name> = $val // '';
      }

      when / Author / {
        $h<Source> = $val // '';
      }

      when 'ImageSize' {
        my $size = $val // '';
        my ( $width, $height) = $size.split(',');
        $h<ImageSize> = "$width x $height";
      }

      when 'Slicer' {
        $val ~~ s/^ palapeli '_' //;
        $val ~~ s/ slicer $//;
        $h<Slicer> = $val;
      }

      when 'SlicerMode' {
        if    $val eq 'preset' { $h<SlicerMode> = ', predefined cut'; }
        elsif $val eq 'rect'   { $h<SlicerMode> = ', rectangular cut'; }
        elsif $val eq 'cairo'  { $h<SlicerMode> = ', cairo cut'; }
        elsif $val eq 'hex'    { $h<SlicerMode> = ', hexagonal cut'; }
        elsif $val eq 'rotrex' { $h<SlicerMode> = ', rhombi trihexagonal cut'; }
        elsif $val eq 'irreg'  { $h<SlicerMode> = ', irregular cut'; }
        elsif $val eq ''       {
          if $h<Slicer> eq 'rect' {
            $h<SlicerMode> = ' cut in rectangles';
          }

          elsif $h<Slicer> eq 'jigsaw' {
            $h<SlicerMode> = ' cut in classic pieces';
          }
        }
      }
    }
  }

  $h<PieceCount> = $piece-count;

  $h
}

#-------------------------------------------------------------------------------
method archive-puzzles (
  Str:D $archive-trashbin, Str:D $category, Str:D $container is copy,
  Hash:D $puzzles

  --> Str
) {
  # Drop the container marker if any
  $container ~~ s/ '_EX_' $//;

  # Create the name of the archive
  my Str $archive-name;
  $archive-name = DateTime.now.Str;         # 2024-07-03T09:55:12.196236+02:00
  $archive-name ~~ s/ '.' (...) .* $/.$0/;  # keep 3 digits behind the dot
  $archive-name ~~ s:g/ <[:-]> //;          # remove all '-' and ':'
  $archive-name ~~ s:g/ <[T.]> /-/;         # replace 'T' with '-'
                                            # 20240703-095512-196
  $archive-name ~= ":$container:$category";

  # Change dir to archive path
  my Str $cwd = $*CWD.Str;
  my Str $archive-path = $archive-trashbin;
  chdir($archive-path);

  # Create a bzipped tar archive
  my Archive::Libarchive $archive .= new(
    operation => LibarchiveWrite,
    file => "$archive-trashbin$archive-name.tbz2",
    format => 'v7tar',
    filters => ['bzip2']
  );

  for $puzzles.keys -> $puzzle-id {

    # Rename the puzzle path into the archive path, effectively removing the
    # puzzle data from the other puzzles. Use $cwd to make path absolute. The
    # puzzle path is created in reference to the root of the table data.
    # But don't do it when path is absolute!
    my Str $puzzle-path = $puzzles{$puzzle-id}<puzzle-path>;
    $puzzle-path = "$cwd/$puzzle-path" unless $puzzle-path ~~ m/^ \/ /;
    $puzzle-path.IO.rename("./$puzzle-id");

    # Save config into a yaml file in the archive dir
    my Hash $puzzle-data = $puzzles{$puzzle-id}<puzzle-data>;
    "$puzzle-id/puzzle-data.yaml".IO.spurt(save-yaml($puzzle-data));

    # Store each file in this path into the archive
    for dir($puzzle-id) -> $file {
      $archive.write-header($file.Str);
      $archive.write-data($file.Str);
    }

    # Cleanup files in directory
    for dir($puzzle-id) -> $file {
      $file.IO.unlink;
    }

    # And the directory itself
    $puzzle-id.IO.rmdir;
  }

  # And close the archive
  $archive.close;

  # Return to dir where we started
  chdir($cwd);

  "$archive-name.tbz2"
}

#-------------------------------------------------------------------------------
method restore-puzzles (
  Str:D $archive-trashbin, Str:D $archive-name, Str:D $puzzle-root-path --> Hash
) {
  return Hash unless "$archive-trashbin$archive-name".IO.r;

  # Extract the data from the archive
  my Archive::Libarchive $archive .= new(
    operation => LibarchiveExtract,
    file => "$archive-trashbin$archive-name",
    flags => ARCHIVE_EXTRACT_TIME +| ARCHIVE_EXTRACT_PERM +|
             ARCHIVE_EXTRACT_ACL +|  ARCHIVE_EXTRACT_FFLAGS
  );

  try {
    $archive.extract("$archive-trashbin/puzzles");
    CATCH {
      $archive.close;
      say "Can't extract files: $_";
      return Hash;
    }
  }

  # Close the archive
  $archive.close;

  my Str $config-file;
  my Hash $puzzles = %();
  for dir("$archive-trashbin/puzzles") -> $pid {
    # Get the puzzle config data
    $config-file = "$pid/puzzle-data.yaml";

    my $puzzle-id = $pid.Str;
    $puzzle-id ~~ s/^ .*? (p\d\d\d) $/orig-$0/;
    $puzzles{$puzzle-id}<puzzle-data> = load-yaml($config-file.IO.slurp);
    $config-file.IO.unlink;

    # Remove unneeded data, older version might have it saved in the archive
    "/$pid/image.jpg".IO.unlink if "$pid/image.jpg".IO.e;
    "$pid/pala.desktop".IO.unlink if "$pid/pala.desktop".IO.e;

    # Rename the archive path into the puzzle path, effectively adding the
    # puzzle data into a category.
    my Int $count = 0;
    my Str $puzzle-path = "$puzzle-root-path/";
    while "$puzzle-path/$count.fmt('p%03d')".IO.e { $count++; }
    my Str $new-puzzle-id = $count.fmt('p%03d');

    $pid.rename("$puzzle-path/$new-puzzle-id");
    $puzzles{$puzzle-id}<puzzle-id> = $new-puzzle-id;
  }

  "$archive-trashbin/puzzles".IO.rmdir;

  $puzzles
}
