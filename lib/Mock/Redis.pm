package Mock::Redis;

use warnings;
use strict;

use Scalar::Util qw/blessed/;
use Set::Scalar;

=head1 NAME

Mock::Redis - use in place of Redis for unit testing

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Mock::Redis;

    my $redis = Mock::Redis->new(server => 'whatever');
    ...
    

=head1 SUBROUTINES/METHODS

=head2 new

    Create a new Mock::Redis object. 

    It can be used in place of a Redis object for unit testing.

=cut

our %defaults = (
    _quit     => 0,
    _stash    => [ map { {} } (1..16) ],
    _db_index => 0,
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

    unless($self->exists($key)){
        $self->_stash->{$key} = "$value";
        return 1;
    }
    return 0;
}

sub exists {
    my ( $self, $key ) = @_;
    return exists $self->_stash->{$key};
}

sub get {
    my ( $self, $key  ) = @_;

    return $self->_stash->{$key};
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

    return $self->_stash->{$key} -= $decr;
}

sub mget {
    my ( $self, @keys ) = @_;

    return map { $self->_stash->{$_} } @keys;
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

    return 0 unless $self->exists($key);

    my $type = ref $self->_stash->{$key};

    return !$type 
         ? 'string'
         : $type eq 'Set::Scalar'
           ? 'set'
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
}

sub _stash {
    my ( $self, $index ) = @_;
    $index = $self->{_db_index} unless defined $index;

    return $self->{_stash}->[$index];
}

sub sadd {
    my ( $self, $key, $value ) = @_;

    $self->_stash->{$key} = Set::Scalar->new
        unless blessed $self->_stash->{$key} 
            && $self->_stash->{$key}->isa( 'Set::Scalar' );

    my $return = !$self->_stash->{$key}->member("$value");
    $self->_stash->{$key}->insert("$value");
    return $return;
}

sub scard {
    my ( $self, $key ) = @_;

    return scalar $self->_stash->{$key}->members;
}

sub sismember {
    my ( $self, $key, $value ) = @_;

    return $self->_stash->{$key}->member("$value");
}

sub srem {
    my ( $self, $key, $value ) = @_;

    my $return = $self->_stash->{$key}->member("$value");
    $self->_stash->{$key}->delete("$value");
    return $return;
}

sub sinter {
    my ( $self, $key, @keys ) = @_;

    my $r = $self->_stash->{$key};
    $r = $r->intersection($self->_stash->{$_})
        for @keys;

    return reverse $r->members;
}

sub sinterstore {
    my ( $self, $dest, @keys ) = @_;

    $self->_stash->{$dest} = Set::Scalar->new;
    $self->_stash->{$dest}->insert($self->sinter(@keys));
    return $self->scard($dest);
}


=head1 AUTHOR

Jeff Lavallee, C<< <jeff at zeroclue.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mock-redis at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Mock-Redis>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Mock::Redis


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mock-Redis>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mock-Redis>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mock-Redis>

=item * Search CPAN

L<http://search.cpan.org/dist/Mock-Redis/>

=back


=head1 TODO

Not all Redis functionality is implemented.  Pull requests welcome!

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

1; # End of Mock::Redis
