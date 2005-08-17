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
