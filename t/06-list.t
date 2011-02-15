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
    LPOP
    LPUSH
    LPUSHX
    LRANGE
    LREM
    LSET
    LTRIM
    RPOP
    RPOPLPUSH
    RPUSH
    RPUSHX
=cut

my $r = Test::Mock::Redis->new;

diag('TODO');
ok(1, 'placeholder to keep Test::More happy');

done_testing();
