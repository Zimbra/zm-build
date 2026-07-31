@ENTRIES = (
   {
      "dir"             => "zm-mailbox",
      "ant_targets"     => ["pkg-after-plough-through-tests"],
      "deploy_pkg_into" => "bundle",
      "stage_cmd"       => sub {
         SysExec("mkdir -p                                 $CFG{BUILD_DIR}/zm-mailbox/store-conf/");
         SysExec("rsync -az store-conf/conf                $CFG{BUILD_DIR}/zm-mailbox/store-conf/");
         SysExec("install -T -D store/build/dist/versions-init.sql $CFG{BUILD_DIR}/zm-mailbox/store/build/dist/versions-init.sql");
      },
      "nexus_artifacts" => {
         type     => 'package',
         packages => [
            { name => "zimbra-common-core-jar"         },
            { name => "zimbra-common-mbox-conf-attrs"  },
            { name => "zimbra-common-mbox-conf-msgs"   },
            { name => "zimbra-common-mbox-conf-rights" },
            { name => "zimbra-common-mbox-conf"        },
            { name => "zimbra-common-mbox-db"          },
            { name => "zimbra-common-mbox-docs"        },
            { name => "zimbra-common-mbox-native-lib"  },
            { name => "zimbra-mbox-conf"               },
            { name => "zimbra-mbox-service"            },
            { name => "zimbra-mbox-war"                },
         ],
         post_fetch => sub {
            my $pkg_os_tag  = $CFG{PKG_OS_TAG};
            my $sources_dir = $CFG{BUILD_SOURCES_BASE_DIR};
            my $extract_dir = "/tmp/zimbra-common-mbox-db-extract-$$";
            my $pkg_ext = ( $CFG{BUILD_OS} =~ /UBUNTU/i ) ? 'deb' : 'rpm';
            my $glob_pattern = ( $pkg_ext eq 'deb' )
                ? "$sources_dir/zm-mailbox/build/dist/$pkg_os_tag/zimbra-common-mbox-db_*.$pkg_ext"
                : "$sources_dir/zm-mailbox/build/dist/$pkg_os_tag/zimbra-common-mbox-db-[0-9]*.$pkg_ext";
            my ($pkg_file) = glob($glob_pattern);

            unless ( $pkg_file && -f $pkg_file ) {
               _Warn("post_fetch: zimbra-common-mbox-db.$pkg_ext not found in $sources_dir/zm-mailbox/build/dist/$pkg_os_tag/");
               return 0;
            }

            eval { SysExec( "mkdir", "-p", $extract_dir ); };
            if ($@) { _Warn("post_fetch: mkdir failed: $@"); return 0; }
            if ( $CFG{BUILD_OS} =~ /UBUNTU/i ) {
               eval { SysExec( "dpkg-deb", "-x", $pkg_file, $extract_dir ); };
            }
            else {
               eval { SysExec( "bash", "-c", "cd '$extract_dir' && rpm2cpio '$pkg_file' | cpio -idm 2>/dev/null" ); };
            }
            if ($@) { _Warn("post_fetch: package extraction failed: $@"); SysExec( "rm", "-rf", $extract_dir ); return 0; }

            eval { SysExec( "install", "-T", "-D",
               "$extract_dir/opt/zimbra/db/versions-init.sql",
               "$sources_dir/zm-mailbox/store/build/dist/versions-init.sql"
            ); };
            if ($@) { _Warn("post_fetch: install versions-init.sql failed: $@"); SysExec( "rm", "-rf", $extract_dir ); return 0; }

            SysExec( "rm", "-rf", $extract_dir );
            return 1;
         },
      },
   },
   {
      "dir"         => "zm-mailbox/store",
      "ant_targets" => ["publish-store-test", "test", "coverage", "sonar-scan"],
      "stage_cmd"   => undef,
   },
   {
      # This repo can be removed and made independent of zm-zextras
      # This cannot be done unless the packages from zm-timezones are pushed to public repo
      # This is already excluded in CircleCI builds
      "dir"             => "zm-timezones",
      "ant_targets"     => ["pkg", "sonar-scan"],
      "deploy_pkg_into" => "bundle",
      "nexus_artifacts" => {
         type     => 'package',
         packages => [ { name => "zimbra-timezone-data" } ],
      },
   },
   {
      "dir"         => "junixsocket/junixsocket-native",
      "mvn_targets" => ["package"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/junixsocket/junixsocket-native/build");
         SysExec("cp -f target/nar/junixsocket-native-*/lib/*/jni/libjunixsocket-native-*.so $CFG{BUILD_DIR}/junixsocket/junixsocket-native/build/");
         SysExec("cp -f target/junixsocket-native-*.nar  $CFG{BUILD_DIR}/junixsocket/junixsocket-native/build/");
      },
   },
   {
      "dir"         => "zm-taglib",
      "ant_targets" => ["publish-local", "sonar-scan"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-taglib/build");
         SysExec("cp -f build/zm-taglib*.jar  $CFG{BUILD_DIR}/zm-taglib/build/");
      },
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-taglib", dest_subdir => "build" },
         ],
      },
   },
   {
      "dir"         => "zm-charset",
      "ant_targets" => ["publish-local", "sonar-scan"],
      "stage_cmd"   => undef,
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-charset" },
         ],
      },
   },
   {
      "dir"         => "zm-ldap-utilities",
      "ant_targets" => ["build-dist"],
      "stage_cmd"   => sub {
         SysExec("(cd .. && rsync -az --relative zm-ldap-utilities/build/dist $CFG{BUILD_DIR}/)");
         SysExec("(cd .. && rsync -az --relative zm-ldap-utilities/src/ldap/migration $CFG{BUILD_DIR}/)");
         SysExec("(cd .. && rsync -az --relative zm-ldap-utilities/conf $CFG{BUILD_DIR}/)");
         SysExec("(cd .. && rsync -az --relative zm-ldap-utilities/src/libexec $CFG{BUILD_DIR}/)");
      },
   },
   {
      "dir"         => "zm-ajax",
      "ant_targets" => ["publish-local", "sonar-scan"],
      "stage_cmd"   => undef,
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-ajax" },
         ],
      },
   },
   {
      "dir"         => "zm-admin-ajax",
      "ant_targets" => ["publish-local", "sonar-scan"],
      "stage_cmd"   => undef,
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-admin-ajax" },
         ],
      },
   },
   {
      "dir"         => "zm-ssdb-ephemeral-store",
      "ant_targets" => ["publish-local", "test", "coverage", "sonar-scan"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-ssdb-ephemeral-store/build/dist");
         SysExec("cp -f build/zm-ssdb-ephemeral-store*.jar $CFG{BUILD_DIR}/zm-ssdb-ephemeral-store/build/dist");
      },
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-ssdb-ephemeral-store", dest_subdir => "build" },
         ],
      },
   },
   {
      "dir"         => "zm-openid-consumer-store",
      "ant_targets" => ["dist-package", "test", "coverage", "sonar-scan"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-openid-consumer-store/build/dist");
         SysExec("cp -f -r build/dist $CFG{BUILD_DIR}/zm-openid-consumer-store/build/");
      },
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-openid-consumer-store" },
            { name => "guice", org => "com.google.inject", nexus_repo => "thirdparty", keep_versioned => 1 },
         ],
      },
   },
   {
      "dir"         => "zm-clam-scanner-store",
      "ant_targets" => ["publish-local", "test", "coverage", "sonar-scan"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-clam-scanner-store/build/dist");
         SysExec("cp -f -rp build/zm-clam-scanner-store-*.jar $CFG{BUILD_DIR}/zm-clam-scanner-store/build/dist");
      },
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-clam-scanner-store", dest_subdir => "build", keep_versioned => 1  },
         ],
      },
   },
   {
      "dir"         => "zm-licenses",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-licenses");
         SysExec("(cd .. && rsync -az --relative zm-licenses/ $CFG{BUILD_DIR}/)");
      },
   },
   {
      "dir"         => "zm-nginx-lookup-store",
      "ant_targets" => ["publish-local", "test", "coverage", "sonar-scan"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-nginx-lookup-store/build/dist");
         SysExec("cp -f -rp build/zm-nginx-lookup-store-*.jar $CFG{BUILD_DIR}/zm-nginx-lookup-store/build/dist");
      },
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-nginx-lookup-store", dest_subdir => "build", keep_versioned => 1  },
         ],
      },
   },
   {
      "dir"         => "zm-versioncheck-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-versioncheck-admin-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-versioncheck-admin-zimlet/build/zimlet");
      },
      "nexus_artifacts" => {
         type => 'zip',
         zips => [
            { dest_subdir => "build/zimlet" },
         ],
      }
   },
   {
      "dir"         => "zm-bulkprovision-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-bulkprovision-admin-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-bulkprovision-admin-zimlet/build/zimlet");
      },
      "nexus_artifacts" => {
         type => 'zip',
         zips => [
            { dest_subdir => "build/zimlet" },
         ],
      },
   },
   {
      "dir"         => "zm-certificate-manager-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-certificate-manager-admin-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-certificate-manager-admin-zimlet/build/zimlet");
      },
      "nexus_artifacts" => {
         type => 'zip',
         zips => [
            { dest_subdir => "build/zimlet" },
         ],
      },
   },
   {
      "dir"         => "zm-proxy-config-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-proxy-config-admin-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-proxy-config-admin-zimlet/build/zimlet");
      },
      "nexus_artifacts" => {
         type => 'zip',
         zips => [
            { dest_subdir => "build/zimlet" },
         ],
      },
   },
   {
      "dir"         => "zm-helptooltip-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-helptooltip-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-helptooltip-zimlet/build/zimlet");
      },
      "nexus_artifacts" => {
         type => 'zip',
         zips => [
            { dest_subdir => "build/zimlet" },
         ],
      },
   },
   {
      "dir"         => "zm-viewmail-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-viewmail-admin-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-viewmail-admin-zimlet/build/zimlet");
      },
      "nexus_artifacts" => {
         type => 'zip',
         zips => [
            { dest_subdir => "build/zimlet" },
         ],
      },
   },
   {
      "dir"         => "zm-zimlets",
      "ant_targets" => [ "package-zimlets", "jar", "sonar-scan" ],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-zimlets/conf");
         SysExec("cp -f conf/zimbra.tld $CFG{BUILD_DIR}/zm-zimlets/conf");
         SysExec("cp -f conf/web.xml.production $CFG{BUILD_DIR}/zm-zimlets/conf");
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-zimlets/build/dist/zimlets");
         SysExec("cp -f build/dist/zimlets/*.zip $CFG{BUILD_DIR}/zm-zimlets/build/dist/zimlets");
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-zimlets/build/dist");
         SysExec("cp -f build/dist/lib/zimlettaglib.jar $CFG{BUILD_DIR}/zm-zimlets/build/dist/zimlettaglib.jar");
      },
      "nexus_artifacts" => {
         type => ['jar', 'zip'],
         jars => [
            { name => "zm-zimlets", dest_subdir => "build/dist/lib", jar_filename => "zimlettaglib.jar" },
         ],
         zips => [
            { name => "com_zimbra_attachcontacts",     dest_subdir => "build/dist/zimlets" },
            { name => "com_zimbra_attachmail",         dest_subdir => "build/dist/zimlets" },
            { name => "com_zimbra_date",               dest_subdir => "build/dist/zimlets" },
            { name => "com_zimbra_email",              dest_subdir => "build/dist/zimlets" },
            { name => "com_zimbra_gotourl",            dest_subdir => "build/dist/zimlets" },
            { name => "com_zimbra_mailarchive",        dest_subdir => "build/dist/zimlets" },
            { name => "com_zimbra_phone",              dest_subdir => "build/dist/zimlets" },
            { name => "com_zimbra_srchhighlighter",    dest_subdir => "build/dist/zimlets" },
            { name => "com_zimbra_url",                dest_subdir => "build/dist/zimlets" },
            { name => "com_zimbra_webex",              dest_subdir => "build/dist/zimlets" },
            { name => "com_zimbra_ymemoticons",        dest_subdir => "build/dist/zimlets" },
         ],
      },
   },
   {
      "dir"             => "zm-web-client",
      "ant_targets"     => ["pkg"],
      "deploy_pkg_into" => "bundle",
      "nexus_artifacts" => {
         type     => 'package',
         packages => [ { name => "zimbra-mbox-webclient-war" } ],
      },
   },
   {
      "dir"         => "zm-admin-help-common",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("cp -f -r ../zm-admin-help-common $CFG{BUILD_DIR}");
      },
   },
   {
      "dir"         => "zm-versioncheck-utilities",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("(cd .. && rsync -az --relative zm-versioncheck-utilities/src/libexec/zmcheckversion $CFG{BUILD_DIR}/)");
      },
   },
   {
      "dir"         => "zm-webclient-portal-example",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("cp -f -r ../zm-webclient-portal-example $CFG{BUILD_DIR}");
      },
   },
   {
      "dir"         => "zm-downloads",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("(cd .. && rsync -az --relative --exclude '.git' zm-downloads $CFG{BUILD_DIR}/)");
      },
   },
   {
      "dir"         => "zm-db-conf",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("(cd .. && rsync -az --relative zm-db-conf/src/db/migration $CFG{BUILD_DIR}/)");
         SysExec("(cd .. && rsync -az --relative zm-db-conf/src/db/mysql     $CFG{BUILD_DIR}/)");
      },
   },
   {
      "dir"             => "zm-admin-console",
      "ant_targets"     => ["pkg"],
      "deploy_pkg_into" => "bundle",
      "nexus_artifacts" => {
         type     => 'package',
         packages => [ { name => "zimbra-mbox-admin-console-war" } ],
      },
   },
   {
      "dir"         => "zm-aspell",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("cp -f -r ../zm-aspell $CFG{BUILD_DIR}");
      },
   },
   {
      "dir"         => "zm-dnscache",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("cp -f -r ../zm-dnscache $CFG{BUILD_DIR}");
      },
   },
   {
      "dir"         => "zm-amavis",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("cp -f -r ../zm-amavis $CFG{BUILD_DIR}");
      },
   },
   {
      "dir"         => "zm-nginx-conf",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("cp -f -r ../zm-nginx-conf $CFG{BUILD_DIR}");
      },
   },
   {
      "dir"         => "zm-postfix",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("cp -f -r ../zm-postfix $CFG{BUILD_DIR}");
      },
   },
   {
      "dir"         => "zm-core-utils",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("cp -f -r ../zm-core-utils $CFG{BUILD_DIR}");
      },
   },
   {
      "dir"         => "zm-migration-tools",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("cp -f -r ../zm-migration-tools $CFG{BUILD_DIR}");
      },
   },
   {
      "dir"         => "zm-bulkprovision-store",
      "ant_targets" => ["jar", "sonar-scan"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-bulkprovision-store");
         SysExec("cp -f -r ../zm-bulkprovision-store/build $CFG{BUILD_DIR}/zm-bulkprovision-store");
      },
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-bulkprovision-store" },
            { name => "commons-csv", org => "org.apache.commons", nexus_repo => "thirdparty", keep_versioned => 1 },
         ],
      },
   },
   {
      "dir"         => "zm-certificate-manager-store",
      "ant_targets" => ["jar", "sonar-scan"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-certificate-manager-store");
         SysExec("cp -f -r ../zm-certificate-manager-store/build $CFG{BUILD_DIR}/zm-certificate-manager-store");
      },
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-certificate-manager-store", dest_subdir => "build" },
         ],
      },
   },
   {
      "dir"         => "zm-versioncheck-store",
      "ant_targets" => ["jar", "sonar-scan"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-versioncheck-store");
         SysExec("cp -f -r ../zm-versioncheck-store/build $CFG{BUILD_DIR}/zm-versioncheck-store");
      },
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-versioncheck-store", dest_subdir => "build" },
         ],
      },
   },
   {
      "dir"         => "zm-ldap-utils-store",
      "ant_targets" => ["jar", "sonar-scan"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-ldap-utils-store");
         SysExec("cp -f -r ../zm-ldap-utils-store/build $CFG{BUILD_DIR}/zm-ldap-utils-store");
      },
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-ldap-utils-store", dest_subdir => "build" },
         ],
      },
   },
   {
      "dir"         => "ant-1.7.0-ziputil-patched",
      "ant_targets" => ["jar", "sonar-scan"],
      "stage_cmd"   => undef,
      "nexus_artifacts" => { type => 'provided' },
   },
   {
      "dir"         => "ant-tar-patched",
      "ant_targets" => ["jar", "sonar-scan"],
      "stage_cmd"   => undef,
      "nexus_artifacts" => { type => 'provided' },
   },
   {
      "dir"         => "nekohtml-1.9.13",
      "ant_targets" => ["jar", "sonar-scan"],
      "stage_cmd"   => undef,
      "nexus_artifacts" => { type => 'provided' },
   },
   {
      "dir"         => "java-html-sanitizer-release-20190610.1",
      "ant_targets" => ["jar", "sonar-scan"],
      "stage_cmd"   => undef,
      "nexus_artifacts" => { type => 'provided' },
   },
   {
      "dir"         => "antisamy",
      "ant_targets" => ["jar", "sonar-scan"],
      "stage_cmd"   => undef,
      "nexus_artifacts" => { type => 'provided' },
   },
   {
      "dir"         => "ical4j-0.9.16-patched",
      "ant_targets" => [ "clean-compile", "package", "sonar-scan" ],
      "stage_cmd"   => undef,
      "nexus_artifacts" => { type => 'provided' },
   },
   {
      "dir"             => "zm-zcs-lib",
      "ant_targets"     => ["dist", "pkg"],
      "stage_cmd"       => sub {
         SysExec("(cd .. && rsync -az --relative zm-zcs-lib $CFG{BUILD_DIR}/)");
      },
      "deploy_pkg_into" => "bundle",
      "nexus_artifacts" => {
         type     => ['jar', 'package'],
         packages => [
            { name => "zimbra-common-core-libs" },
            { name => "zimbra-mbox-store-libs"  },
         ],
         jars => [
            { name => "oauth",              org => "oauth", keep_versioned => 1 },
            { name => "jedis",              org => "redis.clients",        nexus_repo => "thirdparty", keep_versioned => 1 },
            { name => "commons-pool2",      org => "org.apache.commons",   nexus_repo => "thirdparty", keep_versioned => 1 },
            { name => "java-jwt",           org => "com.auth0",            nexus_repo => "thirdparty", keep_versioned => 1 },
            { name => "tika-app",           org => "org.apache.tika",      nexus_repo => "thirdparty", keep_versioned => 1 },
            { name => "bcpkix-jdk15on",     org => "org.bouncycastle",     nexus_repo => "thirdparty", keep_versioned => 1 },
            { name => "bcmail-jdk15on",     org => "org.bouncycastle",     nexus_repo => "thirdparty", keep_versioned => 1 },
            { name => "bcprov-jdk15on",     org => "org.bouncycastle",     nexus_repo => "thirdparty", keep_versioned => 1 },
            { name => "saaj-impl",          org => "com.sun.xml.messaging.saaj", nexus_repo => "thirdparty", keep_versioned => 1 },
         ],
      },
   },
   {
      "dir"         => "zm-jython",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("(cd .. && rsync -az --relative zm-jython $CFG{BUILD_DIR}/)");
      },
   },
   {
      "dir"         => "zm-mta",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("(cd .. && rsync -az --relative zm-mta $CFG{BUILD_DIR}/)");
      },
   },
   {
      "dir"         => "zm-freshclam",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("(cd .. && rsync -az --relative zm-freshclam $CFG{BUILD_DIR}/)");
      },
   },
   {
      "dir"          => "zm-launcher",
      "make_targets" => ["JAVA_BINARY=/opt/zimbra/common/bin/java"],
      "stage_cmd"    => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-launcher/build/dist");
         SysExec("cp -f build/zmmailboxd* $CFG{BUILD_DIR}/zm-launcher/build/dist");
      },
      "nexus_artifacts" => {
         type => 'bin',
         bins => [
            { name => "zmmailboxdmgr",              dest_subdir => "build" },
            { name => "zmmailboxdmgr.unrestricted",  dest_subdir => "build" },
         ],
      },
   },
   {
      "dir"         => "zm-jetty-conf",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         SysExec("cp -f -r ../zm-jetty-conf $CFG{BUILD_DIR}");
      },
   },
   {
      "dir"         => "zm-oauth-social",
      "ant_targets" => ["publish-local", "oauth-social-common-jar", "oauth-social-jar", "test", "coverage", "sonar-scan"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-oauth-social/build/dist");
         SysExec("cp -f -rp build/zm-oauth-social*.jar $CFG{BUILD_DIR}/zm-oauth-social/build/dist");
      },
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-oauth-social", dest_subdir => "build", jar_filename => "zm-oauth-social.jar" },
            { name => "zm-oauth-social-common", dest_subdir => "build", jar_filename => "zm-oauth-social-common.jar" },
         ],
      },
   },
   {
      "dir"         => "zm-gql",
      "ant_targets" => ["publish-local", "test", "coverage", "sonar-scan"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-gql/build/dist");
         SysExec("cp -f -rp build/zm-gql-*.jar $CFG{BUILD_DIR}/zm-gql/build/dist");
      },
      "nexus_artifacts" => {
         type => 'jar',
         jars => [
            { name => "zm-gql", dest_subdir => "build", keep_versioned => 1   },
         ],
      },
   },
);
