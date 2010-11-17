#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Git::Editor' ) || print "Bail out!
";
}

diag( "Testing Git::Editor $Git::Editor::VERSION, Perl $], $^X" );
