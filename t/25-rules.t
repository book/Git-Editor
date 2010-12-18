use strict;
use warnings;
use Test::More;
use Git::Repository 'Log';
use Git::Editor;
use Test::Git;
use File::Spec;

# check prerequisites
has_git();

plan 'no_plan';

# a place to put a git repository
my $r = test_repository;

# put some content
my $file = 'file.txt';
my $path = File::Spec->catfile( $r->work_tree, $file );
open my $fh, '>', $path or die "Can't open $path: $!";
print $fh "line 1\n";
close $fh;
$r->run( add => $file );
$r->run( commit => '-m', 'new flie with one line' );

# update content
open $fh, '>>', $path or die "Can't open $path: $!";
print $fh "line 2\n";
close $fh;
$r->run( add => $file );
$r->run( commit => '-m', 'add an extra line' );

# quick check
my @old = $r->log();
is( scalar @old, 2, '2 original commits' );
is( $old[-1]{subject}, 'new flie with one line', 'expected commit message' );

# get an editor
my $ed = Git::Editor->new( git_dir => $r->git_dir );

# add a rule
$ed->add_rule( 'commit *' => $ed->compile_code( '$M =~ s/flie/file/g' ) );

# do the transform
$ed->process_revlist( 'master' );

# now check the results
my @new = $r->log();
is( scalar @new, scalar @old, 'same number of commits in the new branch' );
is( $new[-1]{subject}, 'new file with one line', 'fixed commit message' );

