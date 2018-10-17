#!/usr/bin/perl -w
use strict;
use warnings FATAL => 'all';


# test child command
my $child_command = "./testcmd.sh";
print "child command='$child_command'\n";


use IPC::Open3;
use IO::Select;
use POSIX ":sys_wait_h";
use Symbol 'gensym';

# Options:

my $COMMENTARY;
$COMMENTARY=1;	# verbose

# we might lose output if interrupted, so it's safest to die
# TODO: robust handling of interruption (if that's even possible!)
my $DIE_ON_INTERRUPTION = 1;


#-----------------------------------------------------------------------------

my $child_pid;
my $child_result;


#-----------------------------------------------------------------------------

# install SIGCHILD handler
# - we receive SIGCHILD when child exits
# - make sure we clean up child (i.e. avoid zombie)
$SIG{CHLD} = sub {
	return if !defined $child_pid;

	print "SIGCHILD caught...\n" if $COMMENTARY;

	# find out what happened to child
	my $kid = waitpid($child_pid, WNOHANG);
	my $child_status = $?;
	print "child_status=$child_status\n";

	if ($kid > 0) {
		# child exited
		if ($child_status & 127) {
			# child died somehow
			die sprintf("child died with signal %d, %s coredump\n", ($? & 127),  ($? & 128) ? 'with' : 'without');
		} else {
			# child exited calmly
			$child_result = ($child_status >> 8);
			print "(child exited normally with result=$child_result)\n" if $COMMENTARY;
		}
	} else {
		# unexpected (e.g. interrupted?)
		print "(other SIGCHILD: pid=$child_pid: child_status=$child_status\n" if $COMMENTARY;

		# we might decide this is fatal
		die "interrupted: unable to continue\n" if $DIE_ON_INTERRUPTION;
	}
};


#-----------------------------------------------------------------------------
# setup

# handles for stdin/stdout/stderr
my ($child_stdin, $child_stdout, $child_stderr);
$child_stderr = gensym;


# create handles & start command
eval {
	$child_pid = open3($child_stdin, $child_stdout, $child_stderr, $child_command);
};
die "open3 failed: $@\n" if $@;


# if we're not interested in anything interactive, just close stdin immediately
#close($child_stdin);



#-----------------------------------------------------------------------------
# handlers

sub received_stdout {
	my $input = shift or die;
	print "STDOUT: $input";

	# interact with our test script: respond when prompted
	if ($input =~ /prompt/) {
		print "(responding to prompt)\n" if $COMMENTARY;
		print $child_stdin "response to prompt\n";
	}
}

sub received_stderr {
	my $input = shift or die;
	print "STDERR: $input";
}


#-----------------------------------------------------------------------------
# read input

my $selector = IO::Select->new();
$selector->add($child_stdout, $child_stderr);

while (my @ready = $selector->can_read) {
    foreach my $fh (@ready) {

		# we need to detect end-of-input somehow, either:
        # - newline ended lines
		# - using a timeout (in 'can_read')
		# this implementation uses newlines

		# read until newline
		my $data="";
		my $CHUNK_SIZE=1000;
		
		while (1) {
			my $len = sysread($fh, $data, $CHUNK_SIZE, length($data));
			die("failed to read input: $!\n") unless defined $len;

			# detect end-of-file
			if ($len == 0) {
				print "end of file on input\n" if $COMMENTARY;
				$selector->remove($fh);
				last;
			}

			# end of input if we didn't get all the data we asked for
			last if $len < $CHUNK_SIZE;

			# end of input if we got newline
			last if substr ($data, -1)  eq "\n";
		}

		# look at the filehandle we read, and handle appropriately
        if (fileno($fh) == fileno($child_stdout)) {
			if (length($data)) {
				received_stdout($data);
			} else {
				print "(stdout closed)\n" if $COMMENTARY;
			}
		} elsif (fileno($fh) == fileno($child_stderr)) {
			if (length($data)) {
				received_stderr($data);
			} else {
				print "(stderr closed)\n" if $COMMENTARY;
			}
		} else {
			die "received input on unexpected filehandle";
		}

    }
}

close($child_stdout);
close($child_stderr);
close($child_stdin);

print "child exited with result=$child_result\n" if defined $child_result && $COMMENTARY;

