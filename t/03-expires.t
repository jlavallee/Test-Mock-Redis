#!perl -T

use strict;
use warnings;
use Test::More;
use Test::Mock::Redis;

=pod
x   SETEX
x   EXPIRE
x   EXPIREAT
x   PERSIST
=cut

my $r = Test::Mock::Redis->new;

ok($r->set('foo', 'foobar'), 'can set foo');
ok($r->set('bar', 'barfoo'), 'can set bar');
ok($r->set('baz', 'bazbaz'), 'can set baz');

ok(! $r->expire('quizlebub', 1), 'expire on a key that doesn\'t exist returns false');
ok($r->expire('bar', 1), 'expire on a key that exists returns true');

sleep 1;

ok(! $r->exists('bar'), 'bar expired');

ok(! $r->expireat('quizlebub', time + 1), 'expireat on a key that doesn\'t exist returns false');
ok($r->expireat('baz', time + 1), 'expireat on a key that exists returns true');

sleep 1;

ok(! $r->exists('baz'), 'baz expired');

ok($r->setex('foo', 'foobar', 1), 'set foo again returns a true value');

sleep 1;

ok(! $r->exists('foo'), 'foo expired');

ok($r->setex('foo', 'foobar', 2), 'set foo again returns a true value');
ok($r->persist('foo'), 'persist for a key that exists returns true');

ok(! $r->persist('quizlebub'), 'persist returns false for a key that doesn\'t exist');

sleep 2;

is($r->get('foo'), 'foobar', 'foo persisted');

done_testing();
