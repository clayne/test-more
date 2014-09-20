package Test::Stream::Event::Ok;
use strict;
use warnings;

use base 'Test::Stream::Event';

use Scalar::Util qw/blessed/;
use Test::Stream::Util qw/unoverload_str/;
use Test::Stream::Carp qw/confess/;

use Test::Stream qw/OUT_STD/;
use Test::Stream::Event;
BEGIN {
    accessors qw/real_bool name diag bool level/;
    Test::Stream::Event->cleanup;
};

sub skip { $_[0]->[CONTEXT]->skip }
sub todo { $_[0]->[CONTEXT]->todo }

sub init {
    my $self = shift;

    # Do not store objects here, only true/false/undef
    if ($self->[REAL_BOOL]) {
        $self->[REAL_BOOL] = 1;
    }
    elsif(defined $self->[REAL_BOOL]) {
        $self->[REAL_BOOL] = 0;
    }
    $self->[LEVEL] = $Test::Builder::Level;

    my $ctx  = $self->[CONTEXT];
    my $rb   = $self->[REAL_BOOL];
    my $todo = $ctx->in_todo;
    my $skip = defined $ctx->skip;
    my $b    = $rb || $todo || $skip || 0;
    my $diag = delete $self->[DIAG];
    my $name = $self->[NAME];

    $self->[BOOL] = $b ? 1 : 0;

    unless ($rb || ($todo && $skip)) {
        my $msg = $todo ? "Failed (TODO)" : "Failed";
        my $prefix = $ENV{HARNESS_ACTIVE} ? "\n" : "";

        my ($pkg, $file, $line) = $ctx->call;

        if (defined $name) {
            $msg = qq[$prefix  $msg test '$name'\n  at $file line $line.];
        }
        else {
            $msg = qq[$prefix  $msg test at $file line $line.];
        }

        $self->add_diag($msg);
    }

    $self->add_diag("    You named your test '$name'.  You shouldn't use numbers for your test names.\n    Very confusing.")
        if $name && $name =~ m/^[\d\s]+$/;

    $self->add_diag(@$diag) if $diag && @$diag;
}

sub to_tap {
    my $self = shift;
    my ($num) = @_;

    my $name    = $self->[NAME];
    my $context = $self->[CONTEXT];
    my $skip    = $context->skip;
    my $todo    = $context->todo;

    my @out;
    push @out => "not" unless $self->[REAL_BOOL];
    push @out => "ok";
    push @out => $num if defined $num;

    unoverload_str \$name if defined $name;

    if ($name) {
        $name =~ s|#|\\#|g;    # # in a name can confuse Test::Harness.
        push @out => ("-", $name);
    }

    if (defined $skip && defined $todo) {
        push @out => "# TODO & SKIP";
        push @out => $todo if length $todo;
    }
    elsif (defined $todo) {
        push @out => "# TODO";
        push @out => $todo if length $todo;
    }
    elsif (defined $skip) {
        push @out => "# skip";
        push @out => $skip if length $skip;
    }

    my $out = join " " => @out;
    $out =~ s/\n/\n# /g;

    return (OUT_STD, "$out\n") unless $self->[DIAG];

    return (
        OUT_STD, "$out\n",
        map {$_->to_tap($num)} @{$self->[DIAG]},
    );
}

sub add_diag {
    my $self = shift;

    my $context = $self->[CONTEXT];
    my $created = $self->[CREATED];

    for my $item (@_) {
        next unless $item;

        if (ref $item) {
            confess("Only diag objects can be linked to events.")
                unless blessed($item) && $item->isa('Test::Stream::Event::Diag');

            $item->link($self);
        }
        else {
            $item = Test::Stream::Event::Diag->new($context, $created, $self->[IN_SUBTEST], $item, $self);
        }

        push @{$self->[DIAG]} => $item;
    }
}

{
    # Yes, we do want to override the imported one.
    no warnings 'redefine';
    sub clear_diag {
        my $self = shift;
        return unless $self->[DIAG];
        my $out = $self->[DIAG];
        $self->[DIAG] = undef;
        $_->clear_linked for @$out;
        return $out;
    }
}

sub to_legacy {
    my $self = shift;

    my $result = {};
    $result->{ok}        = $self->bool ? 1 : 0;
    $result->{actual_ok} = $self->real_bool;
    $result->{name}      = $self->name;

    my $ctx = $self->context;

    if($self->skip && ($ctx->in_todo || $ctx->todo)) {
        $result->{type} = 'todo_skip',
        $result->{reason} = $ctx->skip || $ctx->todo;
    }
    elsif($ctx->in_todo || $ctx->todo) {
        $result->{reason} = $ctx->todo;
        $result->{type}   = 'todo';
    }
    elsif($ctx->skip) {
        $result->{reason} = $ctx->skip;
        $result->{type}   = 'skip';
    }
    else {
        $result->{reason} = '';
        $result->{type}   = '';
    }

    if ($result->{reason} eq 'incrementing test number') {
        $result->{type} = 'unknown';
    }

    return $result;
}

1;

__END__

=head1 NAME

Test::Stream::Event::Ok - Ok event type

=head1 DESCRIPTION

The ok event type.

=head1 METHODS

See L<Test::Stream::Event> which is the base class for this module.

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 COPYRIGHT

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>