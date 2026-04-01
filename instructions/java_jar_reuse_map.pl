# Java JAR reuse from Nexus (see build.pl NexusJavaJarReuseAttempt).
#
# Keys are exact "dir" values from instructions/*_staging_list.pl.
# Coordinates match Ivy: organisation=groupId, module=artifactId (see each repo's ivy.xml).
#
# version_style:
#   ivy_dev    — default; version = MAJOR.MINOR.MICRO.<git commit epoch>[-candidate],
#                same as Ant dev.version / Ivy pubrevision (matches zimbra-jar output).
#   release_no — BUILD_RELEASE_NO only (set when Nexus stores e.g. 10.1.0 without timestamp).
#
# Publishing (build.pl): after a fresh compile, jars are PUT to NEXUS_MAVEN_REPO_BASE as
#   <group path>/<artifactId>/<version>/<artifactId>-<version>.jar
# plus <artifactId>-<version>.buildinfo.json when NEXUS_PUBLISH is on (see Jenkins NEXUS_PUBLISH*).
#
# publish_globs: optional list of globs (relative to repo dir) if the default
#   build/<artifactId>*.jar, build/<artifactId>-*.jar, build/dist/... misses the jar.

use strict;
use warnings;

+{
   'zm-charset' => {
      git_repo                => 'zm-charset',
      require_git_sha_match   => 0,
      version_style           => 'ivy_dev',
      groupId                 => 'zimbra',
      artifactId              => 'zm-charset',
      artifacts               => [ { groupId => 'zimbra', artifactId => 'zm-charset', packaging => 'jar', classifier => '' }, ],
      install_paths           => [ { into => 'build' }, ],
   },
   'zm-taglib' => {
      git_repo              => 'zm-taglib',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-taglib',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-taglib', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, ],
   },
   'zm-ajax' => {
      git_repo              => 'zm-ajax',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-ajax',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-ajax', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, ],
   },
   'zm-admin-ajax' => {
      git_repo              => 'zm-admin-ajax',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-admin-ajax',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-admin-ajax', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, ],
   },
   'zm-ldap-utilities' => {
      git_repo              => 'zm-ldap-utilities',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-ldap-utilities',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-ldap-utilities', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, ],
   },
   'zm-ssdb-ephemeral-store' => {
      git_repo              => 'zm-ssdb-ephemeral-store',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-ssdb-ephemeral-store',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-ssdb-ephemeral-store', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, { into => 'build/dist' }, ],
   },
   'zm-openid-consumer-store' => {
      git_repo              => 'zm-openid-consumer-store',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-openid-consumer-store',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-openid-consumer-store', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, { into => 'build/dist' }, ],
   },
   'zm-clam-scanner-store' => {
      git_repo              => 'zm-clam-scanner-store',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-clam-scanner-store',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-clam-scanner-store', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, { into => 'build/dist' }, ],
   },
   'zm-nginx-lookup-store' => {
      git_repo              => 'zm-nginx-lookup-store',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-nginx-lookup-store',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-nginx-lookup-store', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, { into => 'build/dist' }, ],
   },
   'zm-gql' => {
      git_repo              => 'zm-gql',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-gql',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-gql', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, { into => 'build/dist' }, ],
   },
   'zm-oauth-social' => {
      git_repo              => 'zm-oauth-social',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-oauth-social',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-oauth-social', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, { into => 'build/dist' }, ],
   },
   'zm-ldap-utils-store' => {
      git_repo              => 'zm-ldap-utils-store',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-ldap-utils-store',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-ldap-utils-store', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, ],
   },
   'zm-certificate-manager-store' => {
      git_repo              => 'zm-certificate-manager-store',
      require_git_sha_match => 0,
      version_style         => 'ivy_dev',
      groupId               => 'zimbra',
      artifactId            => 'zm-certificate-manager-store',
      artifacts             => [ { groupId => 'zimbra', artifactId => 'zm-certificate-manager-store', packaging => 'jar', classifier => '' }, ],
      install_paths         => [ { into => 'build' }, ],
   },
};
