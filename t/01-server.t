#!perl -T

use strict;
use warnings;
use Test::More;
use Test::Mock::Redis;


=pod
x   AUTH  
x   ECHO
x   PING
x   QUIT
o   SELECT  <-- TODO: complain about invalid values?

    BGREWRITEAOF
    BGSAVE
    CONFIG GET
    CONFIG RESETSTAT
    CONFIG SET
    DBSIZE
    DEBUG OBJECT
    DEBUG SEGFAULT
x   FLUSHALL
x   FLUSHDB
o   INFO
x   LASTSAVE
    MONITOR
x   SAVE
    SHUTDOWN
    SLAVEOF
    SYNC
=cut

my $r = Test::Mock::Redis->new;

ok($r->ping, 'ping returns PONG');
ok($r->select($_), "select returns true for $_") for 0..15;

$r->select(0);

# TODO: do we care?
eval{ $r->auth };
like($@, qr/^\Q[auth] ERR wrong number of arguments for 'auth' command\E/, 'auth without a password dies');

ok($r->auth('foo'), 'auth with anything else returns true');


for(0..15){
    $r->select($_);
    $r->set('foo', "foobar $_");
    is($r->get('foo'), "foobar $_");
}

ok($r->flushall);

for(0..15){
    $r->select($_);
    ok(! $r->exists('foo'), "foo flushed from db$_");
}

for my $flush_db (0..15){
    for(0..15){
        $r->select($_);
        $r->set('foo', "foobar $_");
        is($r->get('foo'), "foobar $_");
    }

    $r->select($flush_db);
    $r->flushdb;

    ok(! $r->exists('foo'), "foo flushed from db$flush_db");

    for(0..15){
        next if $_ == $flush_db;
        $r->select($_);
        ok($r->exists('foo'), "foo not flushed from db$_");
    }
}

$r->select(0);  # go back to db0

like($r->lastsave, qr/^\d+$/, 'lastsave returns digits');

ok($r->save, 'save returns true');
like($r->lastsave, qr/^\d+$/, 'lastsave returns digits');

{
    my $info = $r->info;
    is(ref $info, 'HASH', 'info returned a hash');

    #use Data::Dumper; diag Dumper $info;

    like($info->{last_save_time}, qr/^\d+$/, 'last save time is some digits');

    for(0..14){
        is($info->{"db$_"}, 'keys=1,expires=0', "db$_ info is correct");
    }
    # db15 was left with nothing in it, since it was the last one flushed
    is($info->{"db15"}, undef, 'info returns no data about databases with no keys');
}

$r->setex("volitile-key-$_", 'some value', 15) for (1..5);

{
    my $info = $r->info;
    is($info->{'db0'}, 'keys=6,expires=5', 'db0 info now has six keys and five expire');
}



ok($r->quit, 'quit returns true');
ok($r->quit, '...even if we call it again');

ok(! $r->ping, 'ping returns false after we quit');

{
    my $r = Test::Mock::Redis->new;

    ok($r->ping, 'we can ping our new mock redis client');

    $r->shutdown;  # doesn't return anything

    ok(! $r->ping, 'ping returns false after we shutdown');
}


done_testing();


