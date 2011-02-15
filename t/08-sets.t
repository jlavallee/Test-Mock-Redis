#!perl -T

use strict;
use warnings;
use Test::More;
use Test::Mock::Redis;

=pod
    SADD
    SCARD
    SDIFF
    SDIFFSTORE
    SINTER
    SINTERSTORE
    SISMEMBER
    SMEMBERS
    SMOVE
    SPOP
    SRANDMEMBER
    SREM
    SUNION
    SUNIONSTORE
=cut

my $r = Test::Mock::Redis->new;

diag('TODO');
ok(1, 'placeholder to keep Test::More happy');

done_testing();

