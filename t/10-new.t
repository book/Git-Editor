use strict;
use warnings;
use Test::More;
use Cwd;
use Git::Repository;
use Git::Editor;
use Test::Git;

# check prerequisites
has_git();

plan tests => 9;

# a place to put a git repository
my $r = test_repository;
isa_ok( $r, 'Git::Repository' );

my $ed;

# repository in the current directory
my $home = cwd;
chdir $r->work_tree;
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
