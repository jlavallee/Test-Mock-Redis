#!perl

use Test::More;
use Test::Mock::Redis;

=pod
    DEL
    EXISTS
    KEYS
    MOVE
    RANDOMKEY
    RENAME
    RENAMENX
    TTL
    TYPE
    SORT   <-- TODO, requires list/set/sorted set
=cut

my $r = Test::Mock::Redis->new;

ok($r->set('foo', 'foobar'), 'can set foo');

is($r->randomkey, 'foo', 'randomkey returns foo, because it\'s all we have');

ok($r->set('bar', 'barfoo'), 'can set bar');
ok($r->set('baz', 'bazbaz'), 'can set baz');

is_deeply([ $r->keys('ba*') ], [qw/bar baz/], 'keys ba* matches bar and baz');

ok(! $r->del('quizlebub'), 'del on a key that doesn\'t exist returns false');
ok($r->del('foo'), 'del on a key that exists returns true');

is($r->get('bar'), 'barfoo', 'get returns correct value');

ok($r->set('foo', 'foobar'), 'can set foo again');

my $rand = $r->randomkey;

ok(grep { $_ eq $rand } qw/foo bar baz/, 'random returned one of our keys');

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

ok($r->move('foo', 1), 'move returns true on success');
ok(! $r->get('foo'), 'move moved foo');
ok(! $r->move('foo', 1), 'move returns false when key does not exist in source');
ok($r->select(1), 'select returns true on success');
ok($r->exists('foo'), 'move moved foo and exists found it');
ok($r->select(0), 'select returns true on success');
$r->set('foo', 'foobar');  # put it back in db0
ok(! $r->move('foo', 1), 'move returns false when key already exists in destination');


done_testing();
