#!perl

use Test::More;

use Test::Mock::Redis;

=pod
    DEL
    EXISTS
    EXPIRE
    EXPIREAT
    KEYS
    MOVE
    PERSIST
    RANDOMKEY
    RENAME
    RENAMENX
    SORT
    TTL
    TYPE
=cut

my $r = Test::Mock::Redis->new;

ok(! $r->exists('foo'), 'foo does not exist yet');
ok($r->set('foo', 'foobar'), 'can set foo');
ok($r->set('bar', 'barfoo'), 'can set bar');
ok($r->set('baz', 'bazbaz'), 'can set baz');

is_deeply([ $r->keys('ba*') ], [qw/bar baz/], 'keys ba* matches bar and baz');

ok(! $r->del('quizlebub'), 'del on a key that doesn\'t exist returns false');
ok($r->del('foo'), 'del on a key that exists returns true');

is($r->get('bar'), 'barfoo', 'get returns correct value');

ok(! $r->expire('quizlebub', 1), 'expire on a key that doesn\'t exist returns false');
ok($r->expire('bar', 1), 'expire on a key that exists returns true');

sleep 1;
is($r->get('bar'), undef, 'bar expired');

ok(! $r->expireat('quizlebub', time + 1), 'expireat on a key that doesn\'t exist returns false');
ok($r->expireat('baz', time + 1), 'expireat on a key that exists returns true');

sleep 1;

is($r->get('baz'), undef, 'baz expired');

done_testing();
