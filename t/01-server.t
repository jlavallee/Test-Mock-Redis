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
    FLUSHALL
    FLUSHDB
    INFO
    LASTSAVE
    MONITOR
    SAVE
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

ok($r->quit, 'quit returns true');
ok($r->quit, '...even if we call it again');

ok(! $r->ping, 'ping returns false after we quit');

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


done_testing();


