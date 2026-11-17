use v6.d;

use PuzzleTable::Types;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Totals;

has Supply $!supply;
has @!totals;

#-------------------------------------------------------------------------------
submethod BUILD ( Supply :$!supply ) {
  self!init-totals;

  $!supply.tap(
    -> Hash $command {

      # It's for us only when the code is PROCESS_TOTALS
      next unless $command<code> ~~ PROCESS_TOTALS;
#note $?LINE;
#dd $command;

      # With it, there are other keys at the same level for the operations.
      # The operations are add, set, substract, get, check and report. 
      # Get, check and report return answers using a provided channel.
      # The code throws an error if there is not a channel to return
      # an answer.
      with $command {
        when .<add>:exists {
          self!add( .<n>, .<type>);
        }

        when .<set>:exists {
          die "No channel available" unless ?.<channel>;
          .<channel>.send(self!set(.<a>));
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

        when .<check>:exists {
          die "No channel available" unless ?.<channel>;
          .<channel>.send(self!check);
        }
      }
    }
  )
}

#-------------------------------------------------------------------------------
method !init-totals ( ) {
  @!totals = [ 0, 0, 0, 0];
}

#-------------------------------------------------------------------------------
method !add ( UInt $n, TotalType $entry ) {
  @!totals[$entry] += $n;
}

#-------------------------------------------------------------------------------
method !set ( @a --> Bool ) {
  @!totals = @!totals Z+ @a;

  self!check
}

#-------------------------------------------------------------------------------
method !substract ( UInt $n, TotalType $entry ) {
  @!totals[$entry] -= $n;

  # Test needed when < 0, => reset to 0
  @!totals[$entry] = 0 if @!totals[$entry] < 0;
}

#-------------------------------------------------------------------------------
method !get ( TotalType $entry --> UInt ) {
  @!totals[$entry];
}

#-------------------------------------------------------------------------------
method !check ( --> Bool ) {
  @!totals[TOTAL_PUZZLES] == 
    [+] @!totals[UNTOUCHED_PUZZLES], @!totals[UNFINISHED_PUZZLES], @!totals[FINISHED_PUZZLES];
}

#-------------------------------------------------------------------------------
method !get-report ( --> Str ) {
  Q:qq:to/EOTT/;
    Number of puzzles
    Untouched puzzles
    Unfinished puzzles
    Finished puzzles

    Totals
    [ @!totals.join(', ') ]
    EOTT
}
