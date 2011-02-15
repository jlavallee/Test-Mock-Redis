#!perl

use Test::More;
use Test::Mock::Redis;


=pod
x   AUTH  
x   ECHO
x   PING
x   QUIT
o   SELECT  <-- TODO: complain about invalid values?
=cut

my $r = Test::Mock::Redis->new;

is($r->ping, 'PONG', 'ping returns PONG');
ok($r->select($_), "select returns true for $_") for 0..15;

# TODO: do we care?
eval{ $r->auth };
like($@, qr/^\Q[auth] ERR wrong number of arguments for 'auth' command\E/, 'auth without a password dies');

ok($r->auth('foo'), 'auth with anything else returns true');

ok($r->quit, 'quit returns true');
ok($r->quit, '...even if we call it again');

eval{ $r->ping };
like($@, qr/^Not connected to any server/, 'ping dies with message after we quit');

done_testing();


