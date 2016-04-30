#!perl -T

use strict;
use warnings;
use lib 't/tlib';
use Test::More;
use Test::Mock::Redis;

=pod
    BLPOP
    BRPOP
    BRPOPLPUSH
x   LINDEX
    LINSERT
x   LLEN
x   LPOP
x   LPUSH
x   LPUSHX
o   LRANGE
    LREM
    LSET
    LTRIM
x   RPOP
    RPOPLPUSH
x   RPUSH
x   RPUSHX
=cut

ok(my $r = Test::Mock::Redis->new, 'pretended to connect to our test redis-server');
my @redi = ($r);

my ( $guard, $srv );
if( $ENV{RELEASE_TESTING} ){
    use_ok("Redis");
    use_ok("Test::SpawnRedisServer");
    ($guard, $srv) = redis();
    ok(my $r = Redis->new(server => $srv), 'connected to our test redis-server');
    $r->flushall;
    unshift @redi, $r
}

foreach my $r (@redi){
    diag("testing $r") if $ENV{RELEASE_TESTING};

    $r->set('foo', 'foobar');

    is $r->$_('list'), undef, "$_ on key that doesn't exist returns undef"
        for (qw/lpop rpop/);

    ok ! $r->$_('list'), "$_ on key that doesn't exist returns undef"
        for (qw/lpop rpop/);

    # TODO: is this the expected behavior?
    is $r->llen('list'), 0, "llen returns 0 for a list that doesn't exist";

    for my $op (qw/lpush rpush/){
        eval { $r->lpush('foo', 'barfoo') };
        like $@, qr/^\Q[lpush] ERR Operation against a key holding the wrong kind of value\E/, "lpush against a key that doesn't hold a list died";

        ok ! $r->exists("list-$op"), "key 'list-$op' does not exist yet";
        is $r->$op("list-$op", 'foobar'), 1, "$op returns length of list";
        is $r->llen("list-$op"),          1, "llen agrees";
        is $r->$op("list-$op", 'barfoo'), 2, "$op returns length of list";
        is $r->llen("list-$op"),          2, "llen agrees";
        is $r->$op("list-$op", 'bazbaz'), 3, "$op returns length of list";
        is $r->llen("list-$op"),          3, "llen agrees";
        is $r->$op("list-$op", 'quxqux'), 4, "$op returns length of list";
        is $r->llen("list-$op"),          4, "llen agrees";
    }

    $r->rpush('list', $_) for 0..9;

    is $r->lindex('list', $_), $_ for 0..9;

    is $r->llen('list'), 10, 'llen returns length of list';

    is $r->lpop('list'), $_ for 0..9;

    # TODO: is this the expected behavior?
    is $r->llen('list'), 0, 'llen returns zero for empty list';

    $r->lpush('list', $_) for 0..9; # just for rpop
    is $r->rpop('list'), $_ for 0..9;

    # TODO rpush( 'list', 0..9 ) should also work

    # rpushlpop
    # Setup...
    $r->rpush(source => $_) for 'a', 'b', 'c';
    $r->rpush(destination => $_) for 'x', 'y', 'z';

    is $r->rpoplpush('list-that-does-not-exist', 'dummy'), undef;
    is $r->rpoplpush('source', 'destination'), 'c';
    list_exactly_contains($r, source => 'a', 'b');
    list_exactly_contains($r, destination => 'c', 'x', 'y', 'z');

    is $r->rpoplpush(destination => 'destination'), 'z';
    list_exactly_contains($r, destination => 'z', 'c', 'x', 'y');

    is_deeply([$r->lrange(destination => 0, 2)], [qw/z c x/]);
    is_deeply([$r->lrange(destination => 1, 2)], [qw/c x/]);
    is_deeply([$r->lrange(destination => 1, -1)], [qw/c x y/]);
    is_deeply([$r->lrange(destination => 2, -2)], [qw/x/]);
    is_deeply([$r->lrange(destination => -3, 5)], [qw/c x y/]);
    is_deeply([$r->lrange(destination => 3, 1)], []);
}

sub list_exactly_contains {
    my ( $redis, $list, @elements ) = @_;

    my @from_redis = $redis->lrange($list, 0, scalar @elements);

    for my $i (0 .. $#elements) {
        is $from_redis[$i], $elements[$i];
    }

    is $redis->lindex($list, $#elements + 1), undef;
}

done_testing();
