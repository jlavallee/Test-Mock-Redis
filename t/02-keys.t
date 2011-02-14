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
    SORT   <-- TODO, requires list/set/sorted set
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

ok($r->setex('foo', 'foobar', 1), 'set foo again returns a true value');

sleep 1;

is($r->get('foo'), undef, 'foo expired');

ok($r->setex('foo', 'foobar', 2), 'set foo again returns a true value');
ok($r->persist('foo'));

sleep 2;

is($r->get('foo'), 'foobar', 'foo persisted');

is($r->randomkey, 'foo', 'randomkey returns foo, because it\'s all we have');

my %stuff = ( icky => 'poo', blecky => 'shoe' );
$r->set($_, $stuff{$_}) for keys %stuff;

my $rand = $r->randomkey;

ok(grep { $_ eq $rand } qw/icky foo blecky/, 'random returned one of our keys');

ok(! $r->rename('foo', 'foo'), 'rename with identical source and dest returns false');
ok(! $r->rename('quizlebub', 'foo'), 'rename with source that doesn\'t exist returns false');
ok($r->rename('foo', 'newfoo'), 'rename returns true on success');
is( $r->get('newfoo'), 'foobar', 'rename worked');

$r->set('foo', 'foobar');
ok(! $r->renamenx('newfoo', 'foo'), 'renamenx returns false when destination key exists');
ok($r->renamenx('newfoo', 'newfoo2'), 'renamenx returns true on success');
is( $r->get('newfoo2'), 'foobar', 'renamenx worked');

$r->expire('newfoo2', 3);
ok($r->ttl('newfoo2') >= 2, 'ttl for newfoo2 is at least 2');

is($r->type('foo'), 'string', 'type works for simple key/value');


done_testing();
