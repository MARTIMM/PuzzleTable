use v6.d;

use PuzzleTable::Types;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Totals;

has Supply $!supply;
has Array $!totals;

#-------------------------------------------------------------------------------
submethod BUILD ( Supply :$!supply ) {
  self!init-totals;

  $!supply.tap(
    -> Hash $command {

      # It's for us only when the code is PROCESS_TOTALS
      next unless $command<code> ~~ PROCESS_TOTALS;

      # With it, there must be a data hash. The operations are
      # add, substract, get, report. Get and report returns answers
      # using a provided channel.
      with $command<data> {
        when .<add>:exists {
          self!add( .<n>, .<type>);
        }

        when .<substract>:exists {
          self!substract( .<n>, .<type>);
        }

        when .<get>:exists {
          die "No channel available" unless ?.<channel>;
          .<channel>.send(self!get(.<type>));
        }

        when .<report>:exists {
          die "No channel available" unless ?.<channel>;
          .<channel>.send(self!get-report);
        }
      }
    }
  )
}

#-------------------------------------------------------------------------------
method !init-totals ( ) {
  $!totals = [ 0, 0, 0, 0];
}

#-------------------------------------------------------------------------------
method !add ( UInt $n, TotalType $entry ) {
  $!totals[$entry] += $n;
}

#-------------------------------------------------------------------------------
method !substract ( UInt $n, TotalType $entry ) {
  $!totals[$entry] -= $n;

  # Test needed when < 0, => reset to 0
  $!totals[$entry] = 0 if $!totals[$entry] < 0;
}

#-------------------------------------------------------------------------------
method !get ( TotalType $entry --> UInt ) {
  $!totals[$entry];
}

#-------------------------------------------------------------------------------
method !get-report ( --> Str ) {
  Q:qq:to/EOTT/;
    Number of puzzles
    Untouched puzzles
    Unfinished puzzles
    Finished puzzles

    Totals
    [ $!totals.join(', ') ]
    EOTT
}
