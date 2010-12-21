use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Git::Editor',
    AUTHOR              => q{Philippe Bruhat (BooK) <book@cpan.org>},
    VERSION_FROM        => 'lib/Git/Editor.pm',
    ABSTRACT_FROM       => 'lib/Git/Editor.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Git::Repository' => 1.15,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Git-Editor-*' },
);
