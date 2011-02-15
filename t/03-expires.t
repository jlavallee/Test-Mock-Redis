#!perl

use Test::More;
use Test::Mock::Redis;

=pod
    EXPIRE
    EXPIREAT
    PERSIST
=cut

my $r = Test::Mock::Redis->new;

ok($r->set('foo', 'foobar'), 'can set foo');
ok($r->set('bar', 'barfoo'), 'can set bar');
ok($r->set('baz', 'bazbaz'), 'can set baz');

ok(! $r->expire('quizlebub', 1), 'expire on a key that doesn\'t exist returns false');
ok($r->expire('bar', 1), 'expire on a key that exists returns true');

sleep 1;
is($r->get('bar'), undef, 'bar expired');

ok(! $r->expireat('quizlebub', time + 1), 'expireat on a key that doesn\'t exist returns false');
ok($r->expireat('baz', time + 1), 'expireat on a key that exists returns true');

sleep 1;

is($r->get('baz'), undef, 'baz expired');

ok($r->setex('foo', 'foobar', 1), 'set foo again returns a true value');

sleep 1;

is($r->get('foo'), undef, 'foo expired');

ok($r->setex('foo', 'foobar', 2), 'set foo again returns a true value');
ok($r->persist('foo'));

sleep 2;

is($r->get('foo'), 'foobar', 'foo persisted');

done_testing();
