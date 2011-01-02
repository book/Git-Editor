package Git::Editor;

use warnings;
use strict;
use Carp;
use Git::Repository 1.15 'Log';

our $VERSION = '0.01';

# some quick accessors
for my $attr (qw( repository package )) {
    no strict 'refs';
    *$attr = sub { return ref $_[0] ? $_[0]{$attr} : () };
}

sub new {
    my ( $class, @args ) = @_;

    # create the object instance
    my $self = bless {
        repository => Git::Repository->new(@args),
        mapper     => {},
        rules      => {},
        count      => 0,
    }, $class;

    # the instance's private package
    $self =~ /0x([0-9a-f]+)/;
    $self->{package} = "Git::Editor::Scratch::$1";

    # add some functions to the private package
    for my $meth (qw( remap )) {
        no strict 'refs';
        *{"$self->{package}::$meth"} = sub { $self->$meth(@_) };
    }

    return $self;
}

sub generate_code {
    my ( $self, $code, $source, $line ) = @_;
    ( $source, $line ) = (caller)[ 1, 2 ] if !defined $source;
    $line = 'unknown' if !defined $line;

    # remove code indentation based on the first line
    $code = '' if !defined $code;
    my ($indent) = $code =~ /^(\s+)/g;
    $code =~ s/^$indent//gm if defined $indent;

    # generate the code
    return << "EOT";
package $self->{package};
our ( \$H, \$T, \@P, \$M, \$an, \$ae, \$ad, \$cn, \$ce, \$cd );
sub {
# line $line $source
$code
}
EOT
}

sub compile_code {
    my ( $self, $code, $source, $line ) = @_;
    return eval $self->generate_code( $code, $source, $line );
}

sub execute_code {
    my ( $self, $code, $commit ) = @_;
    my $pkg = $self->{package};

    # use package variables
    # that will be accessible from the coderef scope
    {
        no strict 'refs';
        ${"$pkg\::H"} = $commit->{commit};
        ${"$pkg\::T"} = $commit->{tree};
        @{"$pkg\::P"} = @{ $commit->{parent} };
        ${"$pkg\::M"} = $commit->{message};
        ( ${"$pkg\::an"}, ${"$pkg\::ae"}, ${"$pkg\::ad"} )
            = $commit->{author} =~ /^(.*) <(.*)> (.*)$/;
        ( ${"$pkg\::cn"}, ${"$pkg\::ce"}, ${"$pkg\::cd"} )
            = $commit->{committer} =~ /^(.*) <(.*)> (.*)$/;
    }

    # call the code
    $code->();

    # create the new commit information structure
    no strict 'refs';
    return {
        commit    => $commit->{commit},
        tree      => ${"$pkg\::T"},
        parent    => \@{"$pkg\::P"},
        author    => qq{${"$pkg\::an"} <${"$pkg\::ae"}> ${"$pkg\::ad"}},
        committer => qq{${"$pkg\::cn"} <${"$pkg\::ce"}> ${"$pkg\::cd"}},
        message   => ${"$pkg\::M"},
    };
}

sub add_rule {
    my ( $self, $rule, $code ) = @_;

    # make sure we have a code ref
    my ( $type, $target ) = split /\s+/, $rule, 2;

    # check rule type is valid
    croak "Unknown rule type: $type" if $type !~ /^(?:commit)$/;

    # store the code
    push @{ $self->{rules}{$type}{$target} ||= [] },
        [ $code, $self->{count}++ ];
}

sub compile_script {
    my ( $self, $file ) = @_;
    my ( $rule, $code ) = ( '', '' );
    my $line;

    local @ARGV = ($file);
    while (<>) {
        next if /^#/;    # skip comments

        # generate code
        /^\S/ && do {
            $self->add_rule(
                $rule => $self->compile_code( $code, $file, $line ) );

            # prepare next block of code
            $line = $. + 1;
            $rule = $_;
            $code = '';
            next;
        };

        # update the code block
        $code .= $_;
    }
}

sub process_revlist {
    my ( $self, @revlist ) = @_;
    @revlist = qw( --all --date-order ) if !@revlist;
    my $r = $self->repository;
    my $mapper = $self->{mapper};

    # rewrite the commits
    my $iter = $r->log( '--reverse', @revlist );
    while ( my $commit = $iter->next ) {

        # keep the old id
        my $old_id = $commit->{commit};

        # fetch the new commit structure
        $commit = $self->process_commit(
            {   commit    => $old_id,
                tree      => $commit->tree,
                parent    => [ $commit->parent ],
                author    => $commit->author,
                committer => $commit->committer,
                message   => $commit->message,
            }
        );

        # remap parent commits
        # parent ids containing a '_' are not remapped
        $commit->{parent} = [ map { tr/_//d ? $_ : $self->remap($_) }
                @{ $commit->{parent} } ];

        # create the new commit object
        my ($new_id) = $r->run( { input => $commit->{message} },
            'commit-tree', $commit->{tree},
            map { ( '-p' => $_ ) } @{ $commit->{parent} } );

        # store the new id in the mapper
        $self->remap( $old_id => $new_id );
    }

    # collect all refs and what they point to
    my %refs = reverse map { split / / } $r->run(qw(show-ref --heads --tags));
    my %type = map { ( split / / )[ 0, 1 ] } $r->run(
        'cat-file' => '--batch-check',
        { input => join "\n", values %refs }
    );

    # rewrite the heads and tags
    while ( my ( $ref, $id ) = each %refs ) {
        if ( $type{$id} eq 'commit' ) {    # simple ref
            $r->run( 'update-ref' => $ref, $self->remap($id) );
        }
        elsif ( $type{$id} eq 'tag' ) {    # annotated tag
            my $content = $r->run( 'cat-file', 'tag', $id );
            $content =~ s/(?<=^object )([a-f0-9]{40})$/$self->remap($1)/me;
            carp "$ref was signed -- New tag signature will be invalid"
                if $content =~ /-----BEGIN PGP SIGNATURE-----/;
            my $tag_id = $r->run( mktag => { input => $content } );
            $r->run( 'update-ref' => $ref, $tag_id );
        }
        else {                             # uh?
            carp "Unhandled type '$type{$id}' for ref '$ref' ($id)";
        }
    }

}

sub process_commit {
    my ( $self, $commit ) = @_;
    my $rules = $self->{rules};
    my @code;

    # find all matching rules and collect code to apply
    $rules->{commit}{$_} && push @code, @{ $rules->{commit}{'*'} }
        for '*', $commit->{commit};

    # order code
    @code = map { $_->[0] } sort { $a->[1] <=> $b->[1] } @code;

    # successively apply the code
    $commit = $self->execute_code( $_ => $commit ) for @code;

    return $commit;
}

# methods to be shared with the code
sub remap {
    $_[0]{mapper}{ $_[1] } = $_[2] if @_ > 2;
    $_[0]{mapper}{ $_[1] } ||= $_[1];    # auto-remap to oneself
}

1;

__END__

=head1 NAME

Git::Editor - Rewrite a Git repository using Perl snippets

=head1 SYNOPSIS

    # see git-editor for user-level documentation

    # build your own editor
    my $ed = Git::Editor->new();
    my $coderef = $ed->compile_code('$M =~ s/foo/bar/g')
    $ed->add_rule( 'commit *' => $coderef );
    $ed->process_revlist( '--all' );

=head1 DESCRIPTION

C<Git::Editor> contains all routines used by the C<git-editor>
command-line script to write new commits in a Git repository
based on existing ones.

A C<Git::Editor> object collects snippets of code that will be used to
modify the content of commit objects in the repository, and then replace
them.



=head1 ACCESSORS

=head2 repository()

Return the C<Git::Repository> object used to interface the editor with
the repository.

=head2 package()

Each coderef is executed in its own package under the
C<Git::Editor::Scratch::> namespace.

This method returns the fully qualified package name.

=head1 METHODS

=head2 new( @args )

Create and return a new C<Git::Editor> object. The parameters in C<@args>
are passed to C<< Git::Repository->new() >> to create the C<Git::Repository>
object.

=head2 add_rule( $rule => coderef );

FIXME

=head2 generate_code( $code )

Given a snippet of code, return the full source code to the anonymous
subroutine used to process a commit. This code is compilable with C<eval "">.

=head2 compile_code( $code )

Compile the full subroutine code produced by C<generate_code> and return
the corresponding code reference.

=head2 execute_code( $coderef => $commit )

Call the given C<$coderef> (as obtained by C<compile_code>) with the
given C<$commit> hash as a parameter.

=head2 process_commit( $commit )

Execute all matching rules on a commit, potentially creating a new one.

=head2 process_revlist( @args )

Process all the commits in the given revlist using the rules list.

=head2 compile_script( $file )

Read a script file and generate the rules list and the code references.

=head1 FUNCTIONS AVAILABLE TO THE CODE SNIPPETS

Some C<Git::Editor> methods are also available as functions I<within>
a code snippet.

=head2 remap( $old [, $new ] )

Each time a commit is I<modified> by the editor, a new commit is actually
created, with a different id. The editor maintains a mapping of I<old-to-new>
commit id.

Returns the new id corresponding to the old one. Returns the old id
if no mapping is defined for the old id.

If C<$new> is given, it is stored as the id corresponding to the C<$old> id.


=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-git-editor at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Git-Editor>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Git::Editor


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Git-Editor>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Git-Editor>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Git-Editor>

=item * Search CPAN

L<http://search.cpan.org/dist/Git-Editor/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK).

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

