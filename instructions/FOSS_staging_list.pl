@ENTRIES = (
   {
      "dir"             => "zm-mailbox",
      "ant_targets"     => [ "all", "pkg" ],
      "deploy_pkg_into" => "bundle",
      "stage_cmd"       => sub {
         System("install -T -D store/build/dist/versions-init.sql $GLOBAL_BUILD_DIR/zm-mailbox/store/build/dist/versions-init.sql");
      },
   },
   {
      "dir"             => "zm-zextras",
      "make_targets"    => [ "PKG_RELEASE=1zimbra${GLOBAL_BUILD_RELEASE_NO_MAJOR}.${GLOBAL_BUILD_RELEASE_NO_MINOR}b1", "all" ],
      "deploy_pkg_into" => "repo-dev",
   },
   {
      "dir"         => "junixsocket/junixsocket-native",
      "mvn_targets" => ["package"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/junixsocket/junixsocket-native/build");
         System("cp -f target/nar/junixsocket-native-*/lib/*/jni/libjunixsocket-native-*.so $GLOBAL_BUILD_DIR/junixsocket/junixsocket-native/build/");
         System("cp -f target/junixsocket-native-*.nar  $GLOBAL_BUILD_DIR/junixsocket/junixsocket-native/build/");
      },
   },
   {
      "dir"         => "zm-taglib",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-taglib/build");
         System("cp -f build/zm-taglib*.jar  $GLOBAL_BUILD_DIR/zm-taglib/build/");
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
         System("(cd .. && rsync -az --relative zm-ldap-utilities/build/dist $GLOBAL_BUILD_DIR/)");
         System("(cd .. && rsync -az --relative zm-ldap-utilities/src/ldap/migration $GLOBAL_BUILD_DIR/)");
         System("(cd .. && rsync -az --relative zm-ldap-utilities/conf $GLOBAL_BUILD_DIR/)");
         System("(cd .. && rsync -az --relative zm-ldap-utilities/src/libexec $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-ajax",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-ssdb-ephemeral-store",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-ssdb-ephemeral-store/build/dist");
         System("cp -f build/zm-ssdb-ephemeral-store*.jar $GLOBAL_BUILD_DIR/zm-ssdb-ephemeral-store/build/dist");
      },
   },
   {
      "dir"         => "zm-openid-consumer-store",
      "ant_targets" => ["dist-package"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-openid-consumer-store/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-openid-consumer-store/build/");
      },
   },
   {
      "dir"         => "zm-clam-scanner-store",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-clam-scanner-store/build/dist");
         System("cp -f -rp build/zm-clam-scanner-store-*.jar $GLOBAL_BUILD_DIR/zm-clam-scanner-store/build/dist");
      },
   },
   {
      "dir"         => "zm-licenses",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-licenses");
         System("(cd .. && rsync -az --relative zm-licenses/ $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-nginx-lookup-store",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-nginx-lookup-store/build/dist");
         System("cp -f -rp build/zm-nginx-lookup-store-*.jar $GLOBAL_BUILD_DIR/zm-nginx-lookup-store/build/dist");
      },
   },
   {
      "dir"         => "zm-versioncheck-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-versioncheck-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-versioncheck-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-bulkprovision-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-bulkprovision-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-bulkprovision-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-certificate-manager-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-certificate-manager-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-certificate-manager-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-clientuploader-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-clientuploader-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-clientuploader-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-proxy-config-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-proxy-config-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-proxy-config-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-helptooltip-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-helptooltip-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-helptooltip-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-viewmail-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-viewmail-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-viewmail-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-zimlets",
      "ant_targets" => [ "package-zimlets", "jar" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-zimlets/conf");
         System("cp -f conf/zimbra.tld $GLOBAL_BUILD_DIR/zm-zimlets/conf");
         System("cp -f conf/web.xml.production $GLOBAL_BUILD_DIR/zm-zimlets/conf");
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-zimlets/build/dist/zimlets");
         System("cp -f build/dist/zimlets/*.zip $GLOBAL_BUILD_DIR/zm-zimlets/build/dist/zimlets");
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-zimlets/build/dist");
         System("cp -f build/dist/lib/zimlettaglib.jar $GLOBAL_BUILD_DIR/zm-zimlets/build/dist/zimlettaglib.jar");
      },
   },
   {
      "dir"         => "zm-web-client",
      "ant_targets" => [ "prod-war", "jspc.build" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-web-client/build/dist/jetty/webapps");
         System("cp -f build/dist/jetty/webapps/zimbra.war $GLOBAL_BUILD_DIR/zm-web-client/build/dist/jetty/webapps");
         System("cp -f -r build/dist/jetty/work $GLOBAL_BUILD_DIR/zm-web-client/build/dist/jetty");
         System("cp -f -r ../zm-web-client $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-help",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-help $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-admin-help-common",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-admin-help-common $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-versioncheck-utilities",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("(cd .. && rsync -az --relative zm-versioncheck-utilities/src/libexec/zmcheckversion $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-webclient-portal-example",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-webclient-portal-example $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-downloads",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-downloads $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-db-conf",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("(cd .. && rsync -az --relative zm-db-conf/src/db/migration $GLOBAL_BUILD_DIR/)");
         System("(cd .. && rsync -az --relative zm-db-conf/src/db/mysql     $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-admin-console",
      "ant_targets" => ["admin-war"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-admin-console/build/dist/jetty/webapps");
         System("cp -f build/dist/jetty/webapps/zimbraAdmin.war $GLOBAL_BUILD_DIR/zm-admin-console/build/dist/jetty/webapps");
         System("(cd .. && rsync -az --relative zm-admin-console/WebRoot/WEB-INF  $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-aspell",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-aspell $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-dnscache",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-dnscache $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-amavis",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-amavis $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-nginx-conf",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-nginx-conf $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-postfix",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-postfix $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-core-utils",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-core-utils $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-migration-tools",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-migration-tools $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-bulkprovision-store",
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-bulkprovision-store");
         System("cp -f -r ../zm-bulkprovision-store/build $GLOBAL_BUILD_DIR/zm-bulkprovision-store");
      },
   },
   {
      "dir"         => "zm-certificate-manager-store",
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-certificate-manager-store");
         System("cp -f -r ../zm-certificate-manager-store/build $GLOBAL_BUILD_DIR/zm-certificate-manager-store");
      },
   },
   {
      "dir"         => "zm-clientuploader-store",
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-clientuploader-store");
         System("cp -f -r ../zm-clientuploader-store/build $GLOBAL_BUILD_DIR/zm-clientuploader-store");
      },
   },
   {
      "dir"         => "zm-versioncheck-store",
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-versioncheck-store");
         System("cp -f -r ../zm-versioncheck-store/build $GLOBAL_BUILD_DIR/zm-versioncheck-store");
      },
   },
   {
      "dir"         => "zm-ldap-utils-store",
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-ldap-utils-store");
         System("cp -f -r ../zm-ldap-utils-store/build $GLOBAL_BUILD_DIR/zm-ldap-utils-store");
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
      "dir"         => "ical4j-0.9.16-patched",
      "ant_targets" => [ "clean-compile", "package" ],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-zcs-lib",
      "ant_targets" => ["dist"],
      "stage_cmd"   => sub {
         System("(cd .. && rsync -az --relative zm-zcs-lib $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-jython",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("(cd .. && rsync -az --relative zm-jython $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-mta",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("(cd .. && rsync -az --relative zm-mta $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-freshclam",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("(cd .. && rsync -az --relative zm-freshclam $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"          => "zm-launcher",
      "make_targets" => ["JAVA_BINARY=/opt/zimbra/common/bin/java"],
      "stage_cmd"    => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-launcher/build/dist");
         System("cp -f build/zmmailboxd* $GLOBAL_BUILD_DIR/zm-launcher/build/dist");
      },
   },
   {
      "dir"         => "zm-jetty-conf",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-jetty-conf $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-timezones",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("(cd .. && rsync -az --relative zm-timezones $GLOBAL_BUILD_DIR/)");
      },
   },
);
