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
package Zimbra::Failover::SoapToTomcat;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(becomeMaster);

use strict;
use Zimbra::SOAP::XmlDoc;
use Zimbra::SOAP::Soap;
use Zimbra::Failover::Config;

my $ADMIN_NS = "urn:Zimbra::Admin";
my $REPL_NS = "urn:zimbraRepl";

sub invoke($$$) {
    my ($soap, $doc, $timeout) = @_;
    my $resp;
    my $port = Zimbra::Failover::Config::getAdminSOAPPort();
    my $url = "http://localhost:$port/service/soap/";
    eval {
        $resp = $soap->invoke($url, $doc, undef, $timeout);
    };
    return $resp;
}

sub becomeMaster() {
    my $soap = $Zimbra::SOAP::Soap::Soap12;
    my $doc = new Zimbra::SOAP::XmlDoc;
    $doc->start('BecomeMasterRequest', $REPL_NS);
    $doc->end();
    my $resp = invoke($soap, $doc->root(), undef);
    return $resp;
}

sub ping() {
    my $soap = $Zimbra::SOAP::Soap::Soap12;
    my $doc = new Zimbra::SOAP::XmlDoc;
    $doc->start('PingRequest', $ADMIN_NS);
    $doc->end();
    my $resp = invoke($soap, $doc->root(), 10);
    return $resp;
}

sub checkHealth() {
    my $soap = $Zimbra::SOAP::Soap::Soap12;
    my $doc = new Zimbra::SOAP::XmlDoc;
    $doc->start('CheckHealthRequest', $ADMIN_NS);
    $doc->end();
    my $resp = invoke($soap, $doc->root(), 10);
    return $resp;
}

1;
