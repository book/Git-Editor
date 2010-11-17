use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use Cwd;
use Git::Repository;
use Git::Editor;

# check prerequisites
plan skip_all => 'Default git binary not found in PATH'
    if !Git::Repository::Command::_is_git('git');

plan 'no_plan';

# a place to put a git repository
my $dir = tempdir( CLEANUP => 1 );
my $home = cwd;
chdir $dir;
my $r = Git::Repository->create('init');
isa_ok( $r, 'Git::Repository' );
chdir $home;

# get an editor
my $ed = Git::Editor->new( git_dir => $r->git_dir );
my $pkg = $ed->package;

# test code generation
my $code;

# line 1234 test.t
is( $code = $ed->generate_code(), << "EOT", 'NOOP' );
package $pkg;
sub {
# line 1234 test.t

}
EOT
ok( eval { eval $ed->generate_code(); 1; }, 'code compiles' );

# line 1235 test.t
is( $code = $ed->generate_code( DUMMY => 'dummy.t' ),
    << "EOT", 'DUMMY file' );
package $pkg;
sub {
# line unknown dummy.t
DUMMY
}
EOT
ok( eval { eval $ed->generate_code(); 1; }, 'code compiles' );

# line 1236 test.t
is( $code = $ed->generate_code( DUMMY => 'dummy.t', 4321 ),
    << "EOT", 'DUMMY file line' );
package $pkg;
sub {
# line 4321 dummy.t
DUMMY
}
EOT
ok( eval { eval $ed->generate_code(); 1; }, 'code compiles' );

# test code execution
my $coderef;
ok( eval { $coderef = eval $ed->generate_code(); 1; }, 'NOOP code compiles' );
my $commit = {
    commit    => 'ebb3aa2746cfef88a54b5d1f335d0b51d269f3d5',
    tree      => '2a6993bd6529fb3d541204d056a6054cb7b6b812',
    parent    => ['d5342ba5b467382c291f6fd49f6b84f16ecd4001'],
    author    => 'Philippe Bruhat (BooK) <book@cpan.org> 1290020478 +0100',
    committer => 'Philippe Bruhat (BooK) <book@cpan.org> 1290020478 +0100',
    message   => 'rename the project to Git-Editor',
};

my $same = $ed->execute_code( $coderef => $commit );
is_deeply( $same, $commit, 'commit not modified by NOOP' );
