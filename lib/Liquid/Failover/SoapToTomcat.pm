package Liquid::Failover::SoapToTomcat;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(becomeMaster);

use strict;
use Liquid::SOAP::XmlDoc;
use Liquid::SOAP::Soap;
use Liquid::Failover::Config;

my $ADMIN_NS = "urn:liquidAdmin";
my $REPL_NS = "urn:liquidRepl";

sub invoke($$$) {
    my ($soap, $doc, $timeout) = @_;
    my $resp;
    my $port = Liquid::Failover::Config::getAdminSOAPPort();
    my $url = "http://localhost:$port/service/soap/";
    eval {
        $resp = $soap->invoke($url, $doc, undef, $timeout);
    };
    return $resp;
}

sub becomeMaster() {
    my $soap = $Liquid::SOAP::Soap::Soap12;
    my $doc = new Liquid::SOAP::XmlDoc;
    $doc->start('BecomeMasterRequest', $REPL_NS);
    $doc->end();
    my $resp = invoke($soap, $doc->root(), undef);
    return $resp;
}

sub ping() {
    my $soap = $Liquid::SOAP::Soap::Soap12;
    my $doc = new Liquid::SOAP::XmlDoc;
    $doc->start('PingRequest', $ADMIN_NS);
    $doc->end();
    my $resp = invoke($soap, $doc->root(), 10);
    return $resp;
}

sub checkHealth() {
    my $soap = $Liquid::SOAP::Soap::Soap12;
    my $doc = new Liquid::SOAP::XmlDoc;
    $doc->start('CheckHealthRequest', $ADMIN_NS);
    $doc->end();
    my $resp = invoke($soap, $doc->root(), 10);
    return $resp;
}

1;
