package Zimbra::Daemon;

use strict;
use vars qw(@ISA);
use SOAP::Transport::HTTP;

use Errno qw(EAGAIN);

use POSIX ":sys_wait_h";

@ISA = qw(SOAP::Transport::HTTP::Daemon);

sub handle {
  my $self = shift->new;
  # Avoid the main process signal handler
  local $SIG{CHLD} = 'IGNORE';
 CLIENT:
  	while (my $c = $self->accept) {

	my $cpid;
 FORK:
	if ($cpid = fork) { $c->close; next CLIENT }
	if (!defined ($cpid)) {
		Zimbra::Logger::Log ("crit","Fork error: $!");
		if ($! == EAGAIN) {
			Zimbra::Logger::Log ("err","Attempting recovery");
			sleep 5;
			next FORK;
		}
		else {
			Zimbra::Logger::Log ("crit","Unrecoverable fork error: $!");
			next CLIENT;
		}
	}
	
#print STDERR "$$ DAEMON forked\n";

    if (my $r = $c->get_request) {
      	$self->request($r);
      	$self->SOAP::Transport::HTTP::Server::handle;

      	$c->send_response($self->response);
    }
    $c->close;
    undef $c;
    # Exit, or runaway spawning...
#print STDERR "$$ DAEMON exiting\n";
    exit (0);
  }
}

1;
