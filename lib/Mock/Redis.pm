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

sub new {
}

=head2 function2

=cut

sub function2 {
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
