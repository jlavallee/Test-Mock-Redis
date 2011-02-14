use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Mock::Redis',
    license             => 'perl',
    dist_author         => q{Jeff Lavallee <jeff@zeroclue.com>},
    dist_abstract       => 'use Redis; without redis',
    dist_version_from   => 'lib/Mock/Redis.pm',
    meta_merge     => {
        resources => {
            bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mock-Redis',
            repository => 'http://github.com/jlavallee/Mock-Redis/',
        }
    },
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'Test::More' => 0,
        'Scalar::Util' => 0,
    },
    add_to_cleanup      => [ 'Mock-Redis-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
