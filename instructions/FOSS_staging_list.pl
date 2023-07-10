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
   },
   {
      "dir"         => "zm-mailbox/store",
      "ant_targets" => ["publish-store-test"],
      "stage_cmd"   => undef,
   },
   {
      # This repo can be removed and made independent of zm-zextras
      # This cannot be done unless the packages from zm-timezones are pushed to public repo
      # This is already excluded in CircleCI builds
      "dir"             => "zm-timezones",
      "ant_targets"     => ["pkg"],
      "deploy_pkg_into" => "bundle",
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
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-taglib/build");
         SysExec("cp -f build/zm-taglib*.jar  $CFG{BUILD_DIR}/zm-taglib/build/");
      },
   },
   {
      "dir"         => "zm-charset",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
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
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-admin-ajax",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-ssdb-ephemeral-store",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-ssdb-ephemeral-store/build/dist");
         SysExec("cp -f build/zm-ssdb-ephemeral-store*.jar $CFG{BUILD_DIR}/zm-ssdb-ephemeral-store/build/dist");
      },
   },
   {
      "dir"         => "zm-openid-consumer-store",
      "ant_targets" => ["dist-package"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-openid-consumer-store/build/dist");
         SysExec("cp -f -r build/dist $CFG{BUILD_DIR}/zm-openid-consumer-store/build/");
      },
   },
   {
      "dir"         => "zm-clam-scanner-store",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-clam-scanner-store/build/dist");
         SysExec("cp -f -rp build/zm-clam-scanner-store-*.jar $CFG{BUILD_DIR}/zm-clam-scanner-store/build/dist");
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
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-nginx-lookup-store/build/dist");
         SysExec("cp -f -rp build/zm-nginx-lookup-store-*.jar $CFG{BUILD_DIR}/zm-nginx-lookup-store/build/dist");
      },
   },
   {
      "dir"         => "zm-versioncheck-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-versioncheck-admin-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-versioncheck-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-bulkprovision-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-bulkprovision-admin-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-bulkprovision-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-certificate-manager-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-certificate-manager-admin-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-certificate-manager-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-proxy-config-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-proxy-config-admin-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-proxy-config-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-helptooltip-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-helptooltip-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-helptooltip-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-viewmail-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-viewmail-admin-zimlet/build/zimlet");
         SysExec("cp -f build/zimlet/*.zip $CFG{BUILD_DIR}/zm-viewmail-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-zimlets",
      "ant_targets" => [ "package-zimlets", "jar" ],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-zimlets/conf");
         SysExec("cp -f conf/zimbra.tld $CFG{BUILD_DIR}/zm-zimlets/conf");
         SysExec("cp -f conf/web.xml.production $CFG{BUILD_DIR}/zm-zimlets/conf");
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-zimlets/build/dist/zimlets");
         SysExec("cp -f build/dist/zimlets/*.zip $CFG{BUILD_DIR}/zm-zimlets/build/dist/zimlets");
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-zimlets/build/dist");
         SysExec("cp -f build/dist/lib/zimlettaglib.jar $CFG{BUILD_DIR}/zm-zimlets/build/dist/zimlettaglib.jar");
      },
   },
   {
      "dir"         => "zm-web-client",
      "ant_targets"     => ["pkg"],
      "deploy_pkg_into" => "bundle",
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
      "dir"         => "zm-admin-console",
      "ant_targets" => ["pkg"],
      "deploy_pkg_into" => "bundle",
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
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-bulkprovision-store");
         SysExec("cp -f -r ../zm-bulkprovision-store/build $CFG{BUILD_DIR}/zm-bulkprovision-store");
      },
   },
   {
      "dir"         => "zm-certificate-manager-store",
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-certificate-manager-store");
         SysExec("cp -f -r ../zm-certificate-manager-store/build $CFG{BUILD_DIR}/zm-certificate-manager-store");
      },
   },
   {
      "dir"         => "zm-versioncheck-store",
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-versioncheck-store");
         SysExec("cp -f -r ../zm-versioncheck-store/build $CFG{BUILD_DIR}/zm-versioncheck-store");
      },
   },
   {
      "dir"         => "zm-ldap-utils-store",
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-ldap-utils-store");
         SysExec("cp -f -r ../zm-ldap-utils-store/build $CFG{BUILD_DIR}/zm-ldap-utils-store");
      },
   },
   {
      "dir"         => "ant-1.7.0-ziputil-patched",
      "ant_targets" => ["jar"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "ant-tar-patched",
      "ant_targets" => ["jar"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "nekohtml-1.9.13",
      "ant_targets" => ["jar"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "java-html-sanitizer-release-20190610.1",
      "ant_targets" => ["jar"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "antisamy",
      "ant_targets" => ["jar"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "ical4j-0.9.16-patched",
      "ant_targets" => [ "clean-compile", "package" ],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-zcs-lib",
      "ant_targets" => ["dist", "pkg"],
      "stage_cmd"   => sub {
         SysExec("(cd .. && rsync -az --relative zm-zcs-lib $CFG{BUILD_DIR}/)");
      },
      "deploy_pkg_into" => "bundle",
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
      "ant_targets" => ["publish-local", "oauth-social-common-jar", "oauth-social-jar"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-oauth-social/build/dist");
         SysExec("cp -f -rp build/zm-oauth-social*.jar $CFG{BUILD_DIR}/zm-oauth-social/build/dist");
      },
   },
   
   {
      "dir"         => "zm-gql",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         SysExec("mkdir -p $CFG{BUILD_DIR}/zm-gql/build/dist");
         SysExec("cp -f -rp build/zm-gql-*.jar $CFG{BUILD_DIR}/zm-gql/build/dist");
      },
   },
);
