#!/usr/bin/perl

use strict;
use warnings;

use Config;
use Cwd;
use Data::Dumper;
use File::Basename;
use File::Copy;
use IPC::Cmd qw/run can_run/;
use Net::Domain;
use Term::ANSIColor;

my $GLOBAL_PATH_TO_SCRIPT_FILE;
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
my $GLOBAL_BUILD_PROD_FLAG;
my $GLOBAL_BUILD_DEBUG_FLAG;


BEGIN
{
   $GLOBAL_PATH_TO_SCRIPT_FILE = Cwd::abs_path(__FILE__);
   $GLOBAL_PATH_TO_SCRIPT_DIR  = dirname($GLOBAL_PATH_TO_SCRIPT_FILE);
   $GLOBAL_PATH_TO_TOP         = dirname($GLOBAL_PATH_TO_SCRIPT_DIR);
}

chdir($GLOBAL_PATH_TO_TOP);

##############################################################################################

sub InitGlobalBuildVars()
{
   if ( -f "$GLOBAL_PATH_TO_SCRIPT_DIR/.build.last_no_ts" && $ENV{ENV_RESUME_FLAG} )
   {
      my $x = LoadProperties("$GLOBAL_PATH_TO_SCRIPT_DIR/.build.last_no_ts");

      $GLOBAL_BUILD_NO = $x->{BUILD_NO};
      $GLOBAL_BUILD_TS = $x->{BUILD_TS};
   }

   $GLOBAL_BUILD_NO ||= GetNewBuildNo();
   $GLOBAL_BUILD_TS ||= GetNewBuildTs();

   Die("You need to create the file config.build, See config.build.in for an example")
     if ( !-f "$GLOBAL_PATH_TO_SCRIPT_DIR/config.build" );

   my $build_cfg = LoadProperties("$GLOBAL_PATH_TO_SCRIPT_DIR/config.build");

   $GLOBAL_PATH_TO_BUILDS          = $build_cfg->{PATH_TO_BUILDS}          || "$GLOBAL_PATH_TO_TOP/BUILDS";
   $GLOBAL_BUILD_RELEASE           = $build_cfg->{BUILD_RELEASE}           || Die("config not specified BUILD_RELEASE");
   $GLOBAL_BUILD_RELEASE_NO        = $build_cfg->{BUILD_RELEASE_NO}        || Die("config not specified BUILD_RELEASE_NO");
   $GLOBAL_BUILD_RELEASE_CANDIDATE = $build_cfg->{BUILD_RELEASE_CANDIDATE} || Die("config not specified BUILD_RELEASE_CANDIDATE");
   $GLOBAL_BUILD_TYPE              = $build_cfg->{BUILD_TYPE}              || Die("config not specified BUILD_TYPE");
   $GLOBAL_THIRDPARTY_SERVER       = $build_cfg->{THIRDPARTY_SERVER}       || Die("config not specified THIRDPARTY_SERVER");
   $GLOBAL_BUILD_PROD_FLAG         = $build_cfg->{BUILD_PROD_FLAG}         || "true";
   $GLOBAL_BUILD_DEBUG_FLAG        = $build_cfg->{BUILD_DEBUG_FLAG}        || "false";
   $GLOBAL_BUILD_OS                = GetBuildOS();
   $GLOBAL_BUILD_ARCH              = GetBuildArch();

   $GLOBAL_BUILD_RELEASE_NO_SHORT = $GLOBAL_BUILD_RELEASE_NO =~ s/[.]//gr;
   $GLOBAL_BUILD_DIR              = "$GLOBAL_PATH_TO_BUILDS/$GLOBAL_BUILD_OS/$GLOBAL_BUILD_RELEASE-$GLOBAL_BUILD_RELEASE_NO_SHORT/${GLOBAL_BUILD_TS}_$GLOBAL_BUILD_TYPE";

   my $fmt2v = " %-35s: %s\n";

   print "=========================================================================================================\n";
   foreach my $x (`grep -o '\\<GLOBAL[_][A-Z_]*\\>' '$GLOBAL_PATH_TO_SCRIPT_FILE' | sort | uniq`)
   {
      chomp($x);
      printf( $fmt2v, $x, eval "\$$x" );
   }

   print "=========================================================================================================\n";
   foreach my $x (`grep -o '\\<[E][N][V]_[A-Z_]*\\>' '$GLOBAL_PATH_TO_SCRIPT_FILE' | sort | uniq`)
   {
      chomp($x);
      printf( $fmt2v, $x, defined $ENV{$x} ? $ENV{$x} : "(undef)" );
   }

   print "=========================================================================================================\n";
   {
      $ENV{PATH} = "$ENV{HOME}/.zm-dev-tools/bin/Sencha/Cmd/4.0.2.67:$ENV{HOME}/.zm-dev-tools/bin:$ENV{PATH}";

      my $cc    = DetectPrerequisite("cc");
      my $cpp   = DetectPrerequisite("c++");
      my $java  = DetectPrerequisite( "java", $ENV{JAVA_HOME} ? "$ENV{JAVA_HOME}/bin" : "" );
      my $javac = DetectPrerequisite( "javac", $ENV{JAVA_HOME} ? "$ENV{JAVA_HOME}/bin" : "" );
      my $mvn   = DetectPrerequisite("mvn");
      my $ant   = DetectPrerequisite("ant");
      my $ruby  = DetectPrerequisite("ruby");

      $ENV{JAVA_HOME} ||= dirname( dirname( Cwd::realpath($javac) ) );
      $ENV{PATH} = "$ENV{JAVA_HOME}/bin:$ENV{PATH}";

      printf( $fmt2v, "USING javac", "$javac (JAVA_HOME=$ENV{JAVA_HOME})" );
      printf( $fmt2v, "USING java",  $java );
      printf( $fmt2v, "USING maven", $mvn );
      printf( $fmt2v, "USING ant",   $ant );
      printf( $fmt2v, "USING cc",    $cc );
      printf( $fmt2v, "USING c++",   $cpp );
      printf( $fmt2v, "USING ruby",  $ruby );
   }

   print "=========================================================================================================\n";
   print "Press enter to proceed";
   read STDIN, $_, 1;
}

sub Prepare()
{
   RemoveTargetInDir( ".zcs-deps",   $ENV{HOME} ) if ( $ENV{ENV_CACHE_CLEAR_FLAG} );
   RemoveTargetInDir( ".ivy2/cache", $ENV{HOME} ) if ( $ENV{ENV_CACHE_CLEAR_FLAG} );

   open( FD, ">", "$GLOBAL_PATH_TO_SCRIPT_DIR/.build.last_no_ts" );
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

   for my $j_url (@TP_JARS)
   {
      if ( my $f = "$ENV{HOME}/.zcs-deps/" . basename($j_url) )
      {
         if ( !-f $f )
         {
            System("wget '$j_url' -O '$f.tmp'");
            System("mv '$f.tmp' '$f'");
         }
      }
   }
}

sub EvalFile($)
{
   my $fname = shift;

   my $file = "$GLOBAL_PATH_TO_SCRIPT_DIR/$fname";

   Die( "Error in '$file'", "$@" )
     if ( !-f $file );

   my @ENTRIES;

   eval `cat '$file'`;
   Die( "Error in '$file'", "$@" )
     if ($@);

   return \@ENTRIES;
}

sub LoadRepos()
{
   my @agg_repos = ();

   push( @agg_repos, @{ EvalFile("public_repos.pl") } );
   push( @agg_repos, @{ EvalFile("private_repos.pl") } ) if ( $GLOBAL_BUILD_TYPE eq "NETWORK" );

   return \@agg_repos;
}


sub LoadBuilds($)
{
   my $repo_list = shift;

   my @agg_builds = @{ EvalFile("global_builds.pl") };

   my %repo_hash = map { $_->{name} => 1 } @$repo_list;

   my @filtered_builds = grep { $repo_hash{ $_->{dir} =~ s/\/.*//r }; } @agg_builds;

   return \@filtered_builds;
}


sub Checkout($)
{
   my $repo_list = shift;

   for my $repo_details (@$repo_list)
   {
      Clone($repo_details);
   }
}


sub RemoveTargetInDir($$)
{
   my $target = shift;
   my $chdir  = shift;

   s/\/\/*/\//g, s/\/*$// for ( my $sane_target = $target );    #remove multiple slashes, and ending slashes, dots

   if ( $sane_target && $chdir && -d $chdir )
   {
      eval
      {
         Run( cd => $chdir, child => sub { System( "rm", "-rf", $sane_target ); } );
      };
   }
}


sub Build($)
{
   my $repo_list = shift;

   my @ALL_BUILDS = @{ LoadBuilds($repo_list) };

   my @ant_attributes = (
      "-Ddebug=${GLOBAL_BUILD_DEBUG_FLAG}",
      "-Dis-production=${GLOBAL_BUILD_PROD_FLAG}",
      "-Dzimbra.buildinfo.platform=${GLOBAL_BUILD_OS}",
      "-Dzimbra.buildinfo.version=${GLOBAL_BUILD_RELEASE_NO}_${GLOBAL_BUILD_RELEASE_CANDIDATE}_${GLOBAL_BUILD_NO}",
      "-Dzimbra.buildinfo.type=${GLOBAL_BUILD_TYPE}",
      "-Dzimbra.buildinfo.release=${GLOBAL_BUILD_TS}",
      "-Dzimbra.buildinfo.date=${GLOBAL_BUILD_TS}",
      "-Dzimbra.buildinfo.host=@{[Net::Domain::hostfqdn]}",
      "-Dzimbra.buildinfo.buildnum=${GLOBAL_BUILD_RELEASE_NO}",
   );

   my $cnt = 0;
   for my $build_info (@ALL_BUILDS)
   {
      ++$cnt;

      if ( my $dir = $build_info->{dir} )
      {
         my $target_dir = "$GLOBAL_BUILD_DIR/$dir";

         next
           unless ( !defined $ENV{ENV_BUILD_INCLUDE} || grep { $dir =~ /$_/ } split( ",", $ENV{ENV_BUILD_INCLUDE} ) );

         RemoveTargetInDir( $dir, $GLOBAL_BUILD_DIR )
           if ( ( $ENV{ENV_FORCE_REBUILD} && grep { $dir =~ /$_/ } split( ",", $ENV{ENV_FORCE_REBUILD} ) ) );

         print "=========================================================================================================\n";
         print color('bright_blue') . "BUILDING: $dir ($cnt of " . scalar(@ALL_BUILDS) . ")" . color('reset') . "\n";
         print "\n";

         if ( $ENV{ENV_RESUME_FLAG} && -f "$target_dir/.built.$GLOBAL_BUILD_TS" )
         {
            print color('bright_yellow') . "SKIPPING... [TO REBUILD REMOVE '$target_dir']" . color('reset') . "\n";
            print "=========================================================================================================\n";
            print "\n";
         }
         else
         {
            unlink glob "$target_dir/.built.*";

            Run(
               cd    => $dir,
               child => sub {

                  my $abs_dir = Cwd::abs_path();

                  if ( my $ant_targets = $build_info->{ant_targets} )
                  {
                     eval { System( "ant", "clean" ) if ( !$ENV{ENV_SKIP_CLEAN_FLAG} ); };

                     System( "ant", @ant_attributes, @$ant_targets );
                  }

                  if ( my $mvn_targets = $build_info->{mvn_targets} )
                  {
                     eval { System( "mvn", "clean" ) if ( !$ENV{ENV_SKIP_CLEAN_FLAG} ); };

                     System( "mvn", @$mvn_targets );
                  }

                  if ( my $make_targets = $build_info->{make_targets} )
                  {
                     eval { System( "make", "clean" ) if ( !$ENV{ENV_SKIP_CLEAN_FLAG} ); };

                     System( "make", @$make_targets );
                  }

                  if ( my $stage_cmd = $build_info->{stage_cmd} )
                  {
                     &$stage_cmd
                  }

                  if ( !exists $build_info->{partial} )
                  {
                     system( "mkdir", "-p", "$target_dir" );
                     System( "touch", "$target_dir/.built.$GLOBAL_BUILD_TS" );
                  }
               },
            );

            print "\n";
            print "=========================================================================================================\n";
            print "\n";
         }
      }
   }

   Run(
      cd    => "$GLOBAL_PATH_TO_SCRIPT_DIR",
      child => sub {
         System("rsync -az --delete . $GLOBAL_BUILD_DIR/zm-build");
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-build/$GLOBAL_BUILD_ARCH");

         my @ALL_PACKAGES = ();
         push( @ALL_PACKAGES, @{ EvalFile("public_packages.pl") } );
         push( @ALL_PACKAGES, @{ EvalFile("private_packages.pl") } ) if ( $GLOBAL_BUILD_TYPE eq "NETWORK" );
         push( @ALL_PACKAGES, "zcs-bundle" );

         for my $package_script (@ALL_PACKAGES)
         {
            if ( !defined $ENV{ENV_PACKAGE_INCLUDE} || grep { $package_script =~ /$_/ } split( ",", $ENV{ENV_PACKAGE_INCLUDE} ) )
            {
               System(
                  "  releaseNo='$GLOBAL_BUILD_RELEASE_NO' \\
                     releaseCandidate='$GLOBAL_BUILD_RELEASE_CANDIDATE' \\
                     branch='$GLOBAL_BUILD_RELEASE-$GLOBAL_BUILD_RELEASE_NO_SHORT' \\
                     buildNo='$GLOBAL_BUILD_NO' \\
                     os='$GLOBAL_BUILD_OS' \\
                     buildType='$GLOBAL_BUILD_TYPE' \\
                     repoDir='$GLOBAL_BUILD_DIR' \\
                     arch='$GLOBAL_BUILD_ARCH' \\
                     buildTimeStamp='$GLOBAL_BUILD_TS' \\
                     buildLogFile='$GLOBAL_BUILD_DIR/logs/build.log' \\
                     zimbraThirdPartyServer='$GLOBAL_THIRDPARTY_SERVER' \\
                        bash $GLOBAL_PATH_TO_SCRIPT_DIR/scripts/packages/$package_script.sh
                  "
               );
            }
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

   my $file = "$GLOBAL_PATH_TO_SCRIPT_DIR/.build.number";

   if ( -f $file )
   {
      open( FD1, "<", $file );
      $line = <FD1>;
      close(FD1);

      $line += 1;
   }

   open( FD2, ">", $file );
   printf( FD2 "%s\n", $line );
   close(FD2);

   return $line;
}

sub GetNewBuildTs()
{
   chomp( my $x = `date +'%Y%m%d%H%M%S'` );

   return $x;
}

sub GetBuildOS()
{
   chomp( my $r = `$GLOBAL_PATH_TO_SCRIPT_DIR/rpmconf/Build/get_plat_tag.sh` );

   return $r
     if ($r);

   Die("Unknown OS");
}

sub GetBuildArch()    # FIXME - use standard mechanism
{
   chomp( my $PROCESSOR_ARCH = `uname -m | grep -o 64` );

   my $b_os = GetBuildOS();

   return "amd" . $PROCESSOR_ARCH
     if ( $b_os =~ /UBUNTU/ );

   return "x86_" . $PROCESSOR_ARCH
     if ( $b_os =~ /RHEL/ || $b_os =~ /CENTOS/ );

   Die("Unknown Arch");
}


##############################################################################################

sub Clone($)
{
   my $repo_details = shift;

   my $repo_name   = $repo_details->{name};
   my $repo_branch = $repo_details->{branch};

   my $repo_dir = "$GLOBAL_PATH_TO_TOP/$repo_name";

   if ( !-d $repo_dir )
   {
      if ( $repo_name =~ /zimbra-package-stub/ )
      {
         System( "git", "clone", "https://github.com/Zimbra/zimbra-package-stub.git", $repo_dir );
      }
      elsif ( $repo_name =~ /junixsocket/ )
      {
         System( "git", "clone", "-b", "$repo_branch", "https://github.com/kohlschutter/junixsocket.git", $repo_dir );
      }
      else
      {
         System( "git", "clone", "-b", $repo_branch, "ssh://git\@stash.corp.synacor.com:7999/zimbra/$repo_name.git", $repo_dir );
      }

      RemoveTargetInDir( $repo_name, $GLOBAL_BUILD_DIR );
   }
   else
   {
      if ( !defined $ENV{ENV_GIT_UPDATE_INCLUDE} || grep { $repo_name =~ /$_/ } split( ",", $ENV{ENV_GIT_UPDATE_INCLUDE} ) )
      {
         return
           if ( $repo_name =~ /junixsocket/ );    #FIXME - some issue with branch junixsocket-parent-2.0.4"

         print "\n";
         my $z = System("cd '$repo_dir' && git pull origin");

         if ( "@{$z->{out}}" !~ /Already up-to-date/ )
         {
            RemoveTargetInDir( $repo_name, $GLOBAL_BUILD_DIR );
         }
      }
   }
}

sub System(@)
{
   my $cmd_str = "@_";

   print color('bright_green') . "#: pwd=@{[Cwd::getcwd()]}" . color('reset') . "\n";
   print color('bright_green') . "#: $cmd_str" . color('reset') . "\n";

   $! = 0;
   my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) = run( command => \@_, verbose => 1 );

   Die( "cmd='$cmd_str'", $error_message )
     if ( !$success );

   return { msg => $error_message, out => $stdout_buf, err => $stderr_buf };
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

   open( FD, "<", "$f" ) || Die( "In open", "file='$f'" );

   chomp( my @x = <FD> );
   close(FD);

   return \@x;
}


sub DetectPrerequisite($;$)
{
   my $util_name = shift;
   my $additional_path = shift || "";

   chomp( my $detected_util = `PATH="$additional_path:\$PATH" \\which "$util_name" 2>/dev/null | sed -e 's,//*,/,g'` );

   return $detected_util
     if ($detected_util);

   Die("Prerequisite '$util_name' missing in PATH");
}


sub Run(%)
{
   my %args  = (@_);
   my $chdir = $args{cd};
   my $child = $args{child};

   my $child_pid = fork();

   Die("FAILURE while forking")
     if ( !defined $child_pid );

   if ( $child_pid != 0 )    # parent
   {
      local $?;

      while ( waitpid( $child_pid, 0 ) == -1 ) { }

      Die( "child $child_pid died", einfo($?) )
        if ( $? != 0 );
   }
   else
   {
      Die( "chdir to '$chdir' failed", einfo($?) )
        if ( $chdir && !chdir($chdir) );

      $! = 0;
      &$child;
      exit(0);
   }
}

sub einfo()
{
   my @SIG_NAME = split( / /, $Config{sig_name} );

   return "ret=" . ( $? >> 8 ) . ( ( $? & 127 ) ? ", sig=SIG" . $SIG_NAME[ $? & 127 ] : "" );
}

sub Die($;$)
{
   my $msg  = shift;
   my $info = shift || "";
   my $err  = "$!";

   print "\n";
   print "\n";
   print "=========================================================================================================\n";
   print color('red') . "FAILURE MSG" . color('reset') . " : $msg\n";
   print color('red') . "SYSTEM ERR " . color('reset') . " : $err\n"  if ($err);
   print color('red') . "EXTRA INFO " . color('reset') . " : $info\n" if ($info);
   print "\n";
   print "=========================================================================================================\n";
   print color('red');
   print "--Stack Trace--\n";
   my $i = 1;

   while ( ( my @call_details = ( caller( $i++ ) ) ) )
   {
      print $call_details[1] . ":" . $call_details[2] . " called from " . $call_details[3] . "\n";
   }
   print color('reset');
   print "\n";
   print "=========================================================================================================\n";

   die "END";
}

##############################################################################################

sub main()
{
   InitGlobalBuildVars();

   my $all_repos = LoadRepos();

   Prepare();

   Checkout($all_repos);

   Build($all_repos);
}

main();

##############################################################################################
