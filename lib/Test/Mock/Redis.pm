package Test::Mock::Redis;

use warnings;
use strict;

use Carp;
use Config;
use Scalar::Util qw/blessed/;

=head1 NAME

Test::Mock::Redis - use in place of Redis for unit testing

=head1 VERSION

Version 0.04

=cut

our $VERSION = '0.04';

=head1 SYNOPSIS

Test::Mock::Redis can be used in place of Redis for running
tests without needing a running redis instance.

    use Test::Mock::Redis;

    my $redis = Test::Mock::Redis->new(server => 'whatever');

    $redis->set($key, 'some value');

    $redis->get($key);

    ...

This module is designed to function as a drop in replacement for
Redis.pm for testing purposes.

See perldoc Redis and the redis documentation at L<http://redis.io>
    

=head1 SUBROUTINES/METHODS

=head2 new

    Create a new Test::Mock::Redis object. 

    It can be used in place of a Redis object for unit testing.

    If you pass the server to "connect" to, it will be ignored.

=cut

sub _new_db {
    tie my %hash, 'Test::Mock::Redis::PossiblyVolitile'; 
    return \%hash;
}

my $NUM_DBS = 16;

sub _defaults {
    return (
        _quit      => 0,
        _shutdown  => 0,
        _stash     => [ map { _new_db } (1..$NUM_DBS) ],
        _db_index  => 0,
        _up_since  => time,
        _last_save => time,
    );
}


my $instances;

sub new {
    my $class = shift;
    my %args = @_;

    my $server = defined $args{server}
               ? $args{'server'}
               : 'localhost:6379';

    if( $instances->{$server} ){
        confess "Could not connect to Redis server at $server" if $instances->{$server}->{_shutdown};
        $instances->{$server}->{_quit} = 0;
        return $instances->{$server};
    }

    my $self = bless {$class->_defaults, server => $server}, $class;

    $instances->{$server} = $self;

    return $self;
}

sub ping {
    my $self = shift;

    return !$self->{_shutdown}
        && !$self->{_quit};
}

sub auth {
    my $self = shift;

    confess '[auth] ERR wrong number of arguments for \'auth\' command' unless @_;

    return 1;
}

sub quit {
    my $self = shift;

    confess "Not connected to any server" if $self->{_quit};
    $self->{_quit} = 1;
}

sub shutdown {
    my $self = shift;

    $self->{_shutdown} = 1;
}

sub set {
    my ( $self, $key, $value ) = @_;

    $self->_stash->{$key} = "$value";
    return 1;
}

sub setnx {
    my ( $self, $key, $value ) = @_;

    return 0 if $self->exists($key);

    $self->_stash->{$key} = "$value";

    return 1;
}

sub setex {
    my ( $self, $key, $ttl, $value ) = @_;
    $self->set($key, $value);
    $self->expire($key, $ttl);
    return 1;
}

sub expire {
    my ( $self, $key, $ttl ) = @_;

    return $self->expireat($key, time + $ttl);
}

sub expireat {
    my ( $self, $key, $when ) = @_;

    return 0 unless exists $self->_stash->{$key};

    my $slot = $self->_stash;
    my $tied = tied(%$slot);

    $tied->expire($key, $when);

    return 1;
}

sub persist {
    my ( $self, $key, $ttl ) = @_;

    return 0 unless exists $self->_stash->{$key};

    my $slot = $self->_stash;
    my $tied = tied(%$slot);

    $tied->persist($key);

    return 1;
}

sub ttl {
    my ( $self, $key, $ttl ) = @_;

    return -1 unless exists $self->_stash->{$key};

    my $slot = $self->_stash;
    my $tied = tied(%$slot);

    return $tied->ttl($key);
}

sub exists {
    my ( $self, $key ) = @_;
    return exists $self->_stash->{$key};
}

sub get {
    my ( $self, $key  ) = @_;

    return $self->_stash->{$key};
}

sub append {
    my ( $self, $key, $value ) = @_;

    $self->_stash->{$key} .= $value;

    return $self->strlen($key);
}

sub strlen {
    my ( $self, $key ) = @_;
    return do { use bytes; length $self->_stash->{$key}; };
}

sub getset {
    my ( $self, $key, $value ) = @_;

    #TODO: should return error when original value isn't a string
    my $old_value = $self->_stash->{$key};

    $self->set($key, $value);

    return $old_value;
}

sub incr {
    my ( $self, $key  ) = @_;

    $self->_stash->{$key} ||= 0;

    return ++$self->_stash->{$key};
}

sub incrby {
    my ( $self, $key, $incr ) = @_;

    $self->_stash->{$key} ||= 0;

    return $self->_stash->{$key} += $incr;
}

sub decr {
    my ( $self, $key ) = @_;

    return --$self->_stash->{$key};
}

sub decrby {
    my ( $self, $key, $decr ) = @_;

    $self->_stash->{$key} ||= 0;

    return $self->_stash->{$key} -= $decr;
}

sub mget {
    my ( $self, @keys ) = @_;

    return map { $self->_stash->{$_} } @keys;
}

sub mset {
    my ( $self, %things ) = @_;

    @{ $self->_stash }{keys %things} = (values %things);

    return 1;
}

sub msetnx {
    my ( $self, %things ) = @_;

    $self->exists($_) && return 0 for keys %things;

    @{ $self->_stash }{keys %things} = (values %things);

    return 1;
}

sub del {
    my ( $self, $key ) = @_;

    my $ret = $self->exists($key);

    delete $self->_stash->{$key};

    return $ret;
}

sub type {
    my ( $self, $key ) = @_;
    # types are string, list, set, zset and hash

    return undef unless $self->exists($key);

    my $type = ref $self->_stash->{$key};

    return !$type 
         ? 'string'
         : $type eq 'Test::Mock::Redis::Hash' 
           ? 'hash'
           : $type eq 'Test::Mock::Redis::Set'
             ? 'set'
             : $type eq 'Test::Mock::Redis::ZSet'
               ? 'zset'
                 : $type eq 'Test::Mock::Redis::List' 
                   ? 'list'
                   : 'unknown'
    ;
}

sub keys :method {
    my ( $self, $match ) = @_;

    # TODO: we're not escaping other meta-characters
    $match =~ s/(?<!\\)\*/.*/g;
    $match =~ s/(?<!\\)\?/.?/g;

    return @{[ sort { $a cmp $b } grep { /$match/ } keys %{ $self->_stash }]};
}

sub randomkey {
    my $self = shift;

    return ( keys %{ $self->_stash } )[
                int(rand( scalar keys %{ $self->_stash } ))
            ]
    ;
}

sub rename {
    my ( $self, $from, $to, $whine ) = @_;

    confess '[rename] ERR source and destination objects are the same' if $from eq $to;
    confess '[rename] ERR no such key' unless $self->exists($from);
    confess 'rename to existing key' if $whine && $self->_stash->{$to};

    $self->_stash->{$to} = $self->_stash->{$from};
    return 1;
}

sub renamenx {
    my ( $self, $from, $to ) = @_;

    return 0 if $self->exists($to);
    return $self->rename($from, $to);
}

sub dbsize {
    my $self = shift;

    return scalar keys %{ $self->_stash };
}

sub rpush {
    my ( $self, $key, $value ) = @_;

    $self->_make_list($key);

    return push @{ $self->_stash->{$key} }, "$value";
}

sub lpush {
    my ( $self, $key, $value ) = @_;

    croak "[lpush] ERR Operation against a key holding the wrong kind of value"
        unless !$self->exists($key) or $self->_is_list($key);

    $self->_make_list($key);

    return unshift @{ $self->_stash->{$key} }, "$value";
}

sub rpushx {
    my ( $self, $key, $value ) = @_;

    return unless $self->_is_list($key);

    return push @{ $self->_stash->{$key} }, "$value";
}

sub lpushx {
    my ( $self, $key, $value ) = @_;

    return unless $self->_is_list($key);

    return unshift @{ $self->_stash->{$key} }, "$value";
}

sub llen {
    my ( $self, $key ) = @_;

    return 0 unless $self->exists($key);

    return scalar @{ $self->_stash->{$key} };
}

sub lrange {
    my ( $self, $key, $start, $end ) = @_;

    return @{ $self->_stash->{$key} }[$start..$end];
}

sub ltrim {
    my ( $self, $key, $start, $end ) = @_;

    $self->_stash->{$key} = [ @{ $self->_stash->{$key} }[$start..$end] ]; 
    return 1;
}

sub lindex {
    my ( $self, $key, $index ) = @_;

    return $self->_stash->{$key}->[$index];
}

sub lset {
    my ( $self, $key, $index, $value ) = @_;

    $self->_stash->{$key}->[$index] = "$value";
    return 1;
}

sub lrem {
    my ( $self, $key, $count, $value ) = @_;
    my $removed;
    my @indicies = $count < 0
                 ? ($#{ $self->_stash->{$key} }..0)
                 : (0..$#{ $self->_stash->{$key} })
    ;
    $count = abs $count;

    for my $index (@indicies){
        if($self->_stash->{$key}->[$index] eq $value){
            splice @{ $self->_stash->{$key} }, $index, 1;
            last if $count && ++$removed >= $count;
        }
    }
    
    return $removed;
}

sub lpop {
    my ( $self, $key ) = @_;

    return undef unless $self->exists($key);

    return shift @{ $self->_stash->{$key} };
}

sub rpop {
    my ( $self, $key ) = @_;

    return undef unless $self->exists($key);

    return pop @{ $self->_stash->{$key} };
}

sub select {
    my ( $self, $index ) = @_;

    $self->{_db_index} = $index;
    return 1;
}

sub _stash {
    my ( $self, $index ) = @_;
    $index = $self->{_db_index} unless defined $index;

    return $self->{_stash}->[$index];
}

sub sadd {
    my ( $self, $key, $value ) = @_;

    $self->_make_set($key);
    my $return = exists $self->_stash->{$key}->{$value}
               ? 0
               : 1;
    $self->_stash->{$key}->{$value} = 1;
    return $return;
}

sub scard {
    my ( $self, $key ) = @_;

    return scalar $self->smembers($key);
}

sub sismember {
    my ( $self, $key, $value ) = @_;

    return exists $self->_stash->{$key}->{$value}
            ? 1 
            : 0;
}

sub srem {
    my ( $self, $key, $value ) = @_;

    my $ret = exists $self->_stash->{$key}->{$value}
            ? 1 
            : 0;
    delete $self->_stash->{$key}->{$value};
    return $ret;
}

sub spop {
    my ( $self, $key ) = @_;

    return undef unless $self->_is_set($key);

    my $value = $self->srandmember($key);
    delete $self->_stash->{$key}->{$value};
    return $value;
}

sub smove {
    my ( $self, $source, $dest, $value ) = @_;

    return 0 unless $self->_is_set($source)
                 && $self->_is_set($dest)
                 && $self->sismember($source, $value);

    $self->_stash->{$dest}->{ delete $self->_stash->{$source}->{$value} } = 1;
    return 1;
}

sub srandmember {
    my ( $self, $key ) = @_;

    return undef unless $self->_is_set($key);

    return ($self->smembers($key))[rand int $self->scard($key)];
}

sub smembers {
    my ( $self, $key ) = @_;

    return keys %{ $self->_stash->{$key} };
}

sub sinter {
    my ( $self, @keys ) = @_;

    my $r = {};

    foreach my $key (@keys){
        $r->{$_}++ for keys %{ $self->_stash->{$key} };
    }

    return grep { $r->{$_} >= @keys } keys %$r;
}

sub sinterstore {
    my ( $self, $dest, @keys ) = @_;

    $self->_stash->{$dest} = { map { $_ => 1 } $self->sinter(@keys) };
    bless $self->_stash->{$dest}, 'Test::Mock::Redis::Set';
    return $self->scard($dest);
}

sub sunion {
    my ( $self, @keys ) = @_;

    my $r = {};

    foreach my $key (@keys){
        $r->{$_}++ for keys %{ $self->_stash->{$key} };
    }

    return grep { $r->{$_} >= 1 } keys %$r;
}

sub sunionstore {
    my ( $self, $dest, @keys ) = @_;

    $self->_stash->{$dest} = { map { $_ => 1 } $self->sunion(@keys) };
    bless $self->_stash->{$dest}, 'Test::Mock::Redis::Set';
    return $self->scard($dest);
}

sub hset {
    my ( $self, $key, $hkey, $value ) = @_;

    croak "[hset] ERR Operation against a key holding the wrong kind of value"
        unless !$self->exists($key) or $self->_is_hash($key);

    $self->_make_hash($key);

    my $ret = exists $self->_stash->{$key}->{$hkey}
            ? 0
            : 1;
    $self->_stash->{$key}->{$hkey} = $value;
    return $ret;
}

sub hsetnx {
    my ( $self, $key, $hkey, $value ) = @_;

    return 0 if exists $self->_stash->{$key}->{$hkey};

    $self->_make_hash($key);

    $self->_stash->{$key}->{$hkey} = "$value";
    return 1;
}

sub hmset {
    my ( $self, $key, %hash ) = @_;

    $self->_make_hash($key);

    foreach my $hkey ( keys %hash ){
        $self->hset($key, $hkey, $hash{$hkey});
    }

    return 1;
}

sub hget {
    my ( $self, $key, $hkey ) = @_;

    return undef unless $self->_is_hash($key);

    return $self->_stash->{$key}->{$hkey};
}

sub hmget {
    my ( $self, $key, @hkeys ) = @_;

    return undef unless $self->_is_hash($key);

    return map { $self->_stash->{$key}->{$_} } @hkeys;
}

sub hexists {
    my ( $self, $key, $hkey ) = @_;

    confess '[hexists] ERR Operation against a key holding the wrong kind of value'
         if $self->exists($key) and !$self->_is_hash($key);

    return exists $self->_stash->{$key}->{$hkey};
}

sub hdel {
    my ( $self, $key, $hkey ) = @_;

    return 0 unless $self->_is_hash($key);

    my $ret = $self->hexists($key, $hkey);
    delete $self->_stash->{$key}->{$hkey};
    return $ret;
}

sub hincrby {
    my ( $self, $key, $hkey, $incr ) = @_;

    $self->_stash->{$key}->{$hkey} ||= 0;

    return $self->_stash->{$key}->{$hkey} += $incr;
}

sub hlen {
    my ( $self, $key ) = @_;

    return 0 unless $self->_is_hash($key);

    return scalar values %{ $self->_stash->{$key} };
}

sub hkeys {
    my ( $self, $key ) = @_;

    return () unless $self->_is_hash($key);

    return keys %{ $self->_stash->{$key} };
}

sub hvals {
    my ( $self, $key ) = @_;

    return CORE::values %{ $self->_stash->{$key} };
}

sub hgetall {
    my ( $self, $key ) = @_;

    return %{ $self->_stash->{$key} };
}

sub move {
    my ( $self, $key, $to ) = @_;

    return 0 unless !exists $self->_stash($to)->{$key}
                 &&  exists $self->_stash->{$key}
    ;

    $self->_stash($to)->{$key} = $self->_stash->{$key};
    delete $self->_stash->{$key};
    return 1;
}

sub flushdb {
    my $self = shift;

    $self->{_stash}->[$self->{_db_index}] = _new_db;
}

sub flushall {
    my $self = shift;

    $self->{_stash} = [ map { _new_db }(1..$NUM_DBS) ];
}

sub sort {
    my ( $self, $key, $how ) = @_;

    my $cmp = do
    { no warnings 'uninitialized';
      $how =~ /\bALPHA\b/ 
      ? $how =~ /\bDESC\b/
        ? sub { $b cmp $a }
        : sub { $a cmp $b }
      : $how =~ /\bDESC\b/
        ? sub { $b <=> $a }
        : sub { $a <=> $b }
      ;
    };

    return sort $cmp @{ $self->_stash->{$key} };
}

sub save { 
    my $self = shift;
    $self->{_last_save} = time;
    return 1;
}

sub bgsave { 
    my $self = shift;
    return $self->save;
}

sub lastsave { 
    my $self = shift;
    return $self->{_last_save};
}

sub info {
    my $self = shift;

    return {
        arch_bits                  => $Config{use64bitint } ? '64' : '32',
        bgrewriteaof_in_progress   => '0',
        bgsave_in_progress         => '0',
        blocked_clients            => '0',
        changes_since_last_save    => '0',
        connected_clients          => '1',
        connected_slaves           => '0',
        expired_keys               => '0',
        hash_max_zipmap_entries    => '64',
        hash_max_zipmap_value      => '512',
        last_save_time             => $self->{_last_save},
        mem_fragmentation_ratio    => '0.11',
        multiplexing_api           => 'kqueue',
        process_id                 => $$,
        pubsub_channels            => '0',
        pubsub_patterns            => '0',
        redis_git_dirty            => '0',
        redis_git_sha1             => 'da14590b',
        redis_version              => '2.1.4',
        role                       => 'master',
        total_commands_processed   => '84',
        total_connections_received => '14',
        uptime_in_days             => (time - $self->{_up_since}) / 60 / 60 / 24,
        uptime_in_seconds          => time - $self->{_up_since},
        used_memory                => '3918288',
        used_memory_human          => '3.74M',
        vm_enabled                 => '0',
        map { 'db'.$_ => sprintf('keys=%d,expires=%d',
                             scalar keys %{ $self->_stash($_) },
                             $self->_expires_count_for_db($_),
                         )
            } grep { scalar keys %{ $self->_stash($_) } > 0 }
                (0..15)
    };
}

sub _expires_count_for_db {
    my ( $self, $db_index ) = @_;

    my $slot = $self->_stash($db_index);
    my $tied = tied(%$slot);

    $tied->expire_count;
}

sub zadd {
    my ( $self, $key, $score, $value ) = @_;

    $self->_make_zset($key);

    my $ret = exists $self->_stash->{$key}->{$value}
            ? 0
            : 1;
    $self->_stash->{$key}->{$value} = $score;
    return $ret;
}


sub zscore {
    my ( $self, $key, $value ) = @_;
    return $self->_stash->{$key}->{$value};
}

sub zincrby {
    my ( $self, $key, $score, $value ) = @_;

    $self->_stash->{$key}->{$value} ||= 0;

    return $self->_stash->{$key}->{$value} += $score;
}

sub zrank {
    my ( $self, $key, $value ) = @_;
    my $rank = 0;
    foreach my $elem ( $self->zrange($key, 0, $self->zcard($key)) ){
        return $rank if $value eq $elem;
        $rank++;
    }
    return undef;
}

sub zrevrank {
    my ( $self, $key, $value ) = @_;
    my $rank = 0;
    foreach my $elem ( $self->zrevrange($key, 0, $self->zcard($key)) ){
        return $rank if $value eq $elem;
        $rank++;
    }
    return undef;
}

sub zrange {
    my ( $self, $key, $start, $stop, $withscores ) = @_;

    $stop = $self->zcard($key)-1 if $stop >= $self->zcard($key);
    
    return map { $withscores ? ( $_, $self->zscore($key, $_) ) : $_ } 
               ( map { $_->[0] }
                     sort { $a->[1] <=> $b->[1] }
                         map { [ $_, $self->_stash->{$key}->{$_} ] }
                             keys %{ $self->_stash->{$key} } 
               )[$start..$stop]
    ;
}

sub zrevrange {
    my ( $self, $key, $start, $stop, $withscores ) = @_;

    $stop = $self->zcard($key)-1 if $stop >= $self->zcard($key);

    return map { $withscores ? ( $_, $self->zscore($key, $_) ) : $_ } 
               ( map { $_->[0] }
                     sort { $b->[1] <=> $a->[1] }
                         map { [ $_, $self->_stash->{$key}->{$_} ] }
                             keys %{ $self->_stash->{$key} } 
               )[$start..$stop]
    ;
}

sub zrangebyscore {
    my ( $self, $key, $min, $max, $withscores ) = @_;

    my $min_inc = !( $min =~ s/^\(// );
    my $max_inc = !( $max =~ s/^\(// );

    my $cmp = !$min_inc && !$max_inc
            ? sub { $self->zscore($key, $_[0]) > $min && $self->zscore($key, $_[0]) < $max }
            : !$min_inc 
              ? sub { $self->zscore($key, $_[0]) > $min && $self->zscore($key, $_[0]) <= $max }
              : !$max_inc 
                ? sub { $self->zscore($key, $_[0]) >= $min && $self->zscore($key, $_[0]) <  $max }
                : sub { $self->zscore($key, $_[0]) >= $min && $self->zscore($key, $_[0]) <= $max }
    ;
            
    return map { $withscores ? ( $_, $self->zscore($key, $_) ) : $_ } 
               grep { $cmp->($_) } $self->zrange($key, 0, $self->zcard($key)-1);
                   $self->zrange($key, 0, $self->zcard($key)-1);
}

sub zcount {
    my ( $self, $key, $min, $max ) = @_;
    return scalar $self->zrangebyscore($key, $min, $max);
}

sub zcard {
    my ( $self, $key ) = @_;
    return scalar values %{ $self->_stash->{$key} }
}

sub zremrangebyrank {
    my ( $self, $key, $start, $stop ) = @_;

    my @remove = $self->zrange($key, $start, $stop);
    delete $self->_stash->{$key}->{$_} for @remove;
    return scalar @remove;
}

sub zremrangebyscore {
    my ( $self, $key, $start, $stop ) = @_;

    my @remove = $self->zrangebyscore($key, $start, $stop);
    delete $self->_stash->{$key}->{$_} for @remove;
    return scalar @remove;
}


=head1 TODO

Lots!

Not all Redis functionality is implemented.  The test files that output "TODO" are still to be done.

The top of all test files [except 01-basic.t] has the list of commands tested or to-be tested in the file.

Those marked with an "x" are pretty well-tested.
Those marked with an "o" need help.
Those that are unmarked have no tests, or are un-implemented.  For example:

x   AUTH          <--- has some tests

o   KEYS          <--- only partially tested and/or implemented

    ZINTERSTORE   <--- not tested (or maybe not implemented)



Beyond that, it would be neat to add methods to inspect how often keys were accessed and get other information that
allows the module user to confirm that their code interacted with redis (or Test::Mock::Redis) as they expected.


=head1 AUTHOR

Jeff Lavallee, C<< <jeff at zeroclue.com> >>

=head1 SEE ALSO

The real Redis.pm client whose interface this module mimics: L<http://search.cpan.org/dist/Redis>


=head1 BUGS

Please report any bugs or feature requests to C<bug-mock-redis at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Mock-Redis>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Mock::Redis


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Mock-Redis>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Mock-Redis>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Mock-Redis>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Mock-Redis/>

=back


=head1 ACKNOWLEDGEMENTS

Salvatore Sanfilippo for redis, of course!

Dobrica Pavlinusic & Pedro Melo for Redis.pm

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Jeff Lavallee.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut


sub _is_list {
    my ( $self, $key ) = @_;

    return $self->exists($key)
        && blessed $self->_stash->{$key}
        && $self->_stash->{$key}->isa('Test::Mock::Redis::List') ;
}

sub _make_list {
    my ( $self, $key ) = @_;

    $self->_stash->{$key} = Test::Mock::Redis::List->new
        unless $self->_is_list($key);
}

sub _is_hash {
    my ( $self, $key ) = @_;

    return $self->exists($key)
        && blessed $self->_stash->{$key}
        && $self->_stash->{$key}->isa('Test::Mock::Redis::Hash') ;
}

sub _make_hash {
    my ( $self, $key ) = @_;

    $self->_stash->{$key} = Test::Mock::Redis::Hash->new
        unless $self->_is_hash($key);
}

sub _is_set {
    my ( $self, $key ) = @_;

    return $self->exists($key)
        && blessed $self->_stash->{$key}
        && $self->_stash->{$key}->isa('Test::Mock::Redis::Set') ;
}

sub _make_set {
    my ( $self, $key ) = @_;

    $self->_stash->{$key} = Test::Mock::Redis::Set->new
        unless $self->_is_set($key);
}

sub _is_zset {
    my ( $self, $key ) = @_;

    return $self->exists($key)
        && blessed $self->_stash->{$key}
        && $self->_stash->{$key}->isa('Test::Mock::Redis::ZSet') ;
}

sub _make_zset {
    my ( $self, $key ) = @_;

    $self->_stash->{$key} = Test::Mock::Redis::ZSet->new
        unless $self->_is_zset($key);
}



1; # End of Test::Mock::Redis

package Test::Mock::Redis::List;
sub new { return bless [], shift }
1;

package Test::Mock::Redis::Hash;
sub new { return bless {}, shift }
1;

package Test::Mock::Redis::ZSet;
sub new { return bless {}, shift }
1;

package Test::Mock::Redis::Set;
sub new { return bless {}, shift }
1;

package Test::Mock::Redis::PossiblyVolitile;

use strict; use warnings;
use Tie::Hash;
use base qw/Tie::StdHash/;

sub DELETE { 
    my ( $self, $key ) = @_;

    delete $self->{$key};
}

my $expires;

sub FETCH {
    my ( $self, $key ) = @_;

    return $self->EXISTS($key)
         ? $self->{$key}
         : undef;
}

sub EXISTS {
    my ( $self, $key ) = @_;

    $self->_delete_if_expired($key);

    return exists $self->{$key};
}

sub _delete_if_expired {
    my ( $self, $key ) = @_;
    if(exists $expires->{$self}->{$key}
       && time >= $expires->{$self}->{$key}){
        delete $self->{$key};
        delete $expires->{$self}->{$key};
    }
}

sub expire {
    my ( $self, $key, $time ) = @_;

    $expires->{$self}->{$key} = $time;
}

sub expire_count {
    my ( $self ) = @_;

    # really, we should probably only count keys that haven't expired
    scalar keys %{ $expires->{$self} };
}

sub persist {
    my ( $self, $key, $time ) = @_;

    delete $expires->{$self}->{$key};
}

sub ttl {
    my ( $self, $key ) = @_;

    return -1 unless exists $expires->{$self}->{$key};
    return $expires->{$self}->{$key} - time;
}


1;

