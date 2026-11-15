use v6.d;

use PuzzleTable::Types;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Config::Totals;

has Supply $!supply;
has Array $!totals;

#-------------------------------------------------------------------------------
submethod BUILD ( Supply :$!supply ) {
  self.init-totals;

  $!supply.tap( -> Hash $command {
    next unless $command<code> ~~ DO_TOTALS;
    with $command<data> {
      when .<add>:exists {
        self.add( .<n>, .<type>);
      }
    }
  })
}

#-------------------------------------------------------------------------------
method init-totals ( ) {
  $!totals = [ 0, 0, 0, 0];
}

#-------------------------------------------------------------------------------
method add ( UInt $n, TotalType $entry ) {
  $!totals[$entry] += $n;
}

#-------------------------------------------------------------------------------
method substract ( UInt $n, TotalType $entry ) {
  $!totals[$entry] -= $n;
  #TODO test needed when < 0?
}

#-------------------------------------------------------------------------------
method get ( TotalType $entry --> UInt ) {
  $!totals[$entry];
}

#-------------------------------------------------------------------------------
method get-report ( --> Str ) {
  Q:qq:to/EOTT/;
    Number of puzzles
    Untouched puzzles
    Unfinished puzzles
    Finished puzzles

    Totals
    [ $!totals.join(', ') ]
    EOTT
}
