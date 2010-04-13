#!/usr/bin/perl
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2009, 2010 Zimbra, Inc.
# 
# The contents of this file are subject to the Zimbra Public License
# Version 1.3 ("License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://www.zimbra.com/license.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
# ***** END LICENSE BLOCK *****

package Zimbra::Util::LDAP; 
use strict;
use Net::LDAP;

sub doLdap() {
  my $self=shift;
  my ($key, $value) = @_;
  my $is_master = $main::config{ldap_is_master};
  my $pw = $main::config{ldap_root_password};
  my $rc=0;
  my $real_master=0;
  my ($dn,$ldap_key);
  my $ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fopenldap%2fvar%2frun%2fldapi/') or die "$@";
  my $mesg = $ldap->bind("cn=config", password=>"$pw");
  if($mesg->code) {
    main::logMsg(2,"LDAP: Failed to bind");
	$ldap->unbind;
    return 1;
  }
  if ($is_master) {
    $mesg = $ldap->search(
                          base=> "cn=accesslog",
                          filter=>"(objectClass=*)",
                          scope => "base",
                          attrs => ['1.1'],
                   );
    my @entries=$mesg->entries;
    my $size = @entries;
    if ($size > 0 ) {
      $real_master = 1;
    }
  }
  if ($key =~ /^ldap_common_/) {
    if ($key eq "ldap_common_loglevel") {
      $ldap_key="olcLogLevel";
    } elsif ($key eq "ldap_common_threads") {
      $ldap_key="olcThreads";
    } elsif ($key eq "ldap_common_toolthreads") {
      $ldap_key="olcToolThreads";
    } elsif ($key eq "ldap_common_require_tls") {
      $ldap_key="olcSecurity";
      chomp($value);
      $value="ssf=$value";
    } elsif ($key eq "ldap_common_writetimeout") {
      $ldap_key="olcWriteTimeout";
    } else {
      main::logMsg(2,"LDAP common: Unknown key: $key");
      $rc=1;
    }
    $dn="cn=config";
  } elsif ($key =~ /^ldap_db_/) {
    if ($real_master) {
      $dn="olcDatabase={3}hdb,cn=config";
    } else {
      $dn="olcDatabase={2}hdb,cn=config";
    }
    if ($key eq "ldap_db_cachefree") {
      $ldap_key="olcDbCacheFree";
    } elsif ($key eq "ldap_db_cachesize") {
      $ldap_key="olcDbCacheSize";
    } elsif ($key eq "ldap_db_checkpoint") {
      $ldap_key="olcDbCheckpoint";
    } elsif ($key eq "ldap_db_dncachesize") {
      $ldap_key="olcDbDNcacheSize";
    } elsif ($key eq "ldap_db_idlcachesize") {
      $ldap_key="olcDbIDLcacheSize";
    } elsif ($key eq "ldap_db_shmkey") {
      $ldap_key="olcDbShmKey";
    } else {
      main::logMsg(2,"LDAP db: Unknown key: $key");
      $rc=1;
    }
  } elsif ($key =~ /ldap_access/) {
    if ($real_master) {
      $dn="olcDatabase={2}hdb,cn=config";
      if ($key eq "ldap_accesslog_cachefree") {
        $ldap_key="olcDbCacheFree";
      } elsif ($key eq "ldap_accesslog_cachesize") {
        $ldap_key="olcDbCacheSize";
      } elsif ($key eq "ldap_accesslog_checkpoint") {
        $ldap_key="olcDbCheckpoint";
      } elsif ($key eq "ldap_accesslog_dncachesize") {
        $ldap_key="olcDbDNcacheSize";
      } elsif ($key eq "ldap_accesslog_idlcachesize") {
        $ldap_key="olcDbIDLcacheSize";
      } elsif ($key eq "ldap_accesslog_shmkey") {
        $ldap_key="olcDbShmKey";
      } else {
        main::logMsg(2,"LDAP accesslog: Unknown key: $key");
        $rc=1;
      }
    }
  } elsif ($key =~ /ldap_overlay/) {
    if ($real_master) {
      if ($key =~ /ldap_overlay_syncprov/) {
        $dn="olcOverlay={0}syncprov,olcDatabase={3}hdb,cn=config";
        if ($key eq "ldap_overlay_syncprov_checkpoint") {
          $ldap_key="olcSpCheckpoint";
        } elsif ($key eq "ldap_overlay_syncprov_sessionlog") {
          $ldap_key="olcSpSessionlog";
        } else {
          main::logMsg(2,"LDAP overlay syncprov: Unknown key: $key");
          $rc=1;
        }
      } elsif ($key =~ /ldap_overlay_accesslog/) {
        $dn="olcOverlay={1}accesslog,olcDatabase={3}hdb,cn=config";
        if ($key eq "ldap_overlay_accesslog_logpurge") {
          $ldap_key="olcAccessLogPurge";
        } else {
          main::logMsg(2,"LDAP overlay accesslog: Unknown key: $key");
          $rc=1;
        }
      } else {
        main::logMsg(2,"LDAP overlay: Unknown key: $key");
        $rc=1;
      }
    }
  } else {
    main::logMsg(2,"LDAP: Unknown key: $key");
    $rc=1;
  }

  if ($rc) { $ldap->unbind; return $rc; }

  if (!$real_master && ($key =~ /ldap_access/ || $key =~ /ldap_overlay/)) {
    main::logMsg(2,"LDAP: Trying to modify key: $key when not a master");
    $ldap->unbind;
    return 0;
  }

  if ($key =~ /_shmkey/ && $value != 0 && $real_master) {
    my ($alt_key, $alt_value, $alt_dn, $entry);

    if ($key =~ /ldap_db_shmkey/) {
      $alt_key="ldap_accesslog_shmkey";
      $alt_dn="olcDatabase={2}hdb,cn=config";
    } else {
      $alt_key="ldap_db_shmkey";
      $alt_dn="olcDatabase={3}hdb,cn=config";
    }
    $mesg=$ldap->search(base=>$alt_dn,
                  scope=>"base",
                  filter=>'objectClass=*',
                  attrs=>[ "$ldap_key" ],
                 );
   
    $entry=$mesg->entry(0);
    $alt_value = $entry->get_value("$ldap_key");
    if ($alt_value == $value) {
      main::logMsg(2,"LDAP: Trying to set unique key value : $key:$value");
      main::logMsg(2,"LDAP: When alternate key has value   : $alt_key:$alt_value");
      main::logMsg(2,"LDAP: Values must differ if non-zero");
      $ldap->unbind;
      return 1;
    }
  }
  main::logMsg(3,"LDAP: Changing key: $key");
  $mesg = $ldap->modify(
         $dn,
         replace=>{$ldap_key=>"$value"},
  );
  if ($mesg->code) {
    main::logMsg(2,"LDAP key change failed: ".$mesg->code());
    $rc=1;
  }
  $ldap->unbind;
  return $rc;
}

1;
