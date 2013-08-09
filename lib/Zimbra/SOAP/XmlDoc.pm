# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2004, 2005, 2007, 2009, 2010, 2011, 2013 Zimbra Software, LLC.
# 
# The contents of this file are subject to the Zimbra Public License
# Version 1.4 ("License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://www.zimbra.com/license.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
# ***** END LICENSE BLOCK *****
# 
package Zimbra::SOAP::XmlDoc;

use strict;
use warnings;
use Zimbra::SOAP::XmlElement;

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

sub new {
    my $type = shift;
    my $self = {};
    bless $self, $type;
    return $self;
}

sub to_string {
    my $self = shift;
    return $self->{'root'}->to_string(@_);
}
 
sub start {
    my $self = shift;
    my $name = shift;
    my $ns = shift;
    my $element = new Zimbra::SOAP::XmlElement($name, $ns);
    if (@_) {
	my $attrs = shift;
	$element->attrs($attrs) if defined($attrs);
    }
    if (@_) {
	$element->content(shift);
    }
    if (!defined($self->{'root'})) {
	$self->{'root'} = $element;
    } else {
	my $s = $self->{'stack'};
	my $parent = @{$s}[$#{$s}];
	$parent->add_child($element);
    }
    push(@{$self->{'stack'}}, $element);
    return $self;
}

sub current {
    my $self = shift;
    my $s = $self->{'stack'};
    my $e = @{$s}[$#{$s}] || die "not in an element";
    return $e;
}

sub end {
    my $self = shift;
    my $s = $self->{'stack'};
    my $e = @{$s}[$#{$s}] || die "not in an element";
    if (@_) {
	my $name = shift;
	my $aname = $e->name;
	if ($name ne $aname) {
	    die "name mismatch in end. expecting($name), actual($aname)";
	}
    }
    pop(@{$self->{'stack'}});
 }

sub add {
    my ($self, $name, $ns, $attrs, $text) = @_;
    $self->start($name, $ns, $attrs);
    $self->current->append_content($text) if defined($text);
    $self->end;
}

sub root {
    my $self = shift;
    return $self->{'root'};
}

1;

__END__
