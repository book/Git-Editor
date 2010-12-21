use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Git::Editor',
    license             => 'perl',
    dist_author         => q{Philippe Bruhat (BooK) <book@cpan.org>},
    dist_version_from   => 'lib/Git/Editor.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'Git::Repository' => 1.15,
    },
    add_to_cleanup      => [ 'Git-Editor-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
