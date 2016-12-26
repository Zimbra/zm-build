#!/usr/bin/perl

use strict;

use File::Basename;
use Data::Dumper;
use Cwd;

my $GLOBAL_PATH_TO_SCRIPT;
my $GLOBAL_PATH_TO_SCRIPT_DIR;
my $GLOBAL_PATH_TO_TOP;
my $GLOBAL_PATH_TO_BUILDS;

my $GLOBAL_BUILD_NO;
my $GLOBAL_BUILD_TS;
my $GLOBAL_BUILD_DIR;
my $GLOBAL_BUILD_OS;
my $GLOBAL_BUILD_RELEASE;
my $GLOBAL_BUILD_RELEASE_NO;
my $GLOBAL_BUILD_RELEASE_NO_SHORT;
my $GLOBAL_BUILD_RELEASE_CANDIDATE;
my $GLOBAL_BUILD_TYPE;
my $GLOBAL_BUILD_ARCH;
my $GLOBAL_THIRDPARTY_SERVER;


BEGIN
{
   $GLOBAL_PATH_TO_SCRIPT     = Cwd::abs_path(__FILE__);
   $GLOBAL_PATH_TO_SCRIPT_DIR = dirname($GLOBAL_PATH_TO_SCRIPT);
   $GLOBAL_PATH_TO_TOP        = dirname($GLOBAL_PATH_TO_SCRIPT_DIR);
}

chdir($GLOBAL_PATH_TO_TOP);

##############################################################################################

my @GLOBAL_REPOS = (
   { name => "ant-1.7.0-ziputil-patched",           branch => "dev",             user => "zimbra" },
   { name => "ant-tar-patched",                     branch => "dev",             user => "zimbra" },
   { name => "ical4j-0.9.16-patched",               branch => "dev",             user => "zimbra" },
   { name => "nekohtml-1.9.13",                     branch => "dev",             user => "zimbra" },
   { name => "zm-2fa-admin-zimlet",                 branch => "master",          user => "zimbra" },
   { name => "zm-admin-console",                    branch => "dev",             user => "zimbra" },
   { name => "zm-ajax",                             branch => "dev",             user => "zimbra" },
   { name => "zm-amavis",                           branch => "master",          user => "zimbra" },
   { name => "zm-archive-admin-zimlet",             branch => "dev",             user => "zimbra" },
   { name => "zm-archive-store",                    branch => "dev",             user => "zimbra" },
   { name => "zm-archive-utils",                    branch => "dev",             user => "zimbra" },
   { name => "zm-aspell",                           branch => "master",          user => "zimbra" },
   { name => "zm-backup-restore-admin-zimlet",      branch => "master",          user => "zimbra" },
   { name => "zm-backup-store",                     branch => "dev",             user => "zimbra" },
   { name => "zm-backup-utilities",                 branch => "master",          user => "zimbra" },
   { name => "zm-build",                            branch => "dev",             user => "zimbra" },    # itself
   { name => "zm-bulkprovision-admin-zimlet",       branch => "master",          user => "zimbra" },
   { name => "zm-bulkprovision-store",              branch => "master",          user => "zimbra" },
   { name => "zm-certificate-manager-admin-zimlet", branch => "master",          user => "zimbra" },
   { name => "zm-certificate-manager-store",        branch => "master",          user => "zimbra" },
   { name => "zm-charset",                          branch => "dev",             user => "zimbra" },
   { name => "zm-clam-scanner-store",               branch => "dev",             user => "zimbra" },
   { name => "zm-client",                           branch => "dev",             user => "zimbra" },
   { name => "zm-clientuploader-admin-zimlet",      branch => "master",          user => "zimbra" },
   { name => "zm-clientuploader-store",             branch => "master",          user => "zimbra" },
   { name => "zm-common",                           branch => "dev",             user => "zimbra" },
   { name => "zm-convertd-admin-zimlet",            branch => "master",          user => "zimbra" },
   { name => "zm-convertd-native",                  branch => "master",          user => "zimbra" },
   { name => "zm-convertd-store",                   branch => "master",          user => "zimbra" },    # dup
   { name => "zm-core-utils",                       branch => "master",          user => "zimbra" },
   { name => "zm-db-conf",                          branch => "master",          user => "zimbra" },
   { name => "zm-delegated-admin-zimlet",           branch => "master",          user => "zimbra" },
   { name => "zm-dnscache",                         branch => "master",          user => "zimbra" },
   { name => "zm-docs",                             branch => "master",          user => "zimbra" },
   { name => "zm-downloads",                        branch => "master",          user => "zimbra" },
   { name => "zm-ews-common",                       branch => "dev",             user => "zimbra" },
   { name => "zm-ews-store",                        branch => "dev",             user => "zimbra" },
   { name => "zm-ews-stub",                         branch => "dev",             user => "zimbra" },
   { name => "zm-freebusy-provider-store",          branch => "judaspriest-870", user => "zimbra" },
   { name => "zm-freshclam",                        branch => "master",          user => "zimbra" },
   { name => "zm-help",                             branch => "master",          user => "zimbra" },
   { name => "zm-helptooltip-zimlet",               branch => "master",          user => "zimbra" },
   { name => "zm-hsm",                              branch => "master",          user => "zimbra" },
   { name => "zm-hsm-admin-zimlet",                 branch => "master",          user => "zimbra" },
   { name => "zm-hsm-store",                        branch => "master",          user => "zimbra" },
   { name => "zm-jython",                           branch => "master",          user => "zimbra" },
   { name => "zm-ldap-utilities",                   branch => "master",          user => "zimbra" },
   { name => "zm-ldap-utils-store",                 branch => "master",          user => "zimbra" },
   { name => "zm-license-admin-zimlet",             branch => "dev",             user => "zimbra" },
   { name => "zm-license-store",                    branch => "dev",             user => "zimbra" },
   { name => "zm-license-tools",                    branch => "dev",             user => "zimbra" },
   { name => "zm-licenses",                         branch => "master",          user => "zimbra" },
   { name => "zm-milter",                           branch => "dev",             user => "zimbra" },
   { name => "zm-mobile-sync-admin-zimlet",         branch => "master",          user => "zimbra" },
   { name => "zm-mta",                              branch => "master",          user => "zimbra" },
   { name => "zm-native",                           branch => "master",          user => "zimbra" },
   { name => "zm-network-build",                    branch => "dev",             user => "zimbra" },
   { name => "zm-network-store",                    branch => "master",          user => "zimbra" },    # dup
   { name => "zm-network-web-client",               branch => "master",          user => "zimbra" },
   { name => "zm-nginx-conf",                       branch => "master",          user => "zimbra" },
   { name => "zm-nginx-lookup-store",               branch => "master",          user => "zimbra" },
   { name => "zm-openid-consumer-store",            branch => "dev",             user => "zimbra" },
   { name => "zm-openoffice-store",                 branch => "dev",             user => "zimbra" },
   { name => "zm-postfix",                          branch => "master",          user => "zimbra" },
   { name => "zm-proxy-config-admin-zimlet",        branch => "master",          user => "zimbra" },
   { name => "zm-saml-consumer-store",              branch => "master",          user => "zimbra" },
   { name => "zm-smime-applet",                     branch => "master",          user => "zimbra" },
   { name => "zm-smime-cert-admin-zimlet",          branch => "master",          user => "zimbra" },
   { name => "zm-soap",                             branch => "dev",             user => "zimbra" },
   { name => "zm-store",                            branch => "dev",             user => "zimbra" },
   { name => "zm-store-conf",                       branch => "dev",             user => "zimbra" },
   { name => "zm-sync-client",                      branch => "dev",             user => "zimbra" },
   { name => "zm-sync-common",                      branch => "dev",             user => "zimbra" },
   { name => "zm-sync-store",                       branch => "dev",             user => "zimbra" },
   { name => "zm-sync-tools",                       branch => "dev",             user => "zimbra" },
   { name => "zm-taglib",                           branch => "master",          user => "zimbra" },
   { name => "zm-timezones",                        branch => "master",          user => "zimbra" },
   { name => "zm-touch-client",                     branch => "master",          user => "zimbra" },
   { name => "zm-twofactorauth-store",              branch => "dev",             user => "zimbra" },
   { name => "zm-uc-admin-zimlets",                 branch => "master",          user => "zimbra" },
   { name => "zm-ucconfig-admin-zimlet",            branch => "master",          user => "zimbra" },
   { name => "zm-versioncheck-admin-zimlet",        branch => "master",          user => "zimbra" },
   { name => "zm-versioncheck-store",               branch => "master",          user => "zimbra" },
   { name => "zm-versioncheck-utilities",           branch => "master",          user => "zimbra" },
   { name => "zm-viewmail-admin-zimlet",            branch => "master",          user => "zimbra" },
   { name => "zm-voice-cisco-store",                branch => "dev",             user => "zimbra" },
   { name => "zm-voice-mitel-store",                branch => "dev",             user => "zimbra" },
   { name => "zm-voice-store",                      branch => "dev",             user => "zimbra" },
   { name => "zm-web-client",                       branch => "dev",             user => "zimbra" },
   { name => "zm-webclient-portal-example",         branch => "master",          user => "zimbra" },
   { name => "zm-windows-comp",                     branch => "dev",             user => "zimbra" },
   { name => "zm-xmbxsearch-store",                 branch => "dev",             user => "zimbra" },
   { name => "zm-xmbxsearch-zimlet",                branch => "dev",             user => "zimbra" },
   { name => "zm-zcs",                              branch => "master",          user => "zimbra" },
   { name => "zm-zcs-lib",                          branch => "dev",             user => "zimbra" },
   { name => "zm-zimlets",                          branch => "dev",             user => "zimbra" },
   { name => "zm-libnative",                        branch => "dev",             user => "zimbra" },
   { name => "zm-launcher",                         branch => "dev",             user => "zimbra" },
   { name => "zm-jetty-conf",                       branch => "dev",             user => "zimbra" },
);

##############################################################################################

main();

##############################################################################################

sub main()
{
   InitGlobalBuildVars();
   Prepare();
   Checkout();
   Build();
}

sub InitGlobalBuildVars()
{
   if ( -f "/tmp/last.build_no_ts" && $ENV{ENV_RESUME_FLAG} )
   {
      my $x = LoadProperties("/tmp/last.build_no_ts");

      $GLOBAL_BUILD_NO = $x->{BUILD_NO};
      $GLOBAL_BUILD_TS = $x->{BUILD_TS};
   }

   $GLOBAL_BUILD_NO ||= GetNewBuildNo();
   $GLOBAL_BUILD_TS ||= GetNewBuildTs();

   my $build_cfg = LoadProperties("$GLOBAL_PATH_TO_SCRIPT_DIR/build.config");

   $GLOBAL_PATH_TO_BUILDS          = $build_cfg->{PATH_TO_BUILDS}          || "$GLOBAL_PATH_TO_TOP/BUILDS";
   $GLOBAL_BUILD_RELEASE           = $build_cfg->{BUILD_RELEASE}           || die "not specified BUILD_RELEASE";
   $GLOBAL_BUILD_RELEASE_NO        = $build_cfg->{BUILD_RELEASE_NO}        || die "not specified BUILD_RELEASE_NO";
   $GLOBAL_BUILD_RELEASE_CANDIDATE = $build_cfg->{BUILD_RELEASE_CANDIDATE} || die "not specified BUILD_RELEASE_CANDIDATE";
   $GLOBAL_BUILD_TYPE              = $build_cfg->{BUILD_TYPE}              || die "not specified BUILD_TYPE";
   $GLOBAL_THIRDPARTY_SERVER       = $build_cfg->{THIRDPARTY_SERVER}       || die "not specified THIRDPARTY_SERVER";
   $GLOBAL_BUILD_OS                = GetBuildOS();
   $GLOBAL_BUILD_ARCH              = GetBuildArch();

   s/[.]//g for ( $GLOBAL_BUILD_RELEASE_NO_SHORT = $GLOBAL_BUILD_RELEASE_NO );

   $GLOBAL_BUILD_DIR = "$GLOBAL_PATH_TO_BUILDS/$GLOBAL_BUILD_OS/$GLOBAL_BUILD_RELEASE-$GLOBAL_BUILD_RELEASE_NO_SHORT/${GLOBAL_BUILD_TS}_$GLOBAL_BUILD_TYPE";

   print "=========================================================================================================\n";
   print "BUILD OS                : $GLOBAL_BUILD_OS\n";
   print "BUILD ARCH              : $GLOBAL_BUILD_ARCH\n";
   print "BUILD NO                : $GLOBAL_BUILD_NO\n";
   print "BUILD TS                : $GLOBAL_BUILD_TS\n";
   print "BUILD TYPE              : $GLOBAL_BUILD_TYPE\n";
   print "BUILD RELEASE           : $GLOBAL_BUILD_RELEASE\n";
   print "BUILD RELEASE NO        : $GLOBAL_BUILD_RELEASE_NO\n";
   print "BUILD RELEASE CANDIDATE : $GLOBAL_BUILD_RELEASE_CANDIDATE\n";
   print "=========================================================================================================\n";

   $ENV{ENV_PACKAGE_EXCLUDE} = '.*' if ( $ENV{ENV_PACKAGE_INCLUDE} );
   $ENV{ENV_BUILD_EXCLUDE}   = '.*' if ( $ENV{ENV_BUILD_INCLUDE} );

   foreach my $x (`grep -o '\\<[E][N][V]_[A-Z_]*\\>' $GLOBAL_PATH_TO_SCRIPT | sort | uniq`)
   {
      chomp($x);
      printf( "%-24s: $ENV{$x}\n", $x );
   }

   print "=========================================================================================================\n";
   print "PATH TO BUILDS          : $GLOBAL_PATH_TO_BUILDS\n";
   print "BUILD DIR               : $GLOBAL_BUILD_DIR\n";
   print "=========================================================================================================\n";
   print "Press enter to proceed";
   my $x;
   read STDIN, $x, 1;
}

sub Prepare()
{
   #system("rm", "-rf", "$ENV{HOME}/.zcs-deps");
   #system("rm", "-rf", "$ENV{HOME}/.ivy2/cache");

   open( FD, ">", "/tmp/last.build_no_ts" );
   print FD "BUILD_NO=$GLOBAL_BUILD_NO\n";
   print FD "BUILD_TS=$GLOBAL_BUILD_TS\n";
   close(FD);

   System( "mkdir", "-p", "$GLOBAL_BUILD_DIR" );
   System( "mkdir", "-p", "$GLOBAL_BUILD_DIR/logs" );
   System( "mkdir", "-p", "$ENV{HOME}/.zcs-deps" );
   System( "mkdir", "-p", "$ENV{HOME}/.ivy2/cache" );


   my @TP_JARS = (
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/ant-1.7.0-ziputil-patched.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/ant-contrib-1.0b1.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/ews_2010-1.0.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/jruby-complete-1.6.3.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/plugin.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/servlet-api-3.1.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/unboundid-ldapsdk-2.3.5-se.jar",
      "http://$GLOBAL_THIRDPARTY_SERVER/ZimbraThirdParty/third-party-jars/zimbrastore-test-1.0.jar",
   );

   for my $j_url ( @TP_JARS )
   {
      if( my $f = "$ENV{HOME}/.zcs-deps/" . basename($j_url) )
      {
         if( ! -f $f )
         {
            System("wget '$j_url' -O '$f.tmp'");
            System("mv '$f.tmp' '$f'");
         }
      }
   }
}

sub Checkout()
{
   if ( !-d "zimbra-package-stub" )
   {
      System( "git", "clone", "https://github.com/Zimbra/zimbra-package-stub.git" );
   }

   for my $repo_details (@GLOBAL_REPOS)
   {
      Clone($repo_details);
   }
}

sub Build()
{
   my @GLOBAL_BUILDS;
   eval `cat $GLOBAL_PATH_TO_TOP/zm-build/global_builds.pl`;
   die "FAILURE in global_builds.pl, (info=$!, err=$@)\n" if ($@);

   for my $build_info (@GLOBAL_BUILDS)
   {
      if ( my $dir = $build_info->{dir} )
      {
         next
           if (
            !( $ENV{ENV_BUILD_INCLUDE} && grep { $build_info->{dir} =~ /$_/ } split( ",", $ENV{ENV_BUILD_INCLUDE} ) )
            && ( $ENV{ENV_BUILD_EXCLUDE} && grep { $build_info->{dir} =~ /$_/ } split( ",", $ENV{ENV_BUILD_EXCLUDE} ) )
           );

         print "=========================================================================================================\n";
         print "BUILDING: $build_info->{dir}\n";
         print "\n";

         Run(
            cd   => $dir,
            call => sub {

               my $abs_dir = Cwd::abs_path();

               if ( my $ant_targets = $build_info->{ant_targets} )
               {
                  my $ANT = $ENV{ENV_ANT_OVERRIDE_CMD} || "ant";

                  System( $ANT, "clean" )
                    if ( $ENV{ENV_ANT_DO_CLEAN_FLAG} || $build_info->{clean_flag} );

                  System( $ANT, @$ant_targets );
               }

               if ( my $stage_cmd = $build_info->{stage_cmd} )
               {
                  &$stage_cmd
               }
            },
         );

         print "\n";
         print "=========================================================================================================\n";
         print "\n";
      }
   }

   Run(
      cd   => "zm-build",
      call => sub {
         System("(cd .. && rsync -az --delete zm-build $GLOBAL_BUILD_DIR/)");
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-build/$GLOBAL_BUILD_ARCH");

         my @PACKAGE_LIST = (
            "zimbra-snmp",
            "zimbra-spell",
            "zimbra-logger",
            "zimbra-dnscache",
            "zimbra-apache",
            "zimbra-mta",
            "zimbra-proxy",
            "zimbra-archiving",
            "zimbra-convertd",
            "zimbra-store",
            "zimbra-core",
         );

         for my $package_script (@PACKAGE_LIST)
         {
            next
              if (
               !( $ENV{ENV_PACKAGE_INCLUDE} && grep { $package_script =~ /$_/ } split( ",", $ENV{ENV_PACKAGE_INCLUDE} ) )
               && ( $ENV{ENV_PACKAGE_EXCLUDE} && grep { $package_script =~ /$_/ } split( ",", $ENV{ENV_PACKAGE_EXCLUDE} ) )
              );

            System(
               "  release='$GLOBAL_BUILD_RELEASE_NO.$GLOBAL_BUILD_RELEASE_CANDIDATE' \\
                  branch='$GLOBAL_BUILD_RELEASE-$GLOBAL_BUILD_RELEASE_NO_SHORT' \\
                  buildNo='$GLOBAL_BUILD_NO' \\
                  os='$GLOBAL_BUILD_OS' \\
                  buildType='$GLOBAL_BUILD_TYPE' \\
                  repoDir='$GLOBAL_BUILD_DIR' \\
                  arch='$GLOBAL_BUILD_ARCH' \\
                  buildTimeStamp='$GLOBAL_BUILD_TS' \\
                  buildLogFile='$GLOBAL_BUILD_DIR/logs/build.log' \\
                  zimbraThirdPartyServer='$GLOBAL_THIRDPARTY_SERVER' \\
                     bash $GLOBAL_PATH_TO_TOP/zm-build/scripts/packages/$package_script.sh
               "
            );
         }
      },
   );

   print "\n";
   print "=========================================================================================================\n";
   print "\n";
}

sub GetNewBuildNo()
{
   my $line = 1000;

   if ( -f "/tmp/build_counter.txt" )
   {
      open( FD1, "<", "/tmp/build_counter.txt" );
      $line = <FD1>;
      close(FD1);

      $line += 2;
   }

   open( FD2, ">", "/tmp/build_counter.txt" );
   printf( FD2 "%s\n", $line );
   close(FD2);

   return $line;
}

sub GetNewBuildTs()
{
   chomp( my $x = `date +'%Y%m%d%H%M%S'` );

   return $x;
}

sub GetBuildOS()    # FIXME - use standard mechanism
{
   chomp( my $PROCESSOR_ARCH = `uname -m | grep -o 64` );
   if ( -f "/etc/lsb-release" )
   {
      my $h = LoadProperties("/etc/lsb-release");

      my $DISTRIB_ID = uc( $h->{DISTRIB_ID} );

      s/[.].*// for ( my $DISTRIB_RELEASE = $h->{DISTRIB_RELEASE} );

      return $DISTRIB_ID . $DISTRIB_RELEASE . "_" . $PROCESSOR_ARCH;
   }
   elsif ( -f "/etc/redhat-release" )
   {
      my @x = split( / /, SlurpFile("/etc/redhat-release") );

      my $DISTRIB_ID = uc( $x[0] );
      s/[.].*// for ( my $DISTRIB_RELEASE = $x[3] );

      return $DISTRIB_ID . $DISTRIB_RELEASE . "_" . $PROCESSOR_ARCH;
   }

   die "Unknown OS";
}

sub GetBuildArch()    # FIXME - use standard mechanism
{
   chomp( my $PROCESSOR_ARCH = `uname -m | grep -o 64` );

   my $b_os = GetBuildOS();

   return "amd" . $PROCESSOR_ARCH
     if ( $b_os =~ /UBUNTU/ );

   return "x86_" . $PROCESSOR_ARCH
     if ( $b_os =~ /RHEL/ || $b_os =~ /CENTOS/ );

   die "Unknown Arch"
}


##############################################################################################

sub Clone($)
{
   my $repo_details = shift;

   my $repo_name   = $repo_details->{name};
   my $repo_user   = $repo_details->{user};
   my $repo_branch = $repo_details->{branch};

   if ( !-d $repo_name )
   {
      System( "git", "clone", "-b", $repo_branch, "ssh://git\@stash.corp.synacor.com:7999/$repo_user/$repo_name.git" );
   }
}

sub System(@)
{
   print "#: @_            #(pwd=" . Cwd::getcwd() . ")\n";

   my $x = system "@_";

   die "FAILURE in system, (info=$!, cmd='@_', ret=$x)\n"
     if ( $x != 0 );
}


sub LoadProperties($)
{
   my $f = shift;

   my $x = SlurpFile($f);

   my %h = map { split( /\s*=\s*/, $_, 2 ) } @$x;

   return \%h;
}


sub SlurpFile($)
{
   my $f = shift;

   open( FD, "<", "$f" ) || die "FAILURE in open, (info=$!, file='$f')\n";

   chomp( my @x = <FD> );
   close(FD);

   return \@x;
}


sub Run(%)
{
   my %args  = (@_);
   my $chdir = $args{cd};
   my $call  = $args{call};

   my $child_pid = fork();

   die "FAILURE while forking, (info=$!)\n"
     if ( !defined $child_pid );

   if ( $child_pid != 0 )    # parent
   {
      while ( waitpid( $child_pid, 0 ) == -1 ) { }
      my $x = $?;

      die "FAILURE in run, (info=$!, ret=$x)\n"
        if ( $x != 0 );
   }
   else
   {
      chdir($chdir)
        if ($chdir);

      my $ret = &$call;
      exit($ret);
   }
}
