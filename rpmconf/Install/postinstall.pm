#!/usr/bin/perl
# 
# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
# 
# The contents of this file are subject to the Mozilla Public License
# Version 1.1 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.zimbra.com/license
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# The Original Code is: Zimbra Collaboration Suite Server.
# 
# The Initial Developer of the Original Code is Zimbra, Inc.
# Portions created by Zimbra are Copyright (C) 2005 Zimbra, Inc.
# All Rights Reserved.
# 
# Contributor(s):
# 
# ***** END LICENSE BLOCK *****
# 

package postinstall;

sub configure {

	if (main::isEnabled("zimbra-ldap")) {
		main::runAsZimbra ("zmprov mcf zimbraComponentAvailable ''");
	}

	if (!defined ($main::options{c}) && 1) {
		if (main::askYN("\nYou have the option of notifying Zimbra of your installation.\nThis helps us to track the uptake of the Zimbra Collaboration Suite.\nThe only information that will be transmitted is:\n\tThe VERSION of zcs installed (${main::curVersion}_${main::platform})\n\tThe ADMIN EMAIL ADDRESS created ($main::config{CREATEADMIN})\n\nNotify Zimbra of your installation?", "Yes") eq "yes") {
			if (open NOTIFY, "/opt/zimbra/libexec/zmnotifyinstall ${main::curVersion}_${main::platform} $main::config{CREATEADMIN} |") {
				while (<NOTIFY>) {
					main::progress ("$_");
				}
				close NOTIFY;
				main::progress ("Notification complete!\n");
			} else {
				main::progress ("ERROR: Notification failed!\n\n");
			}
		} else {
		main::progress ("Notification skipped\n");
	}

}


}

1
