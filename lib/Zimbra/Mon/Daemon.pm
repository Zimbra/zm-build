# 
# ***** BEGIN LICENSE BLOCK *****
# Version: ZPL 1.1
# 
# The contents of this file are subject to the Zimbra Public License
# Version 1.1 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.zimbra.com/license
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# The Original Code is: Zimbra Collaboration Suite.
# 
# The Initial Developer of the Original Code is Zimbra, Inc.
# Portions created by Zimbra are Copyright (C) 2005 Zimbra, Inc.
# All Rights Reserved.
# 
# Contributor(s):
# 
# ***** END LICENSE BLOCK *****
# 
package Zimbra::Mon::Daemon;

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
		Zimbra::Mon::Logger::Log ("crit","Fork error: $!");
		if ($! == EAGAIN) {
			Zimbra::Mon::Logger::Log ("err","Attempting recovery");
			sleep 5;
			next FORK;
		}
		else {
			Zimbra::Mon::Logger::Log ("crit","Unrecoverable fork error: $!");
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
