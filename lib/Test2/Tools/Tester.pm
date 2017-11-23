package Test2::Tools::Tester;
use strict;
use warnings;

our $VERSION = '0.000087';

use Carp qw/croak/;
use Module::Pluggable search_path => ['Test2::EventFacet'], require => 1;
use Test2::Util::Ref qw/rtype/;

use Importer Importer => 'import';

our @EXPORT_OK = qw{
    facets
    filter_events
    event_groups
};

my %TYPES;
for my $class (__PACKAGE__->plugins) {
    my $type = $class;
    $type =~ s/^.*::EventFacet:://g;

    my $key = $class->facet_key || lc($type);

    $TYPES{$type}     = $class;
    $TYPES{lc($type)} = $class;
    $TYPES{$key}      = $class;
}

sub filter_events {
    my $events = shift;

    my @match = map { rtype($_) eq 'REGEXP' ? $_ : qr/^\Q$_\E::/} @_;

    my @out;
    for my $e (@$events) {
        my $trace = $e->facet_data->{trace} or next;
        next unless grep { $trace->{frame}->[3] =~ $_ } @match;
        push @out => $e;
    }

    return \@out;
}

sub event_groups {
    my $events = shift;

    my $out = {};
    for my $e (@$events) {
        my $trace = $e->facet_data->{trace};
        my $tool = ($trace && $trace->{frame} && $trace->{frame}->[3]) ? $trace->{frame}->[3] : undef;

        unless ($tool) {
            push @{$out->{__NA__}} => $e;
            next;
        }

        my ($pkg, $sub) = ($tool =~ m/^(.*)(?:::|')([^:']+)$/);

        push @{$out->{$pkg}->{$sub}} => $e;
        push @{$out->{$pkg}->{__ALL__}} => $e;
    }

    return $out;
}

sub facets {
    my ($type, $events) = @_;

    my ($key, $is_list);
    my $class = $TYPES{$type};
    if ($class) {
        $key = $class->facet_key || lc($type);
        $is_list = $class->is_list;
    }
    else {
        $key = lc($type);
    }

    my @out;
    for my $e (@$events) {
        my $fd = $e->facet_data;
        my $f  = $fd->{$key} or next;

        my $list = defined($is_list) ? $is_list : rtype($f) eq 'ARRAY';

        if ($list) {
            push @out => map { $class ? $class->new($_) : $_ } @$f;
        }
        else {
            push @out => $class ? $class->new($f) : $f;
        }
    }

    return \@out;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Tools::Tester - Tools to help you test other testing tools.

=head1 DESCRIPTION

This is a collection of tools that are useful when testing other test tools.

=head1 SYNOPSIS

    use Test2::Tools::Tester qw/event_groups filter_events facets/;

    use Test2::Tools::Basic qw/plan pass ok/;
    use Test2::Tools::Compare qw/is like/;

    my $events = intercept {
        plan 11;

        pass('pass');
        ok(1, 'pass');

        is(1, 1, "pass");
        like(1, 1, "pass");
    };

    # Grab events generated by tools in Test2::Tools::Basic
    my $basic = filter $events => 'Test2::Tools::Basic';

    # Grab events generated by Test2::Tools::Basic;
    my $compare = filter $events => 'Test2::Tools::Compare';

    # Grab events generated by tools named 'ok'.
    my $oks = filter $events => qr/.*::ok$/;

    my $grouped = group_events $events;
    # Breaks events into this structure:
    {
        '__NA__' => [ ... ],
        'Test2::Tools::Basic' => {
            '__ALL__' => [ $events->[0], $events->[1], $events->[2] ],
            plan => [ $events->[0] ],
            pass => [ $events->[1] ],
            ok => [ $events->[2] ],
        },
        Test2::Tools::Compare => { ... },
    }

    # Get an arrayref of all the assert facets from the list of events.
    my $assert_facets = facets assert => $events;
    # [
    #   bless({ details => 'pass', pass => 1}, 'Test2::EventFacet::Assert'),
    #   bless({ details => 'pass', pass => 1}, 'Test2::EventFacet::Assert'),
    # ]

    # Same, but for info facets
    my $info_facets = facets info => $events;

=head1 EXPORTS

No subs are exported by default.

=over 4

=item $array_ref = filter $events => $PACKAGE

=item $array_ref = filter $events => $PACKAGE1, $PACKAGE2

=item $array_ref = filter $events => qr/match/

=item $array_ref = filter $events => qr/match/, $PACKAGE

This function takes an arrayref of events as the first argument. All additional
arguments must either be a package name, or a regex. Any event that is
generated by a tool in any of the package, or by a tool that matches any of the
regexes, will be returned in an arrayref.

=item $grouped = group_events($events)

This function iterates all the events in the argument arrayref and splits them
into groups. The resulting data structure is:

    { PACKAGE => { SUBNAME => [ $EVENT1, $EVENT2, ... }}

If the package of an event is not known it will be put into and arrayref under
the '__NA__' key at the root of the structure. If a sub name is not known it
will typically go under the '__ANON__' key in under the package name.

In addition there is an '__ALL__' key under each package which stores all of
the events sorted into that group.

A more complete example:

    {
        '__NA__' => [ $event->[3] ],
        'Test2::Tools::Basic' => {
            '__ALL__' => [ $events->[0], $events->[1], $events->[2] ],
            plan => [ $events->[0] ],
            pass => [ $events->[1] ],
            ok => [ $events->[2] ],
        },
    }

=item $arrayref = facets TYPE => $events

This function will compile a list of all facets of the specified type that are
found in the arrayref of events. If the facet has a C<Test2::EventFacet::TYPE>
package available then the facet will be constructed into an instance of the
class, otherwise it is left as a hashref. Facet Order is preserved.

    my $assert_facets = facets assert => $events;
    # [
    #   bless({ details => 'pass', pass => 1}, 'Test2::EventFacet::Assert'),
    #   bless({ details => 'pass', pass => 1}, 'Test2::EventFacet::Assert'),
    # ]

=back

=head1 SOURCE

The source code repository for Test2-Suite can be found at
F<http://github.com/Test-More/Test2-Suite/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2017 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
