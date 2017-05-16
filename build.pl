#!/usr/bin/perl

use strict;
use warnings;

use Config;
use Cwd;
use Data::Dumper;
use File::Basename;
use File::Copy;
use Getopt::Long;
use IPC::Cmd qw/run can_run/;
use Net::Domain;
use Term::ANSIColor;

my $GLOBAL_PATH_TO_SCRIPT_FILE;
my $GLOBAL_PATH_TO_SCRIPT_DIR;
my $GLOBAL_PATH_TO_TOP;

#FIXME - remove following $GLOBAL_BUILD_*, and instead use the hash %CFG every place

my $GLOBAL_BUILD_ARTIFACTS_BASE_DIR;
my $GLOBAL_BUILD_SOURCES_BASE_DIR;
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
my $GLOBAL_BUILD_THIRDPARTY_SERVER;
my $GLOBAL_BUILD_PROD_FLAG;
my $GLOBAL_BUILD_DEBUG_FLAG;
my $GLOBAL_BUILD_DEV_TOOL_BASE_DIR;
my $GLOBAL_BUILD_RELEASE_NO_MAJOR;
my $GLOBAL_BUILD_RELEASE_NO_MINOR;
my $GLOBAL_BUILD_RELEASE_NO_MICRO;

my %CFG = ();

BEGIN
{
   $GLOBAL_PATH_TO_SCRIPT_FILE = Cwd::abs_path(__FILE__);
   $GLOBAL_PATH_TO_SCRIPT_DIR  = dirname($GLOBAL_PATH_TO_SCRIPT_FILE);
   $GLOBAL_PATH_TO_TOP         = dirname($GLOBAL_PATH_TO_SCRIPT_DIR);
}

chdir($GLOBAL_PATH_TO_TOP);

##############################################################################################

sub LoadConfiguration($)
{
   my $args = shift;

   my $cfg_name    = $args->{name};
   my $cmd_hash    = $args->{hash_src};
   my $default_sub = $args->{default_sub};

   my @cfg_list = ();
   push( @cfg_list, "config.build" );
   push( @cfg_list, ".build.last_no_ts" ) if ( $ENV{ENV_RESUME_FLAG} );

   my $val;
   my $src;

   if ( !defined $val )
   {
      y/A-Z_/a-z-/ foreach ( my $cmd_name = $cfg_name );

      if ( $cmd_hash && exists $cmd_hash->{$cmd_name} )
      {
         $val = $cmd_hash->{$cmd_name};
         $src = "cmdline";
      }
   }

   if ( !defined $val )
   {
      foreach my $file_basename (@cfg_list)
      {
         my $file = "$GLOBAL_PATH_TO_SCRIPT_DIR/$file_basename";
         my $hash = LoadProperties($file)
           if ( -f $file );

         if ( $hash && exists $hash->{$cfg_name} )
         {
            $val = $hash->{$cfg_name};
            $src = $file_basename;
            last;
         }
      }
   }

   if ( !defined $val )
   {
      if ($default_sub)
      {
         $val = &$default_sub($cfg_name);
         $src = "default";
      }
   }

   if ( defined $val )
   {
      if ( ref($val) eq "HASH" )
      {
         foreach my $k ( keys %{$val} )
         {
            $CFG{$cfg_name}{$k} = ${$val}{$k};

            printf( " %-25s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", $k . " => " . ${$val}{$k} );
         }
      }
      else
      {
         if ( $cfg_name =~ /BUILD_/ )
         {
            eval "\$GLOBAL_${cfg_name} = \"$val\"";    #FIXME - remove eval and instead use the hash %CFG every place
         }

         $CFG{$cfg_name} = $val;

         printf( " %-25s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", $val );
      }
   }
}

sub InitGlobalBuildVars()
{
   {
      my $build_dir_func = sub {
         return "$GLOBAL_BUILD_ARTIFACTS_BASE_DIR/$GLOBAL_BUILD_OS/$GLOBAL_BUILD_RELEASE-$GLOBAL_BUILD_RELEASE_NO_SHORT/${GLOBAL_BUILD_TS}_$GLOBAL_BUILD_TYPE";
      };

      my %cmd_hash = ();

      my @cmd_args = (
         { name => "BUILD_NO",                 type => "=i",  hash_src => \%cmd_hash, default_sub => sub { return GetNewBuildNo(); }, },
         { name => "BUILD_TS",                 type => "=i",  hash_src => \%cmd_hash, default_sub => sub { return GetNewBuildTs(); }, },
         { name => "BUILD_ARTIFACTS_BASE_DIR", type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return "$GLOBAL_PATH_TO_TOP/BUILDS"; }, },
         { name => "BUILD_SOURCES_BASE_DIR",   type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return $GLOBAL_PATH_TO_TOP; }, },
         { name => "BUILD_RELEASE",            type => "=s",  hash_src => \%cmd_hash, default_sub => sub { Die("@_ not specified"); }, },
         { name => "BUILD_RELEASE_NO",         type => "=s",  hash_src => \%cmd_hash, default_sub => sub { Die("@_ not specified"); }, },
         { name => "BUILD_RELEASE_CANDIDATE",  type => "=s",  hash_src => \%cmd_hash, default_sub => sub { Die("@_ not specified"); }, },
         { name => "BUILD_TYPE",               type => "=s",  hash_src => \%cmd_hash, default_sub => sub { Die("@_ not specified"); }, },
         { name => "BUILD_THIRDPARTY_SERVER",  type => "=s",  hash_src => \%cmd_hash, default_sub => sub { Die("@_ not specified"); }, },
         { name => "BUILD_PROD_FLAG",          type => "!",   hash_src => \%cmd_hash, default_sub => sub { return 1; }, },
         { name => "BUILD_DEBUG_FLAG",         type => "!",   hash_src => \%cmd_hash, default_sub => sub { return 0; }, },
         { name => "BUILD_DEV_TOOL_BASE_DIR",  type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return "$ENV{HOME}/.zm-dev-tools"; }, },
         { name => "INTERACTIVE",              type => "!",   hash_src => \%cmd_hash, default_sub => sub { return 1; }, },
         { name => "GIT_OVERRIDES",            type => "=s%", hash_src => \%cmd_hash, default_sub => sub { return {}; }, },
         { name => "GIT_DEFAULT_TAG",          type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return undef; }, },
         { name => "GIT_DEFAULT_REMOTE",       type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return undef; }, },
         { name => "GIT_DEFAULT_BRANCH",       type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return undef; }, },
         { name => "STOP_AFTER_CHECKOUT",      type => "!",   hash_src => \%cmd_hash, default_sub => sub { return 0; }, },

         { name => "BUILD_OS",               type => "", hash_src => undef, default_sub => sub { return GetBuildOS(); }, },
         { name => "BUILD_ARCH",             type => "", hash_src => undef, default_sub => sub { return GetBuildArch(); }, },
         { name => "BUILD_RELEASE_NO_SHORT", type => "", hash_src => undef, default_sub => sub { my $x = $GLOBAL_BUILD_RELEASE_NO; $x =~ s/[.]//g; return $x; }, },
         { name => "BUILD_DIR",              type => "", hash_src => undef, default_sub => sub { return &$build_dir_func; }, },
      );

      {
         my @cmd_opts =
           map { $_->{opt} =~ y/A-Z_/a-z-/; $_; }    # convert the opt named to lowercase to make command line options
           map { { opt => $_->{name}, opt_s => $_->{type} } }    # create a new hash with keys opt, opt_s
           grep { $_->{type} }                                   # get only names which have a valid type
           @cmd_args;

         my $help_func = sub {
            print "Usage: $0 <options>\n";
            print "Supported options: \n";
            print "   --" . "$_->{opt}$_->{opt_s}\n" foreach (@cmd_opts);
            exit(0);
         };

         if ( !GetOptions( \%cmd_hash, ( map { $_->{opt} . $_->{opt_s} } @cmd_opts ), help => $help_func ) )
         {
            print Die("wrong commandline options, use --help");
         }
      }

      print "=========================================================================================================\n";
      LoadConfiguration($_) foreach (@cmd_args);
      print "=========================================================================================================\n";

      Die( "Bad version '${GLOBAL_BUILD_RELEASE_NO}'", "$@" )
        if ( ${GLOBAL_BUILD_RELEASE_NO} !~ m/^\d+[.]\d+[.]\d+$/ );
   }

   foreach my $x (`grep -o '\\<[E][N][V]_[A-Z_]*\\>' '$GLOBAL_PATH_TO_SCRIPT_FILE' | sort | uniq`)
   {
      chomp($x);
      my $fmt2v = " %-25s: %s\n";
      printf( $fmt2v, $x, defined $ENV{$x} ? $ENV{$x} : "(undef)" );
   }

   print "=========================================================================================================\n";
   {
      $ENV{PATH} = "$GLOBAL_BUILD_DEV_TOOL_BASE_DIR/bin/Sencha/Cmd/4.0.2.67:$GLOBAL_BUILD_DEV_TOOL_BASE_DIR/bin:$ENV{PATH}";

      my $cc    = DetectPrerequisite("cc");
      my $cpp   = DetectPrerequisite("c++");
      my $java  = DetectPrerequisite( "java", $ENV{JAVA_HOME} ? "$ENV{JAVA_HOME}/bin" : "" );
      my $javac = DetectPrerequisite( "javac", $ENV{JAVA_HOME} ? "$ENV{JAVA_HOME}/bin" : "" );
      my $mvn   = DetectPrerequisite("mvn");
      my $ant   = DetectPrerequisite("ant");
      my $ruby  = DetectPrerequisite("ruby");
      my $make  = DetectPrerequisite("make");

      $ENV{JAVA_HOME} ||= dirname( dirname( Cwd::realpath($javac) ) );
      $ENV{PATH} = "$ENV{JAVA_HOME}/bin:$ENV{PATH}";

      my $fmt2v = " %-25s: %s\n";
      printf( $fmt2v, "USING javac", "$javac (JAVA_HOME=$ENV{JAVA_HOME})" );
      printf( $fmt2v, "USING java",  $java );
      printf( $fmt2v, "USING maven", $mvn );
      printf( $fmt2v, "USING ant",   $ant );
      printf( $fmt2v, "USING cc",    $cc );
      printf( $fmt2v, "USING c++",   $cpp );
      printf( $fmt2v, "USING ruby",  $ruby );
      printf( $fmt2v, "USING make",  $make );
   }

   print "=========================================================================================================\n";

   print "NOTE: THIS WILL STOP AFTER CHECKOUTS\n"
     if ( $CFG{STOP_AFTER_CHECKOUT} );

   if ( $CFG{INTERACTIVE} )
   {
      print "Press enter to proceed";
      read STDIN, $_, 1;
   }
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

   System( "find", $GLOBAL_BUILD_DIR, "-type", "f", "-name", ".built.*", "-delete" ) if ( $ENV{ENV_CACHE_CLEAR_FLAG} );

   my @TP_JARS = (
      "https://files.zimbra.com/repository/ant-1.7.0-ziputil-patched/ant-1.7.0-ziputil-patched-1.0.jar",
      "https://files.zimbra.com/repository/ant-contrib/ant-contrib-1.0b1.jar",
      "https://files.zimbra.com/repository/ews_2010/ews_2010-1.0.jar",
      "https://files.zimbra.com/repository/jruby/jruby-complete-1.6.3.jar",
      "https://files.zimbra.com/repository/applet/plugin.jar",
      "https://files.zimbra.com/repository/servlet-api/servlet-api-3.1.jar",
      "https://files.zimbra.com/repository/unbound-ldapsdk/unboundid-ldapsdk-2.3.5-se.jar",
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

   my ( $MAJOR, $MINOR, $MICRO ) = split( /[.]/, ${GLOBAL_BUILD_RELEASE_NO} );

   EchoToFile( "$GLOBAL_PATH_TO_SCRIPT_DIR/RE/BUILD", $GLOBAL_BUILD_NO );
   EchoToFile( "$GLOBAL_PATH_TO_SCRIPT_DIR/RE/MAJOR", $MAJOR );
   EchoToFile( "$GLOBAL_PATH_TO_SCRIPT_DIR/RE/MINOR", $MINOR );
   EchoToFile( "$GLOBAL_PATH_TO_SCRIPT_DIR/RE/MICRO", "${MICRO}_${GLOBAL_BUILD_RELEASE_CANDIDATE}" );

   ${GLOBAL_BUILD_RELEASE_NO_MAJOR} = $MAJOR;
   ${GLOBAL_BUILD_RELEASE_NO_MINOR} = $MINOR;
   ${GLOBAL_BUILD_RELEASE_NO_MICRO} = $MICRO;

   close(FD);
}

sub EvalFile($;$)
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

   push( @agg_repos, @{ EvalFile("instructions/${GLOBAL_BUILD_TYPE}_repo_list.pl") } );

   return \@agg_repos;
}


sub LoadRemotes()
{
   my %details = @{ EvalFile("instructions/${GLOBAL_BUILD_TYPE}_remote_list.pl") };

   return \%details;
}


sub LoadPkgDeployPaths()
{
   my %details = @{ EvalFile("instructions/${GLOBAL_BUILD_TYPE}_pkg_deploy_paths.pl") };

   return \%details;
}


sub LoadBuilds($)
{
   my $repo_list = shift;

   my @agg_builds = ();

   push( @agg_builds, @{ EvalFile("instructions/${GLOBAL_BUILD_TYPE}_staging_list.pl") } );

   my %repo_hash = map { $_->{name} => 1 } @$repo_list;

   my @filtered_builds =
     grep { my $d = $_->{dir}; $d =~ s/\/.*//; $repo_hash{$d} }    # extract the repository from the 'dir' entry, filter out entries which do not exist in repo_list
     @agg_builds;

   return \@filtered_builds;
}


sub Checkout($)
{
   my $repo_list = shift;

   print "\n";
   print "=========================================================================================================\n";
   print " Processing " . scalar(@$repo_list) . " repositories\n";
   print "=========================================================================================================\n";
   print "\n";

   my $repo_remote_details = LoadRemotes();

   for my $repo_details (@$repo_list)
   {
      Clone( $repo_details, $repo_remote_details );
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

   my $tool_attributes = {
      ant => [
         "-Ddebug=${GLOBAL_BUILD_DEBUG_FLAG}",
         "-Dis-production=${GLOBAL_BUILD_PROD_FLAG}",
         "-Dzimbra.buildinfo.platform=${GLOBAL_BUILD_OS}",
         "-Dzimbra.buildinfo.version=${GLOBAL_BUILD_RELEASE_NO}_${GLOBAL_BUILD_RELEASE_CANDIDATE}_${GLOBAL_BUILD_NO}",
         "-Dzimbra.buildinfo.type=${GLOBAL_BUILD_TYPE}",
         "-Dzimbra.buildinfo.release=${GLOBAL_BUILD_TS}",
         "-Dzimbra.buildinfo.date=${GLOBAL_BUILD_TS}",
         "-Dzimbra.buildinfo.host=@{[Net::Domain::hostfqdn]}",
         "-Dzimbra.buildinfo.buildnum=${GLOBAL_BUILD_NO}",
      ],
      make => [
         "debug=${GLOBAL_BUILD_DEBUG_FLAG}",
         "is-production=${GLOBAL_BUILD_PROD_FLAG}",
         "zimbra.buildinfo.platform=${GLOBAL_BUILD_OS}",
         "zimbra.buildinfo.version=${GLOBAL_BUILD_RELEASE_NO}_${GLOBAL_BUILD_RELEASE_CANDIDATE}_${GLOBAL_BUILD_NO}",
         "zimbra.buildinfo.type=${GLOBAL_BUILD_TYPE}",
         "zimbra.buildinfo.release=${GLOBAL_BUILD_TS}",
         "zimbra.buildinfo.date=${GLOBAL_BUILD_TS}",
         "zimbra.buildinfo.host=@{[Net::Domain::hostfqdn]}",
         "zimbra.buildinfo.buildnum=${GLOBAL_BUILD_NO}",
      ],
   };

   my $pkg_deploy_path_details = LoadPkgDeployPaths();

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
         print color('blue') . "BUILDING: $dir ($cnt of " . scalar(@ALL_BUILDS) . ")" . color('reset') . "\n";
         print "\n";

         if ( $ENV{ENV_RESUME_FLAG} && -f "$target_dir/.built.$GLOBAL_BUILD_TS" )
         {
            print color('yellow') . "SKIPPING... [TO REBUILD REMOVE '$target_dir']" . color('reset') . "\n";
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

                  if ( my $tool_seq = $build_info->{tool_seq} || [ "ant", "mvn", "make" ] )
                  {
                     for my $tool (@$tool_seq)
                     {
                        if ( my $targets = $build_info->{ $tool . "_targets" } )    #Known values are: ant_targets, mvn_targets, make_targets
                        {
                           eval { System( $tool, "clean" ) if ( !$ENV{ENV_SKIP_CLEAN_FLAG} ); };

                           System( $tool, @{ $tool_attributes->{$tool} || [] }, @$targets );
                        }
                     }
                  }

                  if ( my $stage_cmd = $build_info->{stage_cmd} )
                  {
                     &$stage_cmd
                  }

                  if ( my $deploy_pkg_into = $build_info->{deploy_pkg_into} )
                  {
                     my $pkg_deploy_method = $pkg_deploy_path_details->{$deploy_pkg_into}->{method} || "cp";
                     my $pkg_deploy_path   = $pkg_deploy_path_details->{$deploy_pkg_into}->{path}   || "$GLOBAL_BUILD_DIR/packages";

                     system("mkdir -p '$pkg_deploy_path'");

                     if ( $pkg_deploy_method eq "cp" )
                     {
                        System("cp -a build/dist/* '$pkg_deploy_path/'");
                     }
                     else
                     {
                        Die("Unknown Pkg Deploy Method: '$pkg_deploy_method'");
                     }
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
         push( @ALL_PACKAGES, @{ EvalFile("instructions/${GLOBAL_BUILD_TYPE}_package_list.pl") } );
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
                     zimbraThirdPartyServer='$GLOBAL_BUILD_THIRDPARTY_SERVER' \\
                        bash $GLOBAL_PATH_TO_SCRIPT_DIR/instructions/bundling-scripts/$package_script.sh
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
   our $detected_os = undef;

   sub detect_os
   {
      chomp( $detected_os = `$GLOBAL_PATH_TO_SCRIPT_DIR/rpmconf/Build/get_plat_tag.sh` )
        if ( !$detected_os );

      return $detected_os
        if ($detected_os);

      Die("Unknown OS");
   }

   return detect_os();
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

sub Clone($$)
{
   my $repo_details        = shift;
   my $repo_remote_details = shift;

   my $repo_name       = $repo_details->{name};
   my $repo_branch     = $CFG{GIT_OVERRIDES}->{"$repo_name.branch"} || $repo_details->{branch} || $CFG{GIT_DEFAULT_BRANCH} || "develop";
   my $repo_tag        = $CFG{GIT_OVERRIDES}->{"$repo_name.tag"} || $repo_details->{tag} || $CFG{GIT_DEFAULT_TAG} if ( $CFG{GIT_OVERRIDES}->{"$repo_name.tag"} || !$CFG{GIT_OVERRIDES}->{"$repo_name.branch"} );
   my $repo_remote     = $CFG{GIT_OVERRIDES}->{"$repo_name.remote"} || $repo_details->{remote} || $CFG{GIT_DEFAULT_REMOTE} || "gh-zm";
   my $repo_url_prefix = $CFG{GIT_OVERRIDES}->{"$repo_remote.url-prefix"} || $repo_remote_details->{$repo_remote}->{'url-prefix'} || Die( "unresolved url-prefix for remote='$repo_remote'", "" );

   $repo_url_prefix =~ s,/*$,,;

   my $repo_dir = "$GLOBAL_BUILD_SOURCES_BASE_DIR/$repo_name";

   if ( !-d $repo_dir )
   {
      my @clone_cmd_args = ( "git", "clone" );

      push( @clone_cmd_args, "--depth=1" ) if ( not $ENV{ENV_GIT_FULL_CLONE} );
      push( @clone_cmd_args, "-b", $repo_tag ? $repo_tag : $repo_branch );
      push( @clone_cmd_args, "-o", $repo_remote, "$repo_url_prefix/$repo_name.git", "$repo_dir" );

      System(@clone_cmd_args);

      RemoveTargetInDir( $repo_name, $GLOBAL_BUILD_DIR );
   }
   else
   {
      if ( !defined $ENV{ENV_GIT_UPDATE_INCLUDE} || grep { $repo_name =~ /$_/ } split( ",", $ENV{ENV_GIT_UPDATE_INCLUDE} ) )
      {
         if ($repo_tag)
         {
            print "\n";
            System("cd '$repo_dir' && git checkout $repo_tag");

            RemoveTargetInDir( $repo_name, $GLOBAL_BUILD_DIR );
         }
         else
         {
            print "\n";
            my $z = System("cd '$repo_dir' && git pull --ff-only");

            if ( "@{$z->{out}}" !~ /Already up-to-date/ )
            {
               RemoveTargetInDir( $repo_name, $GLOBAL_BUILD_DIR );
            }
         }
      }
   }
}

sub System(@)
{
   my $cmd_str = "@_";

   print color('green') . "#: pwd=@{[Cwd::getcwd()]}" . color('reset') . "\n";
   print color('green') . "#: $cmd_str" . color('reset') . "\n";

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

   my @cfg_kvs =
     map { $_ =~ s/^\s+|\s+$//g; $_ }    # trim
     map { split( /=/, $_, 2 ) }         # split around =
     map { $_ =~ s/#.*$//g; $_ }         # strip comments
     grep { $_ !~ /^\s*#/ }              # ignore comments
     grep { $_ !~ /^\s*$/ }              # ignore empty lines
     @$x;

   my %ret_hash = ();
   for ( my $e = 0 ; $e < scalar @cfg_kvs ; $e += 2 )
   {
      my $probe_key = $cfg_kvs[$e];
      my $probe_val = $cfg_kvs[ $e + 1 ];

      if ( $probe_key =~ /^%(.*)/ )
      {
         my @val_kv_pair = split( /=/, $probe_val, 2 );

         $ret_hash{$1}{ $val_kv_pair[0] } = $val_kv_pair[1];
      }
      else
      {
         $ret_hash{$probe_key} = $probe_val;
      }
   }

   return \%ret_hash;
}


sub SlurpFile($)
{
   my $f = shift;

   open( FD, "<", "$f" ) || Die( "In open for read", "file='$f'" );

   chomp( my @x = <FD> );
   close(FD);

   return \@x;
}


sub EchoToFile($$)
{
   my $f = shift;
   my $w = shift;

   open( FD, ">", "$f" ) || Die( "In open for write", "file='$f'" );
   print FD $w . "\n";
   close(FD);
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

   Build($all_repos)
     if ( !$CFG{STOP_AFTER_CHECKOUT} );
}

main();

##############################################################################################
