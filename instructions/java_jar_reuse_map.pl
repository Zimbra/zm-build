# Java JAR reuse from Nexus (see build.pl NexusJavaJarReuseAttempt).
#
# Keys are exact "dir" values from instructions/*_staging_list.pl.
# Return an empty hash to disable reuse (default until entries are added).
#
# Example (publish matching GAV to Nexus first, then add entries here):
#
# +{
#    'zm-taglib' => {
#       git_repo => 'zm-taglib',
#       require_git_sha_match => 0,
#       artifacts => [
#          { groupId => 'com.zimbra', artifactId => 'zm-taglib', packaging => 'jar', classifier => '' },
#       ],
#       install_paths => [ { into => 'build' } ],
#    },
# };
#
# Optional: require_git_sha_match => 1 expects in Nexus next to the JAR:
#   <artifactId>-<version>.buildinfo.json  with  "gitSha":"<40-char-sha>"
#
# Version in build.pl: BUILD_RELEASE_NO, plus "-" + lowercase candidate when not GA.

use strict;
use warnings;

+{};
