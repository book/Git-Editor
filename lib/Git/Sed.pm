package Git::Sed;

use warnings;
use strict;
use Git::Repository 1.14 'Log';

our $VERSION = '0.01';

sub new {
    my ( $class, @args ) = @_;
    return bless {
        r      => Git::Repository->new(@args),
        mapper => {},
        rules  => {},
    }, $class;
}

sub compile {
    my ( $self, $source, $line, $code ) = @_;

    # remove code indentation
    my ($indent) = $code =~ /^(\s+)/g;
    $code =~ s/^$indent//gm;

    # compile the code
    return eval << "EOT";
sub {
    my ($commit) = @_;
    my \$T = \$commit->{tree};
    my \@P = \@{\$commit->{parent}};
    my \$M = \$commit->{message};
    my (\$an, \$ae, \$ad) = \$commit->{author} =~ /^(.*) <(.*)> (.*)\$/;
    my (\$cn, \$ce, \$cd) = \$commit->{committer} =~ /^(.*) <(.*)> (.*)\$/;
    {
# line $line $source
$code
    }
    return {
        tree      => \$T,
        parent    => \\\@P,
        author    => "\$an <\$ae> \$ad",
        committer => "\$cn <\$ce> \$cd",
        message   => \$M,
    };
}
EOT
}

sub process_revlist {
    my ( $self, @revlist ) = @_;

    my ( $r, $mapper ) = @{$self}{qw( r mapper )};

    # rewrite the commits
    my $iter = $r->log( '--reverse', @revlist );
    while ( my $commit = $iter->next ) {

        # keep the old id
        my $old_id = $commit->{commit};

        # fetch the new commit structure
        $commit = $self->process_commit(
            $old_id => {
                parent    => [ $commit->parent ],
                author    => $commit->{author},
                committer => $commit->{committer},
                message   => $commit->{subject}
                    . ( length $commit->{body} ? "\n\n$commit->{body}" : '' );
            }
        );

        # create the new commit object
        my ($new_id) = $r->run(
            { input => $commit->{message} },
            'commit-tree',
            $commit->{tree},
            map { ( '-p' => $_ ) }
                map { tr/_//d ? $_ : $mapper->{$_} } @{ $commit->{parent} }
        );

        # store the new id in the mapper
        $mapper->{$old_id} = $new_id;
    }

    # rewrite the heads
    my @heads = $r->run(qw( show-ref --heads ));

    # rewrite the tags
    my @tags = $r->run(qw( show-ref --tags ));
}

1;

__END__

=head1 NAME

Git::Sed - The great new Git::Sed!

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Git::Sed;

    my $foo = Git::Sed->new();
    ...

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-git-sed at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Git-Sed>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Git::Sed


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Git-Sed>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Git-Sed>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Git-Sed>

=item * Search CPAN

L<http://search.cpan.org/dist/Git-Sed/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK).

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

