# perl-IPC-Open3-example

This is an example for how to use Perl's `IPC::Open3` to create a child process & interact with its stdout/stdin/stderr & get the return code when it exits.

The [standard documentation](https://perldoc.perl.org/IPC/Open3.html) is rather thin, and there aren't many good examples published.

See the code for details (that's the point of an example, right?) but a few points:

- unbuffered input seems necessary if you want to write to child's stdin in response to child output:  the program could be simplified for some use cases (i.e. normal Perl I/O operators used) otherwise
- you must somehow decide when your blocks of input end: this could be via delimiter (e.g. newline in this example) or timeout
- if you don't need to send input to the child, you can just close the child stdin handle at the start
- catching SIGCHILD gives you the opportunity to throw an error if interrupted (you can lose input otherwise)
- handling interruption properly is hard (maybe impossible?) - this example doesn't do this
