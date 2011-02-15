#!perl -T

use utf8;
use strict;
use warnings;
use Test::More;
use Test::Mock::Redis;

=pod
x   APPEND
x   DECR
x   DECRBY
x   GET
    GETBIT
    GETRANGE
o   GETSET   <-- needs error for non-string value
x   INCR
x   INCRBY
x   MGET
x   MSET
x   MSETNX
x   SET
    SETBIT
x   SETNX
    SETRANGE
o   STRLEN   <-- TODO: determine correct behavior w/multi-byte chars
=cut

my $r = Test::Mock::Redis->new;

ok(! $r->exists('foo'), 'foo does not exist yet');
is($r->get('foo'), undef, 'get on a key that doesn\'t exist returns undef');

ok($r->set('foo', 'foobar'), 'can set foo');
ok($r->set('bar', 'barfoo'), 'can set bar');
ok($r->set('baz', 'bazbaz'), 'can set baz');

is($r->get('foo'), 'foobar', 'can get foo');
is($r->get('bar'), 'barfoo', 'can get bar');
is($r->get('baz'), 'bazbaz', 'can get baz');

ok(! $r->setnx('foo', 'foobar'), 'setnx returns false for existing key');
ok($r->setnx('qux', 'quxqux'),   'setnx returns true for new key');

is($r->incr('incr-test'),  1, 'incr returns  1 for new value');
is($r->decr('decr-test'), -1, 'decr returns -1 for new value');

is($r->incr('incr-test'),  2, 'incr returns  2 the next time');
is($r->decr('decr-test'), -2, 'decr returns -2 the next time');

is($r->incr('decr-test'), -1);
is($r->incr('decr-test'),  0, 'decr returns 0 appropriately');

is($r->decr('incr-test'), 1);
is($r->decr('incr-test'), 0, 'incr returns 0 appropriately');

is($r->incrby('incrby-test', 10),  10, 'incrby 10 returns incrby value for new value');
is($r->decrby('decrby-test', 10), -10, 'decrby 10 returns decrby value for new value');

is($r->decrby('incrby-test', 10), 0, 'incrby returns 0 appropriately');
is($r->incrby('decrby-test', 10), 0, 'decrby returns 0 appropriately');

is($r->incrby('incrby-test', -15), -15, 'incrby a negative value works');
is($r->decrby('incrby-test', -15),   0, 'decrby a negative value works');

is($r->append('append-test', 'foo'), 3, 'append returns length (for new)');
is($r->append('append-test', 'bar'), 6, 'append returns length');
is($r->append('append-test', 'baz'), $r->strlen('append-test'), 'strlen agrees with append');

is($r->strlen('append-test'), 9, 'length of append-test key is now 9');

# TODO: is this behavior correct?
is($r->append('append-test', '€'), 10, 'euro character (multi-byte) only counted as one character');

is($r->getset('foo', 'whee!'),  'foobar', 'getset returned old value of foo');
is($r->getset('foo', 'foobar'), 'whee!',  'getset returned old value of foo again (so it must have been set)');


is_deeply([$r->mget(qw/one two three/)], [undef, undef, undef], 'mget returns correct number of undefs');

ok([$r->mset(one => 'fish', two => 'fish', red => 'herring')], 'true returned for Dr Seuss');

is_deeply([$r->mget(qw/one two red blue/)], [qw/fish fish herring/, undef], 'mget returned Dr Seuss and undef');

is_deeply([$r->mget(qw/two blue one red/)], [qw/fish/, undef, qw/fish herring/], 'mget likes order');

ok( !$r->msetnx(blue => 'fish', red => 'fish'), 'msetnx fails if any key exists');

is($r->get('red'), 'herring', 'msetnx left red alone');

ok($r->del('red'), 'bye bye red');

ok($r->msetnx(blue => 'fish', red => 'fish'), 'msetnx sets multiple keys');

is_deeply([$r->mget(qw/one two red blue/)], [qw/fish fish fish fish/], 'all fish now');



=pod
TODO: {
    local $TODO = "no setbit/getbit yet";

    # set the first 8 bits to 0, and the next 8 to 1
    ok(! $r->setbit('bits', $_, 0) for(0..7);
    ok(! $r->setbit('bits', $_, 1) for(8..15);

    ok(! $r->getbit('bits', $_), "got 0 at bit offset $_") for(0..7);
    ok($r->getbit('bits', $_), "got 1 at bit offset $_") for(8..15);
    ok(! $r->getbit('bits', 16), "got 1 at bit offset $_");
};
=cut



done_testing();
