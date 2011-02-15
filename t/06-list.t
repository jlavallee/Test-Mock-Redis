#!perl -T

use strict;
use warnings;
use Test::More;
use Test::Mock::Redis;

=pod
    BLPOP
    BRPOP
    BRPOPLPUSH
    LINDEX
    LINSERT
    LLEN
x   LPOP
x   LPUSH
x   LPUSHX
    LRANGE
    LREM
    LSET
    LTRIM
    RPOP
    RPOPLPUSH
x   RPUSH
x   RPUSHX
=cut

my $r = Test::Mock::Redis->new;

$r->set('foo', 'foobar');

is $r->$_('list'), undef, "$_ on key that doesn't exist returns undef"
    for (qw/lpop rpop/);

ok ! $r->$_('list', 'blarg'), "$_ on key that doesn't exist returns undef"
    for (qw/lpop rpop/);

for my $op (qw/lpush rpush/){
    eval { $r->lpush('foo', 'barfoo') };
    like $@, qr/^\Q[lpush] ERR Operation against a key holding the wrong kind of value\E/, "lpush against a key that doesn't hold a list died";

    ok ! $r->exists("list-$op"), "key 'list-$op' does not exist yet";
    is $r->$op("list-$op", 'foobar'), 1, "$op returns length of list";
    is $r->$op("list-$op", 'barfoo'), 2, "$op returns length of list";
    is $r->$op("list-$op", 'bazbaz'), 3, "$op returns length of list";
    is $r->$op("list-$op", 'quxqux'), 4, "$op returns length of list";
}

$r->rpush('list', $_) for 0..9;

is $r->lindex('list', $_), $_ for 0..9;

is $r->lpop('list', $_), $_ for 0..9;

done_testing();
