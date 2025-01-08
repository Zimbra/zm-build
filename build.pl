#!/usr/bin/perl

use strict;
use warnings;

use Config;
use Cwd;
use Data::Dumper;
use File::Basename;
use File::Copy;
use Getopt::Long;
use IPC::Cmd qw/run/;
use Net::Domain;
use Term::ANSIColor;

my $GLOBAL_PATH_TO_SCRIPT_FILE;
my $GLOBAL_PATH_TO_SCRIPT_DIR;
my $GLOBAL_PATH_TO_TOP;
my $CWD;

my %CFG = ();

BEGIN
{
   $ENV{ANSI_COLORS_DISABLED} = 1 if ( !-t STDOUT );
   $GLOBAL_PATH_TO_SCRIPT_FILE = Cwd::abs_path(__FILE__);
   $GLOBAL_PATH_TO_SCRIPT_DIR  = dirname($GLOBAL_PATH_TO_SCRIPT_FILE);
   $GLOBAL_PATH_TO_TOP         = dirname($GLOBAL_PATH_TO_SCRIPT_DIR);
   $CWD                        = getcwd();
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

            printf( " %-35s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", $k . " => " . ${$val}{$k} );
         }
      }
      else
      {
         $CFG{$cfg_name} = $val;

         printf( " %-35s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", $val );
      }
   }
}

sub InitGlobalBuildVars()
{
   {
      my $destination_name_func = sub {
         return "$CFG{BUILD_OS}-$CFG{BUILD_RELEASE}-$CFG{BUILD_RELEASE_NO_SHORT}-$CFG{BUILD_TS}-$CFG{BUILD_TYPE}-$CFG{BUILD_NO}";
      };

      my $build_dir_func = sub {
         return "$CFG{BUILD_SOURCES_BASE_DIR}/.staging/$CFG{DESTINATION_NAME}";
      };

      my %cmd_hash = ();

      my @cmd_args = (
         { name => "BUILD_NO",                   type => "=i",  hash_src => \%cmd_hash, default_sub => sub { return GetNewBuildNo(); }, },
         { name => "BUILD_TS",                   type => "=i",  hash_src => \%cmd_hash, default_sub => sub { return GetNewBuildTs(); }, },
         { name => "BUILD_OS",                   type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return GetBuildOS(); }, },
         { name => "BUILD_DESTINATION_BASE_DIR", type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return "$GLOBAL_PATH_TO_TOP/BUILDS"; }, },
         { name => "BUILD_SOURCES_BASE_DIR",     type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return $GLOBAL_PATH_TO_TOP; }, },
         { name => "BUILD_RELEASE",              type => "=s",  hash_src => \%cmd_hash, default_sub => sub { Die("@_ not specified"); }, },
         { name => "BUILD_RELEASE_NO",           type => "=s",  hash_src => \%cmd_hash, default_sub => sub { Die("@_ not specified"); }, },
         { name => "BUILD_RELEASE_CANDIDATE",    type => "=s",  hash_src => \%cmd_hash, default_sub => sub { Die("@_ not specified"); }, },
         { name => "BUILD_TYPE",                 type => "=s",  hash_src => \%cmd_hash, default_sub => sub { Die("@_ not specified"); }, },
         { name => "BUILD_THIRDPARTY_SERVER",    type => "=s",  hash_src => \%cmd_hash, default_sub => sub { Die("@_ not specified"); }, },
         { name => "BUILD_PROD_FLAG",            type => "!",   hash_src => \%cmd_hash, default_sub => sub { return 1; }, },
         { name => "BUILD_DEBUG_FLAG",           type => "!",   hash_src => \%cmd_hash, default_sub => sub { return 0; }, },
         { name => "BUILD_DEV_TOOL_BASE_DIR",    type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return "$ENV{HOME}/.zm-dev-tools"; }, },
         { name => "INTERACTIVE",                type => "!",   hash_src => \%cmd_hash, default_sub => sub { return 1; }, },
         { name => "DISABLE_TAR",                type => "!",   hash_src => \%cmd_hash, default_sub => sub { return 0; }, },
         { name => "DISABLE_BUNDLE",             type => "!",   hash_src => \%cmd_hash, default_sub => sub { return 0; }, },
         { name => "EXCLUDE_GIT_REPOS",          type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return ""; }, },
         { name => "GIT_OVERRIDES",              type => "=s%", hash_src => \%cmd_hash, default_sub => sub { return {}; }, },
         { name => "GIT_DEFAULT_TAG",            type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return undef; }, },
         { name => "GIT_DEFAULT_REMOTE",         type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return undef; }, },
         { name => "GIT_DEFAULT_BRANCH",         type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return undef; }, },
         { name => "GIT_DEFAULT_REPO_NAME_SUFFIX", type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return undef; }, },
         { name => "STOP_AFTER_CHECKOUT",        type => "!",   hash_src => \%cmd_hash, default_sub => sub { return 0; }, },
         { name => "ANT_OPTIONS",                type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return undef; }, },
         { name => "BUILD_HOSTNAME",             type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return Net::Domain::hostfqdn; }, },
         { name => "BUILD_ARCH",                 type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return GetBuildArch(); }, },
         { name => "PKG_OS_TAG",                 type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return GetPkgOsTag(); }, },
         { name => "BUILD_RELEASE_NO_SHORT",     type => "=s",  hash_src => \%cmd_hash, default_sub => sub { my $x = $CFG{BUILD_RELEASE_NO}; $x =~ s/[.]//g; return $x; }, },
         { name => "DESTINATION_NAME",           type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return &$destination_name_func; }, },
         { name => "BUILD_DIR",                  type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return &$build_dir_func; }, },
         { name => "DEPLOY_URL_PREFIX",          type => "=s",  hash_src => \%cmd_hash, default_sub => sub { $CFG{LOCAL_DEPLOY} = 1; return "http://" . Net::Domain::hostfqdn . ":8008/$CFG{DESTINATION_NAME}"; }, },
         { name => "DUMP_CONFIG_TO",             type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return undef; }, },
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

      Die( "Bad version '$CFG{BUILD_RELEASE_NO}'", "$@" )
        if ( $CFG{BUILD_RELEASE_NO} !~ m/^\d+[.]\d+[.]\d+$/ );
   }

   foreach my $x (`grep -o '\\<[E][N][V]_[A-Z_]*\\>' '$GLOBAL_PATH_TO_SCRIPT_FILE' | sort | uniq`)
   {
      chomp($x);
      my $fmt2v = " %-35s: %s\n";
      printf( $fmt2v, $x, defined $ENV{$x} ? $ENV{$x} : "(undef)" );
   }

   print "=========================================================================================================\n";
   {
      $ENV{PATH} = join(
         ":",
         "$CFG{BUILD_DEV_TOOL_BASE_DIR}/bin/Sencha/Cmd/4.0.2.67",    #remove nw specific requirements
         reverse sort glob("$CFG{BUILD_DEV_TOOL_BASE_DIR}/*/bin"),
         "$CFG{BUILD_DEV_TOOL_BASE_DIR}/bin",
         "$ENV{PATH}"
      );

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

      my $fmt2v = " %-35s: %s\n";
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

   if ( $CFG{DUMP_CONFIG_TO} )
   {
      open( my $fh, ">", $CFG{DUMP_CONFIG_TO} ) or Die("Could not open '$CFG{DUMP_CONFIG_TO}'");

      print $fh "# Dumping config to file...\n\n";

      foreach my $k ( sort keys %CFG )
      {
         my $v = $CFG{$k};
         if ( ref($v) eq "HASH" )
         {
            foreach my $sk ( sort keys %$v )
            {
               printf $fh "%-30s = %s\n", '%' . $k, "$sk=$v->{$sk}";
            }
         }
         else
         {
            printf $fh "%-30s = %s\n", $k, $v;
         }
      }

      print "NOTE: DUMPED CONFIG TO FILE - $CFG{DUMP_CONFIG_TO}\n";
   }

   print "NOTE: THIS WILL STOP AFTER CHECKOUTS\n"
     if ( $CFG{STOP_AFTER_CHECKOUT} );

   if ( $CFG{INTERACTIVE} )
   {
      print "Press enter to proceed";
      read STDIN, $_, 1;
   }
}

sub TranslateToPackagePath
{
   my $deploy_pkg_into = shift;

   if ( my $pkg_dir = $deploy_pkg_into )
   {
      $pkg_dir = "zimbra-" . lc( $CFG{BUILD_TYPE} )
        if ( $pkg_dir eq "bundle" && $CFG{DISABLE_BUNDLE} );

      $pkg_dir .= "-$ENV{ENV_ARCHIVE_SUFFIX_STR}"
        if ( $pkg_dir ne "bundle" && $ENV{ENV_ARCHIVE_SUFFIX_STR} );

      return "$CFG{BUILD_DIR}/zm-packages/$pkg_dir/$CFG{PKG_OS_TAG}";
   }
   else
   {
      return undef;
   }
}

sub Prepare()
{
   RemoveTargetInDir( ".zcs-deps",   $ENV{HOME} ) if ( $ENV{ENV_CACHE_CLEAR_FLAG} );
   RemoveTargetInDir( ".ivy2/cache", $ENV{HOME} ) if ( $ENV{ENV_CACHE_CLEAR_FLAG} );

   open( FD, ">", "$GLOBAL_PATH_TO_SCRIPT_DIR/.build.last_no_ts" );
   print FD "BUILD_NO=$CFG{BUILD_NO}\n";
   print FD "BUILD_TS=$CFG{BUILD_TS}\n";
   close(FD);

   SysExec( "mkdir", "-p", "$CFG{BUILD_DIR}" );
   SysExec( "mkdir", "-p", "$CFG{BUILD_DIR}/logs" );
   SysExec( "mkdir", "-p", "$ENV{HOME}/.zcs-deps" );
   SysExec( "mkdir", "-p", "$ENV{HOME}/.ivy2/cache" );

   SysExec( "find", $CFG{BUILD_DIR}, "-type", "f", "-name", ".built.*", "-delete" ) if ( $ENV{ENV_CACHE_CLEAR_FLAG} );

   my @TP_JARS = (
      "https://files.zimbra.com/repository/ant-1.7.0-ziputil-patched/ant-1.7.0-ziputil-patched-1.0.jar",
      "https://files.zimbra.com/repository/ant-contrib/ant-contrib-1.0b1.jar",
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
            SysExec( "wget", $j_url, "-O", "$f.tmp" );
            SysExec( "mv", "$f.tmp", $f );
         }
      }
   }

   my ( $MAJOR, $MINOR, $MICRO ) = split( /[.]/, $CFG{BUILD_RELEASE_NO} );

   EchoToFile( "$GLOBAL_PATH_TO_SCRIPT_DIR/RE/BUILD", $CFG{BUILD_NO} );
   EchoToFile( "$GLOBAL_PATH_TO_SCRIPT_DIR/RE/MAJOR", $MAJOR );
   EchoToFile( "$GLOBAL_PATH_TO_SCRIPT_DIR/RE/MINOR", $MINOR );
   EchoToFile( "$GLOBAL_PATH_TO_SCRIPT_DIR/RE/MICRO", "${MICRO}_$CFG{BUILD_RELEASE_CANDIDATE}" );

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

   my %exclusions = ();
   map { $exclusions{$_} = 1; } split(/,/, $CFG{EXCLUDE_GIT_REPOS});

   push( @agg_repos, grep { !exists $exclusions{$_->{name}} } @{ EvalFile("instructions/$CFG{BUILD_TYPE}_repo_list.pl") } );

   return \@agg_repos;
}


sub LoadRemotes()
{
   my %details = @{ EvalFile("instructions/$CFG{BUILD_TYPE}_remote_list.pl") };

   return \%details;
}


sub LoadBuilds($)
{
   my $repo_list = shift;

   my @agg_builds = ();

   push( @agg_builds, @{ EvalFile("instructions/$CFG{BUILD_TYPE}_staging_list.pl") } );

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
         RunInDir( cd => $chdir, child => sub { SysExec( "rm", "-rf", $sane_target ); } );
      };
   }
}

sub EmitArchiveAccessInstructions($)
{
   my $archive_names = shift;

   if ( -f "/etc/redhat-release" )
   {
      return <<EOM_DUMP;
#########################################
# INSTRUCTIONS TO ACCESS FROM CLIENT BOX
#########################################

sudo bash -s <<"EOM_SCRIPT"
cat > /etc/yum.repos.d/zimbra-packages.repo <<EOM
@{[
   join("\n",
      map {
"[$_]
name=Zimbra Package Archive ($_)
baseurl=$CFG{DEPLOY_URL_PREFIX}/archives/$_/$CFG{PKG_OS_TAG}/
enabled=1
gpgcheck=0
protect=0"
      }
      @$archive_names
   )]}
EOM
yum clean all
EOM_SCRIPT
EOM_DUMP
   }
   else
   {
      return <<EOM_DUMP;
#########################################
# INSTRUCTIONS TO ACCESS FROM CLIENT BOX
#########################################

sudo bash -s <<"EOM_SCRIPT"
cat > /etc/apt/sources.list.d/zimbra-packages.list << EOM
@{[
   join("\n",
      map {
"deb [trusted=yes] $CFG{DEPLOY_URL_PREFIX}/archives/$_/$CFG{PKG_OS_TAG} ./ # Zimbra Package Archive ($_)"
      }
      @$archive_names
   )]}
EOM
apt-get update
EOM_SCRIPT
EOM_DUMP
   }
}


sub Build($)
{
   my $repo_list = shift;

   my @ALL_BUILDS = @{ LoadBuilds($repo_list) };

   my $tool_attributes = {
      ant => [
         "-Ddebug=$CFG{BUILD_DEBUG_FLAG}",
         "-Dis-production=$CFG{BUILD_PROD_FLAG}",
         "-Dzimbra.buildinfo.platform=$CFG{BUILD_OS}",
         "-Dzimbra.buildinfo.pkg_os_tag=$CFG{PKG_OS_TAG}",
         "-Dzimbra.buildinfo.version=$CFG{BUILD_RELEASE_NO}_$CFG{BUILD_RELEASE_CANDIDATE}_$CFG{BUILD_NO}",
         "-Dzimbra.buildinfo.type=$CFG{BUILD_TYPE}",
         "-Dzimbra.buildinfo.release=$CFG{BUILD_TS}",
         "-Dzimbra.buildinfo.date=$CFG{BUILD_TS}",
         "-Dzimbra.buildinfo.host=$CFG{BUILD_HOSTNAME}",
         "-Dzimbra.buildinfo.buildnum=$CFG{BUILD_NO}",
      ],
      make => [
         "debug=$CFG{BUILD_DEBUG_FLAG}",
         "is-production=$CFG{BUILD_PROD_FLAG}",
         "zimbra.buildinfo.platform=$CFG{BUILD_OS}",
         "zimbra.buildinfo.pkg_os_tag=$CFG{PKG_OS_TAG}",
         "zimbra.buildinfo.version=$CFG{BUILD_RELEASE_NO}_$CFG{BUILD_RELEASE_CANDIDATE}_$CFG{BUILD_NO}",
         "zimbra.buildinfo.type=$CFG{BUILD_TYPE}",
         "zimbra.buildinfo.release=$CFG{BUILD_TS}",
         "zimbra.buildinfo.date=$CFG{BUILD_TS}",
         "zimbra.buildinfo.host=$CFG{BUILD_HOSTNAME}",
         "zimbra.buildinfo.buildnum=$CFG{BUILD_NO}",
      ],
      mvn => [
      ],
   };

   push( @{ $tool_attributes->{ant} }, $CFG{ANT_OPTIONS} )
     if ( $CFG{ANT_OPTIONS} );

   my $cnt = 0;
   for my $build_info (@ALL_BUILDS)
   {
      ++$cnt;

      if ( my $dir = $build_info->{dir} )
      {
         my $target_dir = "$CFG{BUILD_DIR}/$dir";

         next
           unless ( !defined $ENV{ENV_BUILD_INCLUDE} || grep { $dir =~ /$_/ } split( ",", $ENV{ENV_BUILD_INCLUDE} ) );

         RemoveTargetInDir( $dir, $CFG{BUILD_DIR} )
           if ( ( $ENV{ENV_FORCE_REBUILD} && grep { $dir =~ /$_/ } split( ",", $ENV{ENV_FORCE_REBUILD} ) ) );

         print "=========================================================================================================\n";
         print color('blue') . "BUILDING: $dir ($cnt of " . scalar(@ALL_BUILDS) . ")" . color('reset') . "\n";
         print "\n";

         if ( $ENV{ENV_RESUME_FLAG} && -f "$target_dir/.built.$CFG{BUILD_TS}" )
         {
            print color('yellow') . "SKIPPING... [TO REBUILD REMOVE '$target_dir']" . color('reset') . "\n";
            print "=========================================================================================================\n";
            print "\n";
         }
         else
         {
            unlink glob "$target_dir/.built.*";

            RunInDir(
               cd    => $dir,
               child => sub {

                  my $abs_dir = Cwd::abs_path();

                  if ( my $tool_seq = $build_info->{tool_seq} || [ "ant", "mvn", "make" ] )
                  {
                     for my $tool (@$tool_seq)
                     {
                        if ( my $targets = $build_info->{ $tool . "_targets" } )    #Known values are: ant_targets, mvn_targets, make_targets
                        {
                           eval { SysExec( $tool, "clean" ) if ( !$ENV{ENV_SKIP_CLEAN_FLAG} ); };

                           SysExec( $tool, @{ $tool_attributes->{$tool} || [] }, @$targets );
                        }
                     }
                  }

                  if ( my $stage_cmd = $build_info->{stage_cmd} )
                  {
                     &$stage_cmd
                  }

                  if ( my $packages_path = TranslateToPackagePath( $build_info->{deploy_pkg_into} ) )
                  {
                     SysExec( "mkdir", "-p", $packages_path );
                     SysExec( "rsync", "-av", "build/dist/$CFG{PKG_OS_TAG}/", "$packages_path/" );
                  }

                  if ( !exists $build_info->{partial} )
                  {
                     SysExec( "mkdir", "-p", "$target_dir" );
                     SysExec( "touch", "$target_dir/.built.$CFG{BUILD_TS}" );
                  }
               },
            );

            print "\n";
            print "=========================================================================================================\n";
            print "\n";
         }
      }
   }

   RunInDir(
      cd    => "$GLOBAL_PATH_TO_SCRIPT_DIR",
      child => sub {
         SysExec( "rsync", "-az", "--delete", ".", "$CFG{BUILD_DIR}/zm-build" );
         SysExec( "mkdir", "-p", "$CFG{BUILD_DIR}/zm-build/$CFG{BUILD_ARCH}" );

         my @ALL_PACKAGES = ();
         push( @ALL_PACKAGES, @{ EvalFile("instructions/$CFG{BUILD_TYPE}_package_list.pl") } );
         push( @ALL_PACKAGES, "zcs-bundle" )
           if ( !$CFG{DISABLE_TAR} );

         for my $package_script (@ALL_PACKAGES)
         {
            if ( !defined $ENV{ENV_PACKAGE_INCLUDE} || grep { $package_script =~ /$_/ } split( ",", $ENV{ENV_PACKAGE_INCLUDE} ) )
            {
               SysExec(
                  "  releaseNo='$CFG{BUILD_RELEASE_NO}' \\
                     releaseCandidate='$CFG{BUILD_RELEASE_CANDIDATE}' \\
                     branch='$CFG{BUILD_RELEASE}-$CFG{BUILD_RELEASE_NO_SHORT}' \\
                     buildNo='$CFG{BUILD_NO}' \\
                     os='$CFG{BUILD_OS}' \\
                     PKG_OS_TAG='$CFG{PKG_OS_TAG}' \\
                     buildType='$CFG{BUILD_TYPE}' \\
                     repoDir='$CFG{BUILD_DIR}' \\
                     arch='$CFG{BUILD_ARCH}' \\
                     buildTimeStamp='$CFG{BUILD_TS}' \\
                     buildLogFile='$CFG{BUILD_DIR}/logs/build.log' \\
                     zimbraThirdPartyServer='$CFG{BUILD_THIRDPARTY_SERVER}' \\
                        bash $GLOBAL_PATH_TO_SCRIPT_DIR/instructions/bundling-scripts/$package_script.sh
                  "
               );

               if ( $CFG{DISABLE_BUNDLE} )    # move created packages out of the tar for independent deployment in archive.
               {
                  my $alt_dest_pkg_dir = TranslateToPackagePath("bundle");

                  SysExec( "mkdir", "-p", $alt_dest_pkg_dir );
                  SysExec( "rsync", "-av", "--remove-source-files", "$CFG{BUILD_DIR}/zm-build/$CFG{BUILD_ARCH}/", "$alt_dest_pkg_dir/" );
               }
            }
         }
      },
   );
}


sub Deploy()
{
   print "\n";
   print "=========================================================================================================\n";
   print color('blue') . "DEPLOYING ARTIFACTS" . color('reset') . "\n";
   print "\n";
   print "\n";

   my $destination_dir = "$CFG{BUILD_DESTINATION_BASE_DIR}/$CFG{DESTINATION_NAME}";

   SysExec( "mkdir", "-p", "$destination_dir/archives" );

   my @archive_names = map { basename($_) } grep { -d $_ && $_ !~ m/\/bundle$/ } glob("$CFG{BUILD_DIR}/zm-packages/*");

   foreach my $archive_name (@archive_names)
   {
      SysExec( "rsync", "-av", "--delete", "$CFG{BUILD_DIR}/zm-packages/$archive_name/", "$destination_dir/archives/$archive_name" );

      if ( -f "/etc/redhat-release" )
      {
         if ( !$CFG{LOCAL_DEPLOY} || DetectPrerequisite( "createrepo", "", 1 ) )
         {
            SysExec("cd '$destination_dir/archives/$archive_name/$CFG{PKG_OS_TAG}' && createrepo '.'");
         }
      }
      else
      {
         if ( !$CFG{LOCAL_DEPLOY} || DetectPrerequisite( "dpkg-scanpackages", "", 1 ) )
         {
            SysExec("cd '$destination_dir/archives/$archive_name/$CFG{PKG_OS_TAG}' && dpkg-scanpackages '.' /dev/null > Packages");
         }
      }
   }

   EchoToFile( "$destination_dir/archive-access-$CFG{PKG_OS_TAG}.txt", EmitArchiveAccessInstructions( \@archive_names ) );

   SysExec("cp $CFG{BUILD_DIR}/zm-build/zcs-*.$CFG{BUILD_TS}.tgz $destination_dir/")
     if ( !$CFG{DISABLE_TAR} );

   if ( $CFG{LOCAL_DEPLOY} )
   {
      if ( !-f "/etc/nginx/conf.d/zimbra-pkg-archives-host.conf" || !`pgrep -f -P1 '[n]ginx'` )
      {
         print "\n";
         print "=========================================================================================================\n";
         print <<EOM_DUMP;
@{[color('bold white')]}
############################################
# INSTRUCTIONS TO SETUP NGINX PACKAGES HOST
############################################
@{[color('reset')]}
# You might need to resolve network, firewall, selinux, permissions issues appropriately before proceeding:

# sudo sed -i -e s/^SELINUX=enforcing/SELINUX=permissive/ /etc/selinux/config
# sudo setenforce permissive
# sudo systemctl stop firewalld
# sudo ufw disable
@{[color('yellow')]}
sudo bash -s <<"EOM_SCRIPT"
[ -f /etc/redhat-release ] && ( yum install -y epel-release && yum install -y nginx && service nginx start )
[ -f /etc/redhat-release ] || ( apt-get -y install nginx && service nginx start )
tee /etc/nginx/conf.d/zimbra-pkg-archives-host.conf <<EOM
server {
  listen 8008;
  location / {
     root $CFG{BUILD_DESTINATION_BASE_DIR};
     autoindex on;
  }
}
EOM
service httpd stop 2>/dev/null
service nginx restart
service nginx status
EOM_SCRIPT
@{[color('reset')]}
EOM_DUMP
      }
   }

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


sub GetBuildOS()    # FIXME - use standard mechanism
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

sub GetBuildArch()
{
   my $b_os = $CFG{BUILD_OS};

   return "amd64"
     if ( $b_os =~ /UBUNTU[0-9]+_64/ );

   return "x86_64"
     if ( $b_os =~ /RHEL[0-9]+_64/ || $b_os =~ /CENTOS[0-9]+_64/ );

   Die("Could not determine BUILD_ARCH");
}

sub GetPkgOsTag()
{
   my $b_os = $CFG{BUILD_OS};

   return "u$1"
     if ( $b_os =~ /UBUNTU([0-9]+)_/ );

   return "r$1"
     if ( $b_os =~ /RHEL([0-9]+)_/ || $b_os =~ /CENTOS([0-9]+)_/ );

   Die("Could not determine PKG_OS_TAG");
}


##############################################################################################

sub Clone($$)
{
   my $repo_details        = shift;
   my $repo_remote_details = shift;

   my $repo_name       = $repo_details->{name};
   my $repo_branch_csv = $CFG{GIT_OVERRIDES}->{"$repo_name.branch"} || $repo_details->{branch} || $CFG{GIT_DEFAULT_BRANCH} || "develop";
   my $repo_tag_csv    = $CFG{GIT_OVERRIDES}->{"$repo_name.tag"} || $repo_details->{tag} || $CFG{GIT_DEFAULT_TAG} if ( $CFG{GIT_OVERRIDES}->{"$repo_name.tag"} || !$CFG{GIT_OVERRIDES}->{"$repo_name.branch"} );
   my $repo_remote     = $CFG{GIT_OVERRIDES}->{"$repo_name.remote"} || $repo_details->{remote} || $CFG{GIT_DEFAULT_REMOTE} || "gh-zm";
   my $repo_url_prefix = $CFG{GIT_OVERRIDES}->{"$repo_remote.url-prefix"} || $repo_remote_details->{$repo_remote}->{'url-prefix'} || Die( "unresolved url-prefix for remote='$repo_remote'", "" );
   my $repo_name_suffix     = $CFG{GIT_OVERRIDES}->{"$repo_name.repo_name_suffix"} || $repo_details->{repo_name_suffix} || $CFG{GIT_DEFAULT_REPO_NAME_SUFFIX};

   $repo_url_prefix =~ s,/*$,,;

   my $repo_dir = "$CFG{BUILD_SOURCES_BASE_DIR}/$repo_name";
   my $repo_source = $repo_url_prefix . "/" .
                  ($repo_name_suffix ? "$repo_name$repo_name_suffix.git" : "$repo_name.git");

   if ( !-d $repo_dir )
   {
      my $s = 0;
      foreach my $minus_b_arg ( split( /,/, $repo_tag_csv ? $repo_tag_csv : $repo_branch_csv ) )
      {
         my $r = SysExec("git", "ls-remote",
                $repo_tag_csv ? "--tags" : "--heads",
                $repo_source,
                "$minus_b_arg");
         if ( $r->{success} && "@{$r->{out}}" =~ /$minus_b_arg$/ )
         {
            my @clone_cmd_args = ( "git", "clone" );

            push( @clone_cmd_args, "--depth=1" ) if ( not $ENV{ENV_GIT_FULL_CLONE} and $repo_name ne "zm-mailbox");
            push( @clone_cmd_args, "-b", $minus_b_arg );
            push( @clone_cmd_args, $repo_source, "$repo_dir");
            print "\n";
            my $r = SysExec(@clone_cmd_args);
            if ( $r->{success} )
            {
               $s++;
               last;
            }
         }
      }

      Die("Clone Attempts Failed")
        if ( !$s );

      RemoveTargetInDir( $repo_name, $CFG{BUILD_DIR} );
   }
   else
   {
      if ( !defined $ENV{ENV_GIT_UPDATE_INCLUDE} || grep { $repo_name =~ /$_/ } split( ",", $ENV{ENV_GIT_UPDATE_INCLUDE} ) )
      {
         if ($repo_tag_csv)
         {
            RunInDir(
               cd    => $repo_dir,
               child => sub {

                  my $s = 0;
                  foreach my $minus_b_arg ( split( /,/, $repo_tag_csv ) )
                  {
                     print "\n";
                     my $r = SysExec( "git", "checkout", $minus_b_arg );
                     if ( $r->{success} )
                     {
                        $s++;
                        last;
                     }
                  }

                  Die("Clone Attempts Failed")
                    if ( !$s );
               },
            );

            RemoveTargetInDir( $repo_name, $CFG{BUILD_DIR} );
         }
         else
         {
            print "\n";
            RunInDir(
               cd    => $repo_dir,
               child => sub {
                  my $z = SysExec( "git", "pull", "--ff-only" );

                  if ( "@{$z->{out}}" !~ /Already up-to-date/ )
                  {
                     RemoveTargetInDir( $repo_name, $CFG{BUILD_DIR} );
                  }
               },
            );
         }
      }
   }
}

sub SysExec(@)
{
   my $options = shift
     if ( @_ && ref( $_[0] ) eq "HASH" );

   $options->{continue_on_error} ||= 0;
   $options->{verbose}           ||= 1;

   my $cmd_str = "@_";

   if ( $options->{verbose} )
   {
      print color('green') . "#: pwd=@{[Cwd::getcwd()]}" . color('reset') . "\n";
      print color('green') . "#: $cmd_str" . color('reset') . "\n";
   }

   $! = 0;
   my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) = run( command => \@_, verbose => 1 );

   Die( "cmd='$cmd_str'", $error_message )
     if ( !$success && !$options->{continue_on_error} );

   return { msg => $error_message, out => $stdout_buf, err => $stderr_buf, success => $success };
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


sub DetectPrerequisite($;$$)
{
   my $util_name       = shift;
   my $additional_path = shift || "";
   my $warn_only       = shift || 0;

   chomp( my $detected_util = `PATH="$additional_path:\$PATH" \\which "$util_name" 2>/dev/null | sed -e 's,//*,/,g'` );

   return $detected_util
     if ($detected_util);

   Die(
      "Prerequisite '$util_name' missing in PATH"
        . "\nTry: "
        . "\n   [ -f /etc/redhat-release ] && sudo yum install perl-Data-Dumper perl-IPC-Cmd gcc-c++ java-1.8.0-openjdk ant ant-junit ruby maven wget rpm-build createrepo"
        . "\n   [ -f /etc/redhat-release ] || sudo apt-get install software-properties-common openjdk-8-jdk ant ant-optional ruby git maven build-essential",
      "",
      $warn_only
   );
}


sub RunInDir(%)
{
   my %args  = (@_);
   my $chdir = $args{cd};
   my $child = $args{child};

   my $child_pid = fork();

   Die("FAILURE while forking")
     if ( !defined $child_pid );

   if ( $child_pid != 0 )    # parent
   {
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

sub Die($;$$)
{
   my $msg       = shift;
   my $info      = shift || "";
   my $warn_only = shift || 0;

   my $err = "$!";

   print "\n" if ( !$warn_only );
   print "\n";
   print "=========================================================================================================\n";
   print color('red') . "FAILURE MSG" . color('reset') . " : $msg\n"  if ( !$warn_only );
   print color('red') . "WARNING MSG" . color('reset') . " : $msg\n"  if ($warn_only);
   print color('red') . "SYSTEM ERR " . color('reset') . " : $err\n"  if ($err);
   print color('red') . "EXTRA INFO " . color('reset') . " : $info\n" if ($info);
   print "\n";
   print "=========================================================================================================\n";

   if ( !$warn_only )
   {
      print color('red');
      print "--Stack Trace-- ($$)\n";
      my $i = 1;

      while ( ( my @call_details = ( caller( $i++ ) ) ) )
      {
         print $call_details[1] . ":" . $call_details[2] . " called from " . $call_details[3] . "\n";
      }
      print color('reset');
      print "\n";
      print "=========================================================================================================\n";

      die "END"
   }
}

##############################################################################################

sub main()
{
   InitGlobalBuildVars();

   my $all_repos = LoadRepos();

   Prepare();

   Checkout($all_repos);

   if ( !$CFG{STOP_AFTER_CHECKOUT} )
   {
      Build($all_repos);

      Deploy();
   }
}

main();

##############################################################################################
