#!/usr/bin/perl -w
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2010, 2011, 2012, 2013, 2014, 2015, 2016 Synacor, Inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software Foundation,
# version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.
# ***** END LICENSE BLOCK *****
#  

use strict;
use File::Copy;

 my $infile="/opt/zimbra/jetty/etc/zimbra.web.xml.in";
  my $outfile="/opt/zimbra/data/tmp/zimbra.web.xml.in.new";
  unlink("$outfile") if (-e "$outfile");
  open (IN, "<$infile");
  open (OUT, ">$outfile");
  my $next=0;
  
  while (<IN>) {
    if ($next == 0) {
      if ($_ =~ m/<param-name>jsVersion<\/param-name>/) {
        $next = 1;
      }
      print OUT $_;
    }
    else {
      my ($oldVersion) = $_ =~ /<param-value>(\d+)<\/param-value>/;
      my $newVersion=$oldVersion+1;
      $_ =~ s/$oldVersion/$newVersion/;
      print OUT $_;
      $next = 0;
    }
  }
  close(IN);
  close(OUT);
  copy($outfile, $infile);
  $infile="/opt/zimbra/jetty/etc/zimbraAdmin.web.xml.in";
  $outfile="/opt/zimbra/data/tmp/zimbraAdmin.web.xml.in.new";
  unlink("$outfile") if (-e "$outfile");
  open (IN, "<$infile");
  open (OUT, ">$outfile");
  $next=0;
  
  while (<IN>) {
    if ($next == 0) {
      if ($_ =~ m/<param-name>jsVersion<\/param-name>/) {
        $next = 1;
      }
      print OUT $_;
    }
    else {
      my ($oldVersion) = $_ =~ /<param-value>(\d+)<\/param-value>/;
      my $newVersion=$oldVersion+1;
      $_ =~ s/$oldVersion/$newVersion/;
      print OUT $_;
      $next = 0;
    }
  }
  close(IN);
  close(OUT);
  copy($outfile, $infile);


