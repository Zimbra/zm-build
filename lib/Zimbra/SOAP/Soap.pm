# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2004, 2005, 2007, 2009, 2010, 2011 Zimbra Software, LLC.
# 
# The contents of this file are subject to the Zimbra Public License
# Version 1.3 ("License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://www.zimbra.com/license.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
# ***** END LICENSE BLOCK *****
# 
package Zimbra::SOAP::Soap;

use strict;
use warnings;

use XML::Parser;

use LWP::UserAgent;
use Zimbra::SOAP::XmlElement;
use Zimbra::SOAP::Soap12;
use Zimbra::SOAP::Soap11;

#use overload '""' => \&to_string;

BEGIN {
    use Exporter   ();
    our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

    # set the version for version checking
    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw();
}

our @EXPORT_OK;

our $Soap12 = new Zimbra::SOAP::Soap12;
our $Soap11 = new Zimbra::SOAP::Soap11;

#
# given a XmlElement, wrap it in a SOAP envelope and return the envelope
#

sub soapEnvelope {
    die "must override";
}

#
# Return Content-Type header
#

sub getContentType() {
    die "must override";
}

#
# Return the namespace String
#

sub getNamespace {
    die "must override";
}

#
# Return charset encoding for converting from bytes/strings
#

sub getCharSet {
    return "UTF-8";
}

#
# Convert a SOAP message in a String to bytes
#

sub convertToBytes {
    die "not implemented yet";
}

#
# Convert a SOAP message in bytes to a String 
#

sub convertToString {
    die "not implemented yet";
}

#
# return the first child in the soap body
#

sub getElement {
    die "must override";
}

#
# Returns true if this element represents a SOAP fault
#

sub isFault {
    die "must override";
}

#
# Returns true if this soap envelope has a SOAP fault as the
# first child of its body.     
#

sub hasFault {
    my ($self, $e) = @_;
    return $self->isFault($e->child(0));
}

#
# determine if given element is Soap11 or Soap12 envelope,
# and returns the Soap11 or Soap12 instance, or undef if neither.
#

sub determineProtocol {
    my $e = shift;
    return undef unless $e->name() eq "Envelope";
    return $Soap12 if ($e->ns() eq $Soap12->getNamespace());
    return $Soap11 if ($e->ns() eq $Soap11->getNamespace());
    return undef;
}

#
# Whether or not to include a HTTP SOAPActionHeader. (Gag)
#

sub hasSOAPActionHeader {
    die "must override";
}

#
# returns the version as a string (e.g, "1.1" or "1.2")
#

sub getVersion {
    die "must override";
}

#
sub toString {
    my $self = shift;
    return "SOAP ".$self->getVersion();
}

sub zimbraContext {
        my ($self, $authtoken) = @_;
        my $context = new Zimbra::SOAP::XmlElement("context", "urn:zimbra");
        my $auth = new Zimbra::SOAP::XmlElement("authToken");
        $auth->content($authtoken);
        $context->add_child($auth);
        return $context;                
}

# simple invoke method for now, this will get replaced

sub invoke {
    my ($self, $uri, $doc, $context, $timeout) = @_;

    my $env = $self->soapEnvelope($doc, $context);
    my $soap = $env->to_string();
    #print "REQUEST:\n" . $env->to_string('pretty') . "\n";
    my $ua = new LWP::UserAgent();
    if (defined($timeout) && $timeout > 0) {
        $ua->timeout($timeout);  # timeout in seconds
    }
    my $req = new HTTP::Request(POST=> $uri);

    $req->content_type($self->getContentType());
    $req->content_length(length($soap));
    if ($self->hasSOAPActionHeader()) {
        $req->header("SOAPAction" => $uri);
    }
    $req->add_content($soap);
    my $res = $ua->request($req);
    if (!defined($res)) {
        print STDERR "No response from server\n";
        return undef;
    }

    my $xml = undef;
    eval {
        $xml = Zimbra::SOAP::XmlElement::parse($res->content);
    };
    if (!defined($xml)) {
        # Check for network/HTTP error after trying XML parse because
        # a SOAP fault comes back with HTTP 500 status.
        if ($res->is_error()) {
            print STDERR
                "SOAP request failed: code=" . $res->code() .
                ", error=" . $res->message() . "\n";
        } else {
            # We have legitimate XML parse error.
            print STDERR
                "Unable to parse SOAP response: " . $res->content() . "\n";
        }
        return undef;
    }
    my $rsoap = determineProtocol($xml);
    if (!defined($rsoap)) {
        print STDERR "Unable to determine SOAP protocol\n";
        return undef;
    } elsif ($rsoap != $self) {
        print STDERR "Unexpected SOAP version in response\n";
        return undef;
    }

    my $resp = $self->getElement($xml);
    #print "RESPONSE:\n" . $resp->to_string('pretty') . "\n" if defined($resp);

    if ($self->isFault($resp)) {
        my $faultParsed = 0;
        my $reason = $resp->find_child('Reason');
        if (defined($reason)) {
            my $text = $reason->find_child('Text');
            if (defined($text)) {
                print STDERR
                    "Received SOAP fault: " . $text->content() . "\n";
                $faultParsed = 1;
            }
        }
        if (!$faultParsed) {
            print STDERR
                "Received SOAP fault: " . $resp->to_string('pretty') . "\n";
        }
        return undef;
    }

    return $resp;
}

1;
