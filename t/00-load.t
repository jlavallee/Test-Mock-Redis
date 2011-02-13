#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Mock::Redis' ) || print "Bail out!
";
}

diag( "Testing Mock::Redis $Mock::Redis::VERSION, Perl $], $^X" );
