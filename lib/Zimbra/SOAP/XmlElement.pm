# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2004, 2005, 2007, 2009, 2010 VMware, Inc.
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
package Zimbra::SOAP::XmlElement;

use strict;
use warnings;

use XML::Parser;

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

# 
# parses XML into a hash of hashes, where 'name' is the name
# of the tag, 'ns' is the namespace URI,
# 'attrs' is a hash of the attributes, 'children'
# is an array of the child elements, and 'content' is all of 
# the textual content.
# 
# for example:
# 
# <wkdc:getTokensRequest xmlns:wkdc="http://stanford.edu/wkdc">
#    <requesterCredential type="krb5">
#               {base64-krb5-mk-req-data}
#    </requesterCredential>
#   <tokens>
#     <token type="service" id="0"/>
#   </tokens>
# </wkdc:getTokensRequest>
# 
# will parse into:
# 
# $tree = {
#   'name' => 'getTokensRequest',
#   'ns' => 'http://stanford.edu/wkdc',
#   'attrs' => {},
#   'children' => [
#       {
#         'name' => 'requesterCredential',
#         'attrs' => { 'type' => 'krb5' },
#         'content' => '   {base64-krb5-mk-req-data}  '
#       },
#       {
#          'name' => 'tokens',
#          'attrs' => {},
#          'children' => [
#             {
#               'name' => 'token',
#               'attrs' => { 'id' => 0, 'type' => 'service'},
#               'content' => '     '
#             }
#          ]
#       }
#   ]
#   'content' => '      '
# };
#
# note that all the whitespace in the document will get left
# in. It should be trim'd if needed.
#

sub parse {
    my $xml = shift;
    my $parser = new XML::Parser(Namespaces => 1,
				 Handlers => {
				     Start => \&XPStart,
				     End => \&XPEnd,
				     Char => \&XPChar,
				     Init => \&XPInit,
				     Final => \&XPFinal
				     });
    return $parser->parse($xml);
}

# creates a new element with the specified name and namespace
sub new {
    my $type = shift;
    my ($name, $ns) = @_;
    my $self = { 'attrs' => {}, 'children' => []};
    bless $self, $type;
    $self->name($name) if defined $name;
    $self->ns($ns) if defined $ns;

    return $self;
}

# returns the name of this element
sub name {
    my $self = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'};
}


# returns the URI of the namespace of this element
sub ns {
    my $self = shift;
    $self->{'ns'} = shift if @_;
    return $self->{'ns'};
}

# returns the content
sub content {
    my $self = shift;
    $self->{'content'} = shift if @_;
    return $self->{'content'};
}

# returns the content with leading and trailing whitespace removed
sub content_trimmed {
    my $self = shift;
    my $c = $self->{'content'};
    $c =~ s/^\s*(.*)\s*$/$1/;
    return $c; 
}

# apppend the given string to the content
sub append_content {
    my $self = shift;
    $self->{'content'} .= shift if @_;
}

# returns (and sets new if specified) the hash ref containing attrs
sub attrs {
    my $self = shift;
    $self->{'attrs'} = shift if @_;
    return $self->{'attrs'};
}

# returns true if this element has any attrs
sub has_attrs {
    my $self = shift;
    return %{$self->{'attrs'}};
}

# returns (and sets new if specified) attribute
sub attr {
    my $self = shift;
    my $name = shift;
    $self->{'attrs'}{$name} = shift if @_;
    return $self->{'attrs'}{$name};
}

# returns (and sets new if specified) child array ref
sub children {
    my $self = shift;
    $self->{'children'} = shift if @_;
    return $self->{'children'};
}

# returns true if this element has any children
sub has_children {
    my $self = shift;
    return $#{$self->{'children'}} != -1;
}

# returns the number of children
sub num_children {
    my $self = shift;
    return $#{$self->{'children'}} + 1;
}

# return the child at the specified index
sub child {
    my ($self, $index) = @_;
    return $self->{'children'}->[$index];
}

# this will only find the first child with the given name
sub  find_child {
    my $self = shift;
    my $name = shift;
    foreach my $child (@{$self->children}) {
	return $child if ($child->name() eq $name);
    }
    return undef;
}

# add a new child
sub add_child {
    my $self = shift;
    push @{$self->{'children'}}, shift;
}

# escape any special XML characters
sub escape {
    my $v = shift;
    $$v =~ s/&/&amp;/sg;
    $$v =~ s/</&lt;/sg;
    $$v =~ s/>/&gt;/sg;
    $$v =~ s/\"/&quot;/sg;
    $$v =~ s/\'/&apos;/sg;
}

sub recursive_to_string {
    my ($e, $ctxt) = @_;

    my $pretty = $ctxt->{'pretty'};
    my $level = $ctxt->{'level'};
    my $out = $ctxt->{'out'};

    my $name = $e->name();
    my $ns_uri = $e->ns();
    my $xmlns;

    if (defined $ns_uri) {
	my $prefix = get_ns_prefix($ctxt, $ns_uri);
	if (!defined($prefix)) {
	    $prefix = new_ns_prefix($ctxt, $ns_uri);
	    $xmlns = "xmlns:$prefix=\"$ns_uri\"";
	 }
	$name = "$prefix:$name";
    }

    my $closed = 0;
    my $cont = 0;
    $$out .= ' ' x $level if $pretty;
    $$out .= "<$name";
    while (my($attr,$val) = each(%{$e->attrs})) {
	escape(\$val);
	$$out .= " $attr=\"$val\"";
    }
    $$out .= " $xmlns" if $xmlns;

    my $child;

    if (defined($e->content)) {
	if (!$closed) {
	    $$out .= ">";
	    $closed=1;
	}
	$cont = 1;
	my $c = $e->content;
	escape(\$c);
	$$out .= $c;
    }

    foreach $child (@{$e->children}) {
	    if (!$closed) {
		$$out .= ">";
		$$out .= "\n" if $pretty;
		$closed=1;
	    }
	    $ctxt->{'level'} += 2;
	    recursive_to_string($child, $ctxt);
	    $ctxt->{'level'} = $level;
	}
    
    if ($closed) {
	$$out .= ' ' x $level if $pretty && !$cont;
	$$out .= "</$name>";
	$$out .= "\n" if $pretty;
    } else {
	$$out .= "/>";
	$$out .= "\n" if $pretty;
    }
}

# returns the prefix of the specified URI
sub get_ns_prefix {
    my ($ctxt, $uri) = @_;
    my $pre = $ctxt->{'ns'}->{$uri};
    return $pre;
}

# create a new prefix for the specified URI
sub new_ns_prefix {
    my ($ctxt, $uri) = @_;
    chomp $uri if ($uri =~ m!/$!);
    #my ($pre) = ($uri =~ m!.*/([a-zA-z][a-zA-Z0-9]{1,4})!);
    #if (defined $ctxt->{$pre}) {
	my $pre = "ns" . $ctxt->{'nscounter'}++;
    #} else {
	#$ctxt->{$pre} = 1;
    #}

    $ctxt->{'ns'}->{$uri} = $pre;
    return $pre;
}

# convert this element to a string
sub to_string {
    my $self = shift;
    my $pretty = shift;
    my $output = "";
    my $ctxt = {pretty => $pretty, 
		out => \$output, 
		level => 0,
		nscounter => 0,
		ns => {}
	    };
    recursive_to_string($self, $ctxt);
    return $output;
}

# XML::Parser Init handler
sub XPInit {
  my $expat = shift;
  $expat->{'Doc'} = {};
  $expat->{'Stack'} = [];
  $expat->{'Cur'} = undef;
}

# XML::Parser Start handler
sub XPStart {
  my $expat = shift;
  my $tag = shift;

  my $element = new Zimbra::SOAP::XmlElement($tag, $expat->namespace($tag));

  if ($#_ >= 0) {
      $element->attrs({@_});
  }

  my $cur = $expat->{'Cur'};
  
  if (defined $cur) {
      $cur->add_child($element);
      push @{$expat->{'Stack'}}, $cur;
  } else {
      $expat->{'Doc'} = $element;
  }
  $expat->{'Cur'} = $element;
}

# XML::Parser End handler
sub XPEnd {
  my $expat = shift;
  my $tag = shift;
  $expat->{'Cur'} = pop @{ $expat->{'Stack'}};
}

# XML::Parser Char handler
sub XPChar {
  my $expat = shift;
  my $text = shift;
  my $e = $expat->{'Cur'};
  $e->append_content($text);
}

# XML::Parser Final handler
sub XPFinal {
  my $expat = shift;
  delete $expat->{'Cur'};
  delete $expat->{'Stack'};
  $expat->{'Doc'};
}

1;
