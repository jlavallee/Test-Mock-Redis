use strict;
use warnings FATAL => 'all';

use Test::More 0.88;
use Test::Deep;
use Test::Fatal;
use Test::Mock::Redis;

=pod
x   MULTI
x   EXEC
x   DISCARD
=cut

my $redis = Test::Mock::Redis->new;

{
    like(
        exception { $redis->exec },
        qr/^\[exec\] ERR EXEC without MULTI/,
        'cannot call EXEC before MULTI',
    );

    like(
        exception { $redis->discard },
        qr/^\[discard\] ERR DISCARD without MULTI/,
        'cannot call DISCARD before MULTI',
    );

    like(
        exception { $redis->multi; $redis->multi },
        qr/^\[multi\] ERR MULTI calls cannot be nested/,
        'cannot call MULTI again until EXEC or DISCARD is called',
    );

    is($redis->discard, 'OK', 'multi state has been reset');


    # discarded transactions

    is($redis->multi, 'OK', 'multi transaction started');
    is($redis->hmset('transaction_key_1', qw(a 1 b 2)), 'QUEUED', 'hmset operation recorded');
    is($redis->hset('transaction_key_2', 'ohhai'), 'QUEUED', 'hset operation recorded');

    cmp_deeply(
        $redis->discard,
        'OK',
        'transaction discarded',
    );

    cmp_deeply(
        { $redis->hgetall('transaction_key_1') },
        { },
        'data was not altered',
    );


    # successful transactions

    is($redis->multi, 'OK', 'multi transaction started');
    is($redis->hmset('transaction_key_3', qw(a 1 b 2)), 'QUEUED', 'hmset operation recorded');
    is($redis->keys('transaction_key_*'), 'QUEUED', 'keys operation recorded');
    is($redis->set('transaction_key_4', 'ohhai'), 'QUEUED', 'set operation recorded');
    is($redis->keys('transaction_key_*'), 'QUEUED', 'keys operation recorded');

    cmp_deeply(
        [ $redis->exec ],
        [
            'OK',
            [ 'transaction_key_3' ],    # transaction_key_4 hasn't been set yet
            'OK',
            [ qw(transaction_key_3 transaction_key_4) ],
        ],
        'transaction finished, returning the results of all queries',
    );

    cmp_deeply(
        { $redis->hgetall('transaction_key_3') },
        {
            a => '1',
            b => '2',
        },
        'hash data successfully recorded',
    );


    # an error in replaying a transaction should not abort subsequent commands
    # note: this mirrors behaviour in version 2.6.5+

    is($redis->multi, 'OK', 'multi transaction started');
    is($redis->set('transaction_key_1', 'foo'), 'QUEUED', 'set operation recorded');
    is($redis->hset('transaction_key_1', 'bar', '9'), 'QUEUED', 'hset operation recorded');
    is($redis->hset('transaction_key_3', 'a', '9'), 'QUEUED', 'hset operation recorded');

    like(
        exception { $redis->exec },
        qr/^\[exec\] ERR Operation against a key holding the wrong kind of value/,
        'a bad transaction results in an exception',
    );

    is($redis->get('transaction_key_1'), 'foo', 'the first command was executed');

    cmp_deeply(
        { $redis->hgetall('transaction_key_3') },
        {
            a => '9',
            b => '2',
        },
        'commands after the error were still executed',
    );
}


done_testing;
