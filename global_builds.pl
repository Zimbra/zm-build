@ENTRIES = (
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
      "dir"         => "zm-native",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-charset",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-common",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-soap",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-client",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-store", #FIXME CIRCULAR DEPENDENCY in zm-store and zm-taglib
      "partial"     => 1,
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-taglib",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-store", #FIXME CIRCULAR DEPENDENCY in zm-store and zm-taglib
      "ant_targets" => [ "publish-local", "war", "create-version-sql" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-store/build/dist");
         System("cp -f build/service.war $GLOBAL_BUILD_DIR/zm-store/build/dist");
         System("cp -f build/dist/versions-init.sql $GLOBAL_BUILD_DIR/zm-store/build/dist/");
         System("(cd .. && rsync -az --relative zm-store/docs $GLOBAL_BUILD_DIR/)");
         System("(cd .. && rsync -az --relative zm-store/conf $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-license-tools",
      "ant_targets" => [ "jar", "publish-local" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-license-tools");
         System("(cd .. && rsync -az --relative zm-license-tools/src/bin $GLOBAL_BUILD_DIR/)");
         System("cp -f -r ../zm-license-tools/build $GLOBAL_BUILD_DIR/zm-license-tools");
      },
   },
   {
      "dir"         => "zm-license-store",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-license-store/build/dist");
         System("cp -f -rp build/zm-license-store-*.jar $GLOBAL_BUILD_DIR/zm-license-store/build/dist");
      },
   },
   {
      "dir"         => "zm-network-store",
      "ant_targets" => [ "publish-local", "cmbsearch-jar" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-network-store/build/dist");
         System("cp -f -r ../zm-network-store/build $GLOBAL_BUILD_DIR/zm-network-store");
         System("cp -f build/zm-network-store-*.jar $GLOBAL_BUILD_DIR/zm-network-store/build/dist/zimbranetwork.jar");
         System("(cd .. && rsync -az --relative zm-network-store/src/bin $GLOBAL_BUILD_DIR/)");
         System("(cd .. && rsync -az --relative zm-network-store/src/libexec $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-ajax",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => undef,
   },
   {
      "dir"         => "zm-milter",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-milter/build/dist");
         System("(cd .. && rsync -az --relative zm-milter/conf $GLOBAL_BUILD_DIR/)");
         System("cp -f build/zm-milter*.jar $GLOBAL_BUILD_DIR/zm-milter/build/dist/zm-milter.jar");
      },
   },
   {
      "dir"         => "zm-xmbxsearch-store",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-xmbxsearch-store/build/dist");
         System("cp -f build/zm-xmbxsearch-store*.jar $GLOBAL_BUILD_DIR/zm-xmbxsearch-store/build/dist/zm-xmbxsearch-store.jar");
      },
   },
   {
      "dir"         => "zm-archive-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-archive-admin-zimlet/build/dist");
         System("cp -f build/zimlet/com_zimbra_archive.zip $GLOBAL_BUILD_DIR/zm-archive-admin-zimlet/build/dist");
      },
   },
   {
      "dir"         => "zm-xmbxsearch-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-xmbxsearch-zimlet/build/dist");
         System("cp -f build/zimlets-network/com_zimbra_xmbxsearch.zip $GLOBAL_BUILD_DIR/zm-xmbxsearch-zimlet/build/dist");
      },
   },
   {
      "dir"         => "zm-ldap-utilities",
      "ant_targets" => [ "build-dist" ],
      "stage_cmd"   => sub {
         System("(cd .. && rsync -az --relative zm-ldap-utilities/build/dist $GLOBAL_BUILD_DIR/)");
         System("(cd .. && rsync -az --relative zm-ldap-utilities/src/ldap/migration $GLOBAL_BUILD_DIR/)");
         System("(cd .. && rsync -az --relative zm-ldap-utilities/conf $GLOBAL_BUILD_DIR/)");
         System("(cd .. && rsync -az --relative zm-ldap-utilities/src/libexec $GLOBAL_BUILD_DIR/)");
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
      "dir"         => "zm-saml-consumer-store",
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         System("mkdir -p build/dist/saml/myonelogin");
         System("cp build/samlextn.jar build/dist/saml");
         System("cp docs/saml/README.txt build/dist/saml");
         System("cp build/tricipherextn.jar build/dist/saml/myonelogin");
         System("cp docs/myonelogin/README.txt build/dist/saml/myonelogin");
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-saml-consumer-store/build/dist");
         System("cp -f -rp build/dist $GLOBAL_BUILD_DIR/zm-saml-consumer-store/build");
      },
   },
   {
      "dir"         => "zm-archive-store",
      "ant_targets" => [ "publish-local", "dist" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-archive-store/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-archive-store/build");
      },
   },
   {
      "dir"         => "zm-backup-store",
      "ant_targets" => [ "publish-local", "dist", "create-init-sql" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-backup-store/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-backup-store/build");
         System("(cd .. && rsync -az --relative zm-backup-store/docs $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-voice-store",
      "ant_targets" => [ "publish-local", "dist" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-voice-store/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-voice-store/build");
         System("(cd .. && rsync -az --relative zm-voice-store/docs $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-voice-cisco-store",
      "ant_targets" => [ "publish-local", "dist" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-voice-cisco-store/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-voice-cisco-store/build");
      },
   },
   {
      "dir"         => "zm-voice-mitel-store",
      "ant_targets" => [ "publish-local", "dist" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-voice-mitel-store/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-voice-mitel-store/build");
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
      "dir"         => "zm-network-licenses",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-network-licenses");
         System("(cd .. && rsync -az --relative zm-network-licenses/ $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-twofactorauth-store",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-twofactorauth-store/build/dist");
         System("cp -f -p build/zm-twofactorauth-store-*.jar $GLOBAL_BUILD_DIR/zm-twofactorauth-store/build/dist");
         System("(cd .. && rsync -az --relative zm-twofactorauth-store/docs  $GLOBAL_BUILD_DIR/)");
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
      "dir"         => "zm-ews-stub",
      "ant_targets" => ["dist"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-ews-stub/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-ews-stub/build");
      },
   },
   {
      "dir"         => "zm-ews-common",
      "ant_targets" => [ "publish-local", "dist" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-ews-common/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-ews-common/build");
      },
   },
   {
      "dir"         => "zm-ews-store",
      "ant_targets" => [ "publish-local", "dist" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-ews-store/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-ews-store/build");
         System("cp -f -r ../zm-ews-store $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-sync-common",
      "ant_targets" => [ "publish-local", "dist" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-sync-common/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-sync-common/build");
      },
   },
   {
      "dir"         => "zm-sync-store",
      "ant_targets" => [ "publish-local", "dist" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-sync-store/build/dist");
         System("cp -f -r ../zm-sync-store $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-sync-client",
      "ant_targets" => ["publish-local"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-sync-client/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-sync-client/build");
      },
   },
   {
      "dir"         => "zm-sync-tools",
      "ant_targets" => [ "publish-local", "dist" ],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-sync-tools/build/dist");
         System("cp -f -r ../zm-sync-tools $GLOBAL_BUILD_DIR");
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
      "dir"         => "zm-2fa-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-2fa-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-2fa-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-backup-restore-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-backup-restore-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-backup-restore-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-convertd-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-convertd-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-convertd-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-delegated-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-delegated-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-delegated-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-hsm-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-hsm-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-hsm-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-license-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-license-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-license-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-mobile-sync-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-mobile-sync-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-mobile-sync-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-smime-applet",
      "ant_targets" => ["dist"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-smime-applet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-smime-applet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-smime-cert-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-smime-cert-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-smime-cert-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-uc-admin-zimlets/cisco",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-uc-admin-zimlets/cisco/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-uc-admin-zimlets/cisco/build/zimlet");
      },
   },
   {
      "dir"         => "zm-uc-admin-zimlets/mitel",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-uc-admin-zimlets/mitel/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-uc-admin-zimlets/mitel/build/zimlet");
      },
   },
   {
      "dir"         => "zm-uc-admin-zimlets/voiceprefs",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-uc-admin-zimlets/voiceprefs/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-uc-admin-zimlets/voiceprefs/build/zimlet");
      },
   },
   {
      "dir"         => "zm-ucconfig-admin-zimlet",
      "ant_targets" => ["package-zimlet"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-ucconfig-admin-zimlet/build/zimlet");
         System("cp -f build/zimlet/*.zip $GLOBAL_BUILD_DIR/zm-ucconfig-admin-zimlet/build/zimlet");
      },
   },
   {
      "dir"         => "zm-openoffice-store",
      "ant_targets" => ["build-dist"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-openoffice-store/build/dist");
         System("cp -f -r build/dist $GLOBAL_BUILD_DIR/zm-openoffice-store/build");
      },
   },
   {
      "dir"         => "zm-convertd-store",
      "ant_targets" => ["dist"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-convertd-store/build/dist");
         System("cp -f build/dist/lib/ext/zimbraconvertd/zimbraconvertd.jar $GLOBAL_BUILD_DIR/zm-convertd-store/build/dist");
         System("cp -f -r ../zm-convertd-store $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-zimlets",
      "ant_targets" => ["package-zimlets"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-zimlets/conf");
         System("cp -f conf/zimbra.tld $GLOBAL_BUILD_DIR/zm-zimlets/conf");
         System("cp -f conf/web.xml.production $GLOBAL_BUILD_DIR/zm-zimlets/conf");
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-zimlets/build/dist/zimlets");
         System("cp -f build/dist/zimlets/*.zip $GLOBAL_BUILD_DIR/zm-zimlets/build/dist/zimlets");
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
      "dir"         => "zm-touch-client",
      "ant_targets" => ["touch"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-touch-client/build");
         System("cp -f -r build/WebRoot $GLOBAL_BUILD_DIR/zm-touch-client/build");
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
      "dir"         => "zm-admin-help-network",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-admin-help-network $GLOBAL_BUILD_DIR");
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
      "dir"         => "zm-backup-utilities",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("(cd .. && rsync -az --relative zm-backup-utilities/src/bin $GLOBAL_BUILD_DIR/)");
         System("(cd .. && rsync -az --relative zm-backup-utilities/src/libexec $GLOBAL_BUILD_DIR/)");
         System("(cd .. && rsync -az --relative zm-backup-utilities/src/db  $GLOBAL_BUILD_DIR/)");
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
      "dir"         => "zm-network-build",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-network-build $GLOBAL_BUILD_DIR");
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
      "dir"         => "zm-convertd-native",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-convertd-native $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-hsm",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-hsm $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-archive-utils",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-archive-utils $GLOBAL_BUILD_DIR");
      },
   },
   {
      "dir"         => "zm-store-conf",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("cp -f -r ../zm-store-conf $GLOBAL_BUILD_DIR");
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
      "dir"         => "zm-freebusy-provider-store",
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-freebusy-provider-store");
         System("cp -f -r ../zm-freebusy-provider-store/build $GLOBAL_BUILD_DIR/zm-freebusy-provider-store");
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
      "dir"         => "zm-hsm-store",
      "ant_targets" => ["jar"],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-hsm-store");
         System("cp -f -r ../zm-hsm-store/build $GLOBAL_BUILD_DIR/zm-hsm-store");
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
      "ant_targets" => [ "dist" ],
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
      "dir"       => "zm-libnative",
      "make_targets" => [],
      "stage_cmd" => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-libnative/build/dist");
         System("cp -f build/*.so $GLOBAL_BUILD_DIR/zm-libnative/build/dist");
      },
   },
   {
      "dir"       => "zm-launcher",
      "make_targets" => ["JAVA_BINARY=/opt/zimbra/common/bin/java"],
      "stage_cmd" => sub {
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
   {
      "dir"         => "zm-rebranding-docs",
      "ant_targets" => undef,
      "stage_cmd"   => sub {
         System("(cd .. && rsync -az --relative zm-rebranding-docs $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-vmware-appmonitor",
      "ant_targets" => [ "dist" ],,
      "stage_cmd"   => sub {
         System("(cd .. && rsync -az --relative zm-vmware-appmonitor/build/dist $GLOBAL_BUILD_DIR/)");
      },
   },
   {
      "dir"         => "zm-postfixjournal",
      "make_targets" => [],
      "stage_cmd"   => sub {
         System("mkdir -p $GLOBAL_BUILD_DIR/zm-postfixjournal/build/dist");
         System("cp -f src/postjournal $GLOBAL_BUILD_DIR/zm-postfixjournal/build/dist");
      },
   },
);
