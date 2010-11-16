use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Git::Sed',
    AUTHOR              => q{Philippe Bruhat (BooK) <book@cpan.org>},
    VERSION_FROM        => 'lib/Git/Sed.pm',
    ABSTRACT_FROM       => 'lib/Git/Sed.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Git-Sed-*' },
);
