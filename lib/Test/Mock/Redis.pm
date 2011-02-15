package Test::Mock::Redis;

use warnings;
use strict;

use Config;
use Scalar::Util qw/blessed/;

=head1 NAME

Test::Mock::Redis - use in place of Redis for unit testing

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

Test::Mock::Redis can be used in place of Redis for running
tests without needing a running redis instance.

    use Test::Mock::Redis;

    my $redis = Test::Mock::Redis->new(server => 'whatever');
    ...

    $redis->set($key, 'some value');

    $redis->get($key);

This module is designed to function as a drop in replacement for
Redis.pm for testing purposes.

See perldoc Redis and the redis documentation at L<http://redis.io>
    

=head1 SUBROUTINES/METHODS

=head2 new

    Create a new Test::Mock::Redis object. 

    It can be used in place of a Redis object for unit testing.

    If you pass the server to "connect" to, it will be ignored.

=cut

our %defaults = (
    _quit     => 0,
    _stash    => [ map { tie %$_, 'Test::Mock::Redis::PossiblyVolitile'; $_ }
                       map { {} } (1..16)
                 ],
    _db_index => 0,
    _up_since => time,
);

sub new {
    my $class = shift;
    my %args = @_;

    my $self = bless { %defaults, %args }, $class;
    return $self;
}

sub ping {
    my $self = shift;

    return !$self->{_quit};
}

sub quit {
    my $self = shift;

    $self->{_quit} = 1;
}

sub shutdown {
    my $self = shift;

    $self->{_quit} = 1;
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
    my ( $self, $key, $value, $ttl ) = @_;
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

sub _delete_key_if_expired {
    my ( $self, $key ) = @_;

    delete $self->_stash->{$key}
        if blessed $self->_stash->{$key} 
         && $self->_stash->{$key}->isa('Test::Mock::Redis::Volitile')
         && $self->_stash->{$key}->expired
    ;
    return $self; #chainable
}

sub get {
    my ( $self, $key  ) = @_;

    return $self->_delete_key_if_expired($key)
                ->_stash->{$key};
}

sub append {
    my ( $self, $key, $value ) = @_;

    $self->_stash->{$key} .= $value;

    return $self->strlen($key);
}

sub strlen {
    my ( $self, $key ) = @_;
    # TODO: do we need byte length?
    return length $self->_stash->{$key};
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

    return map { $self->_delete_key_if_expired($_)->_stash->{$_} } @keys;
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

    my $ret = $self->_delete_key_if_expired($key)
                   ->exists($key);

    delete $self->_stash->{$key};

    return $ret;
}

sub type {
    my ( $self, $key ) = @_;
    # types are string, list, set, zset and hash

    return 0 unless $self->exists($key);

    my $type = ref $self->_stash->{$key};

    return !$type 
         ? 'string'
         : $type eq 'Test::Mock::Redis::Set'
           ? 'set'
           : $type eq 'Test::Mock::Redis::ZSet'
             ? 'zset'
             : $type eq 'HASH' 
               ? 'hash'
               : $type eq 'ARRAY' 
                 ? 'list'
                 : 'unknown'
    ;
}

sub keys {
    my ( $self, $match ) = @_;

    # TODO: we're not escaping other meta-characters
    $match =~ s/(?<!\\)\*/.*/g;
    $match =~ s/(?<!\\)\?/.?/g;

    return @{[ sort { $a cmp $b } grep { /$match/ } CORE::keys %{ $self->_stash }]};
}

sub randomkey {
    my $self = shift;

    return ( CORE::keys %{ $self->_stash } )[
                int(rand( scalar CORE::keys %{ $self->_stash } ))
            ]
    ;
}

sub rename {
    my ( $self, $from, $to, $whine ) = @_;

    return 0 unless $self->exists($from);
    return 0 if $from eq $to;
    die "rename to existing key" if $whine && $self->_stash->{$to};

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

    return scalar CORE::keys %{ $self->_stash };
}

sub rpush {
    my ( $self, $key, $value ) = @_;

    $self->_stash->{$key} = []
        unless ref $self->_stash->{$key} eq 'ARRAY';

    return push @{ $self->_stash->{$key} }, "$value";
}

sub lpush {
    my ( $self, $key, $value ) = @_;

    $self->_stash->{$key} = []
        unless ref $self->_stash->{$key} eq 'ARRAY';

    return unshift @{ $self->_stash->{$key} }, "$value";
}

sub llen {
    my ( $self, $key ) = @_;

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

    return shift @{ $self->_stash->{$key} };
}

sub rpop {
    my ( $self, $key ) = @_;

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

    $self->_stash->{$key} = Test::Mock::Redis::Set->new
        unless blessed $self->_stash->{$key} 
            && $self->_stash->{$key}->isa( 'Test::Mock::Redis::Set' );

    my $return = !exists $self->_stash->{$key}->{$value};
    $self->_stash->{$key}->{$value} = 1;
    return $return;
}

sub scard {
    my ( $self, $key ) = @_;

    return scalar CORE::keys %{ $self->_stash->{$key} };
}

sub sismember {
    my ( $self, $key, $value ) = @_;

    return exists $self->_stash->{$key}->{$value};
}

sub srem {
    my ( $self, $key, $value ) = @_;

    my $ret = exists $self->_stash->{$key}->{$value};
    delete $self->_stash->{$key}->{$value};
    return $ret;
}

sub sinter {
    my ( $self, @keys ) = @_;

    my $r = {};

    foreach my $key (@keys){
        $r->{$_}++ for CORE::keys %{ $self->_stash->{$key} };
    }

    return grep { $r->{$_} >= @keys } CORE::keys %$r;
}

sub sinterstore {
    my ( $self, $dest, @keys ) = @_;

    $self->_stash->{$dest} = { map { $_ => 1 } $self->sinter(@keys) };
    bless $self->_stash->{$dest}, 'Test::Mock::Redis::Set';
    return $self->scard($dest);
}

sub hset {
    my ( $self, $key, $hkey, $value ) = @_;

    $self->_stash->{$key} ||= {};

    my $ret = !exists $self->_stash->{$key}->{$hkey};
    $self->_stash->{$key}->{$hkey} = "$value";
    return $ret;
}

sub hsetnx {
    my ( $self, $key, $hkey, $value ) = @_;

    $self->_stash->{$key} ||= {};

    return 0 if exists $self->_stash->{$key}->{$hkey};

    $self->_stash->{$key}->{$hkey} = "$value";
    return 1;
}

sub hmset {
    my ( $self, $key, %hash ) = @_;

    $self->_stash->{$key} ||= {};

    foreach my $hkey ( CORE::keys %hash ){
        $self->hset($key, $hkey, $hash{$hkey});
    }

    return 1;
}

sub hget {
    my ( $self, $key, $hkey ) = @_;

    return $self->_stash->{$key}->{$hkey};
}

sub hmget {
    my ( $self, $key, @hkeys ) = @_;

    return map { $self->_stash->{$key}->{$_} } @hkeys;
}

sub hexists {
    my ( $self, $key, $hkey ) = @_;

    return exists $self->_stash->{$key}->{$hkey};
}

sub hdel {
    my ( $self, $key, $hkey ) = @_;

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

    return scalar values %{ $self->_stash->{$key} };
}

sub hkeys {
    my ( $self, $key ) = @_;

    return CORE::keys %{ $self->_stash->{$key} };
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

    $self->{_stash}->[$self->{_db_index}] = {}
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
                             scalar CORE::keys %{ $self->_stash($_) },
                             0,
                         )
            } grep { scalar CORE::keys %{ $self->_stash($_) } > 0 }
                (0..15)
    };
}

sub zadd {
    my ( $self, $key, $score, $value ) = @_;

    $self->_stash->{$key} ||= {};

    my $ret = !exists $self->_stash->{$key}->{$value};
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
                             CORE::keys %{ $self->_stash->{$key} } 
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
                             CORE::keys %{ $self->_stash->{$key} } 
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

Not all Redis functionality is implemented.  Pull requests welcome!

Add methods to inspect how often keys were accessed

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

1; # End of Test::Mock::Redis

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

    $self->_delete_if_expired($key);

    return $self->{$key};
}

sub EXISTS {
    my ( $self, $key ) = @_;

    $self->_delete_if_expired($key);

    return exists $self->{$key};
}

sub _delete_if_expired {
    my ( $self, $key ) = @_;
    if(exists $expires->{$self->_expires_key($key)}
       && time >= $expires->{$self->_expires_key($key)}){
        delete $self->{$key};
        delete $expires->{$self->_expires_key($key)};
    }
}

sub expire {
    my ( $self, $key, $time ) = @_;

    $expires->{$self->_expires_key($key)} = $time;
}

sub persist {
    my ( $self, $key, $time ) = @_;

    delete $expires->{$self->_expires_key($key)};
}

sub ttl {
    my ( $self, $key ) = @_;

    return -1 unless exists $expires->{$self->_expires_key($key)};
    return $expires->{$self->_expires_key($key)} - time;
}

sub _expires_key {
    my ( $self, $key ) = @_;
    return sprintf('__%s__%s', ref $self, $key);
}


1;

