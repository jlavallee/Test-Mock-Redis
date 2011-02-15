#!perl -T

use strict;
use warnings;
use Test::More;
use Test::Mock::Redis;

=pod
x   HDEL
x   HEXISTS
x   HGET
    HGETALL
    HINCRBY
x   HKEYS
x   HLEN
    HMGET
    HMSET
x   HSET
    HSETNX
    HVALS
=cut

my $r = Test::Mock::Redis->new;

is($r->hget('hash', 'foo'), undef, "hget for a hash that doesn't exist is undef");

is_deeply([sort $r->hkeys('hash')], [], "hkeys returned no keys for a hash that doesn't exist");

ok($r->hset('hash', 'foo', 'foobar'), "hset returns true when it's happy");

is($r->hget('hash', 'foo'), 'foobar', "hget returns the value we just set");

is($r->type('hash'), 'hash', "type of key hash is hash");

is($r->hget('hash', 'bar'), undef, "hget for a hash field that doesn't exist is undef");

ok($r->hset('hash', 'bar', 'foobar'), "hset returns true when it's happy");

is($r->hlen('hash'), 2, 'hlen counted two keys');

is_deeply([sort $r->hkeys('hash')], [qw/bar foo/], 'hkeys returned our keys');

ok(! $r->hset('hash', 'bar', 'barfoo'), "hset returns false when they field already existed");

is($r->hget('hash', 'bar'), 'barfoo', "hget returns the value we just set");

ok($r->set('hash', 'blarg'), "set returns true when we squash a hash");

is($r->get('hash'), 'blarg', "even though it squashed it");

ok($r->hset('hash', 'foo', 'foobar'), "hset returns true when we overwrite a string with a hash");

is($r->hget('hash', 'foo'), 'foobar', "hget returns the value we just set");

ok(! $r->hexists('blarg', 'blorf'), "hexists on a hash that doesn't exist returns false");
ok(! $r->hexists('hash', 'blarg'),  "hexists on a hash field that doesn't exist returns false");

ok($r->hexists('hash', 'foo'), "hexists returns true when it's true");

ok(! $r->hdel('blarg', 'blorf'), "hdel on a hash that doesn't exist returns false");
ok(! $r->hdel('hash', 'blarg'),  "hdel on a hash field that doesn't exist returns false");

ok($r->hdel('hash', 'foo'), "hdel returns true when it's happy");

ok(! $r->hexists('hash', 'foo'), "hdel really deleted the field");

is($r->hlen('hash'), 0, 'hlen counted zarro keys');

is_deeply([sort $r->hkeys('hash')], [], "hkeys returned no keys for an empty hash");

done_testing();

