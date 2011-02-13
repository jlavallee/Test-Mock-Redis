package Mock::Redis;

use warnings;
use strict;

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

    my $foo = Mock::Redis->new();
    ...

=head1 SUBROUTINES/METHODS

=head2 new

    Create a new Mock::Redis object.  Can be passed a hashref 
    that determines the contents of the mock Redis database.

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

    $self->_stash->{$key} = $value;
    return 1;
}

sub setnx {
    my ( $self, $key, $value ) = @_;

    unless($self->exists($key)){
        $self->_stash->{$key} = $value;
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


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Jeff Lavallee.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Mock::Redis
