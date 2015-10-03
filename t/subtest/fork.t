#!/usr/bin/perl -w
use strict;
use warnings;
use Test::Stream::Plugin::CanFork;

use IO::Pipe;
use Test::Builder;
use Test::More;

plan 'tests' => 1;

subtest 'fork within subtest' => sub {
    plan tests => 2;

    my $pipe = IO::Pipe->new;
    my $pid = fork;
    defined $pid or plan skip_all => "Fork not working";

    if ($pid) {
        $pipe->reader;
        my $child_output = do { local $/ ; <$pipe> };
        waitpid $pid, 0;

        is $?, 0, 'child exit status';
        like $child_output, qr/^[\s#]+Child Done\s*\z/, 'child output';
    } 
    else {
        $pipe->writer;

        # Force all T::B output into the pipe, for the parent
        # builder as well as the current subtest builder.
        my $tb = Test::Builder->new;
        $tb->output($pipe);
        $tb->failure_output($pipe);
        $tb->todo_output($pipe);

        diag 'Child Done';
        exit 0;
    }
};
