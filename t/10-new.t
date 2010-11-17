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

plan tests => 9;

# a place to put a git repository
my $dir = tempdir( CLEANUP => 1 );
my $home = cwd;
chdir $dir;
my $r = Git::Repository->create( 'init' );
isa_ok( $r, 'Git::Repository' );

my $ed;

# repository in the current directory
$ed = Git::Editor->new();
isa_ok( $ed->repository, 'Git::Repository' );
is( $ed->repository->git_dir, $r->git_dir, 'git_dir' );
is( $ed->repository->work_tree, $r->work_tree, 'work_tree' );

# repository somewhere else
chdir $home;
$ed = Git::Editor->new( git_dir => $r->git_dir );
isa_ok( $ed->repository, 'Git::Repository' );
is( $ed->repository->git_dir, $r->git_dir, 'git_dir' );
is( $ed->repository->work_tree, $r->work_tree, 'work_tree' );

# private package
like( $ed->package, qr/^Git::Editor::Scratch::[0-9a-f]+$/,
    'private package' );

# two editors on the same repo will have different private packages
isnt( Git::Editor->new( git_dir => $r->git_dir )->package,
    $ed->package, 'same repo, different private packages' );
