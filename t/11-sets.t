#!perl -T

use strict;
use warnings;
use lib 't/tlib';
use Test::More;
use Test::Exception;
use Test::Mock::Redis;

=pod
x   SADD
x   SCARD
    SDIFF
    SDIFFSTORE
x   SINTER
x   SINTERSTORE
x   SISMEMBER
o   SMEMBERS
    SMOVE
o   SPOP
o   SRANDMEMBER
x   SREM
x   SUNION
x   SUNIONSTORE
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
    push @redi, $r;
}

my @members = (qw/foo bar baz qux quux quuux/);

foreach my $r (@redi){
    diag("testing $r") if $ENV{RELEASE_TESTING};


    is        $r->srandmember('noset'),         undef, "srandmember for a set that doesn't exist returns undef";
    is        $r->spop('noset'),                undef, "spop for a set that doesn't exist returns undef";
    is        $r->scard('noset'),                   0, "scard for a set that doesn't exist returns 0";
    is        $r->srem('noset', 'foo'),             0, "srem for a set that doesn't exist returns 0";
    is        $r->smove('noset', 'set', 'foo'),     0, "smove for sets that don't exist returns 0";
    is        $r->sismember('noset', 'foo'),        0, "sismember for a set that doesn't exist returns 0";
    is_deeply [$r->smembers('noset')],             [], "smembers for a set that doesn't exist returns an empty array";

    is $r->sadd('set', 'foo'),  1, "sadd returns 1 when element is new to the set";
    is $r->sadd('set', 'foo'),  0, "sadd returns 0 when element is already in the set";
    is $r->scard('set'),        1, "scard returns size of set";

    is $r->sadd('set', 'bar'),  1, "sadd returns 1 when element is new to the set";
    is $r->scard('set'),        2, "scard returns size of set";

    is $r->sismember('set', 'foo'), 1, "sismember returns 1 for a set element that exists";
    is $r->sismember('set', 'baz'), 0, "sismember returns 0 for a set element that doesn't exist";


    is_deeply [sort $r->smembers('set')], [qw/bar foo/], "smembers returns all members of the set";

    is $r->srem('set', 'bar'), 1, "srem returns 1 when it removes an element";

    is $r->sadd('set', $_), 1, "srem returns 1 when it adds a new element to the set" 
        for (grep { $_ ne 'foo'} @members);

    is $r->type('set'), 'set', "our set has type set";

    my $randmember = $r->srandmember('set');
    ok $randmember, "srandmember returned something";
    ok grep { $_ eq $randmember } $r->smembers('set'), "srandmember returned a member";

    while($r->scard('set')){
        my $popped = $r->spop('set');
        ok $popped, "spopped something";
        ok grep { $_ eq $popped } @members, "spopped a member";
        is $r->sismember('set', $popped), 0, "spop removed $popped";
    }

    # set has been emptied.  Put some stuff in it again
    is $r->sadd('set', $_), 1, "srem returns 1 when it adds a new element to the set" 
        for (@members);

    is $r->sadd('otherset', $_), 1, "srem returns 1 when it adds a new element to the set" 
        for (qw/foo bar baz/);

    is $r->sadd('anotherset', $_), 1, "srem returns 1 when it adds a new element to the set" 
        for (qw/bar baz qux/);

    is_deeply [sort $r->sinter('set', 'otherset')], [qw/bar baz foo/], "sinter returns all members in common";

    is_deeply [sort $r->sinter('set', 'otherset', 'anotherset')], [qw/bar baz/], 
        "sinter returns all members in common for multiple sets";

    is_deeply [$r->sinter('set', 'emptyset')], [], "sinter returns empty list";
    is_deeply [$r->sinter('set', 'otherset', 'emptyset')], [], "sinter returns empty list with multiple sets";

    is $r->sinterstore('destset', 'set', 'otherset'), 3, "sinterstore returns cardinality of intersection";
    is $r->sinterstore('destset', 'set', 'emptyset'), 0, "cardinality of empty intersection is zero";
    is $r->sinterstore('destset', 'set', 'anotherset', 'otherset'), 2, "sinterstore returns cardinality of intersection";

    is $r->sadd('otherset', $_), 1, "srem returns 1 when it adds a new element to the set" 
        for (qw/oink bah neigh/);

    is_deeply [sort $r->sunion('set', 'otherset')],   [sort @members, qw/oink bah neigh/], "sunion returns all members of two sets";
    is_deeply [sort $r->sunion('set', 'anotherset')], [sort @members], "sunion returns all members of two sets";

    is $r->sunionstore('destset', 'set', 'otherset'), @members + 3, "sunionstore returns cardinality of union";
    is $r->sunionstore('destset', 'set', 'emptyset'), @members,     "cardinality of empty union is same as carindality of set";
    is $r->sunionstore('destset', 'set', 'anotherset', 'otherset'), @members + 3, "sunion returns cardinality of union";
}

done_testing();

