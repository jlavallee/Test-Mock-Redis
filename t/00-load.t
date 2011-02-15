#!perl -T

use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use_ok( 'Test::Mock::Redis' ) || print "Bail out!
";
}

diag( "Testing Test::Mock::Redis $Test::Mock::Redis::VERSION, Perl $], $^X" );
