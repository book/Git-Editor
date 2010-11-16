#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Git::Sed' ) || print "Bail out!
";
}

diag( "Testing Git::Sed $Git::Sed::VERSION, Perl $], $^X" );
