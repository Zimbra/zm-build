#!/usr/bin/perl

use strict;
use warnings;
use File::Basename qw(basename);
use File::Path     qw(make_path);
use IPC::Cmd       qw(run);

sub NexusPrefetch {
    my ($build_info) = @_;
    my $dir = $build_info->{dir};
    my $artifacts = $build_info->{nexus_artifacts};
    return 'noop' unless defined $artifacts;

    my $type = $artifacts->{type} // 'none';
    my @types = ref($type) eq 'ARRAY' ? @$type : ($type);
    return 'noop' if grep { $_ eq 'none' } @types;

    ( my $repo_name = $dir ) =~ s|/.*||;

    my $overridden = exists $CFG{GIT_OVERRIDES}{"$repo_name.branch"}
              || exists $CFG{GIT_OVERRIDES}{"$repo_name.tag"}
              || exists $CFG{GIT_OVERRIDES}{"$repo_name.remote"}
              || exists $CFG{GIT_OVERRIDES}{"$repo_name.repo_name_suffix"};

   if ( grep { $_ eq 'provided' } @types ) {
       if ( $overridden ) {
           print color('cyan')
               . "  [NEXUS] $repo_name is in git-overrides — compiling locally\n"
               . color('reset');
           return 'noop';
       }
       print color('green')
           . "  [NEXUS] $dir — provided, skipping compile\n"
           . color('reset');
       return 'provided';
   }

   if ($overridden) {
        print color('cyan')
            . "  [NEXUS] $repo_name is in git-overrides — compiling locally\n"
            . color('reset');
        return 'noop';
    }

    print color('blue')
        . "  [NEXUS] Fetching artifacts for $dir (type=" . join('+', @types) . ") ...\n"
        . color('reset');

    my $ok = 1;

    if ( grep { $_ eq 'jar'     } @types ) {
        $ok = _FetchJars( $dir, $repo_name, $artifacts ) && $ok;
    }

    if ( grep { $_ eq 'sql'     } @types ) {
        $ok = _FetchSqls( $dir, $repo_name, $artifacts ) && $ok;

    }

    if ( grep { $_ eq 'zip'     } @types ) {
        $ok = _FetchZips( $dir, $repo_name, $artifacts ) && $ok;
    }

    if ( grep { $_ eq 'bin'     } @types ) {
    $ok = _FetchBins( $dir, $repo_name, $artifacts ) && $ok;
    }
    
    if ( grep { $_ eq 'package' } @types ) {
        $ok = _FetchPackages( $dir, $repo_name, $artifacts ) && $ok;
    }

    if ($ok) {
        if ( my $post_fetch = $artifacts->{post_fetch} ) {
            print "  [NEXUS] Running post_fetch for $dir ...\n";
            my $hook_ok = eval { &$post_fetch };
            if ( $@ || !$hook_ok ) {
                _Warn("post_fetch failed for $dir: $@");
                return 'fallback';
            }
        }

        print color('green')
            . "  [NEXUS] OK $dir — skipping compile\n"
            . color('reset');
        return 'skip';
    }
    else {
        print color('yellow')
            . "  [NEXUS] WARN $dir — fetch failed, falling back to compile\n"
            . color('reset');
        return 'fallback';
    }
}

sub _FetchJars {
    my ( $dir, $repo_name, $artifacts ) = @_;

    my $jars = $artifacts->{jars};
    unless ( $jars && @$jars ) {
        _Warn("No jars defined for $dir in nexus_artifacts");
        return 0;
    }

    for my $jar (@$jars) {
        my $name        = $jar->{name}        or do { _Warn("jar entry missing 'name' for $dir"); return 0; };
        my $org         = $jar->{org}         // 'zimbra';
        my $nexus_repo  = $jar->{nexus_repo}  // $CFG{NEXUS_JAR_REPO};
        my $dest_subdir = $jar->{dest_subdir} // 'build/dist';

        my ( $url, $filename ) = _ResolveLatestAsset(
            repo      => $nexus_repo,
            name      => $name,
            org       => $org,
            extension => 'jar',
        );

        unless ( $url && $filename ) {
            _Warn("Could not resolve jar: org=$org name=$name in repo=$nexus_repo");
            return 0;
        }

        my $dest_dir  = "$CFG{BUILD_SOURCES_BASE_DIR}/$repo_name/$dest_subdir";
        my $dest_file = "$dest_dir/$filename";

        make_path($dest_dir) unless -d $dest_dir;
        unlink glob "$dest_dir/${name}-*.jar";
        unlink "$dest_dir/$name.jar" if -f "$dest_dir/$name.jar";
        my $final_name = $jar->{jar_filename}   ? $jar->{jar_filename}
               : $jar->{keep_versioned} ? $filename
               :                         "$name.jar";
        my $final_file = "$dest_dir/$final_name";

        unless ( _Download( $url, $dest_file ) ) {
            _Warn("Download failed for $name.jar");
            return 0;
        }

        unless ( rename( $dest_file, $final_file ) ) {
            _Warn("Could not rename $dest_file to $final_file: $!");
            return 0;
        }

        print "  [NEXUS] jar  OK: $repo_name/$dest_subdir/$final_name\n";
    }

    return 1;
}

sub _FetchSqls {
    my ( $dir, $repo_name, $artifacts ) = @_;

    my $sqls = $artifacts->{sqls};
    unless ( $sqls && @$sqls ) {
        _Warn("No sqls defined for $dir in nexus_artifacts");
        return 0;
    }

    for my $sql (@$sqls) {
        my $name        = $sql->{name}        or do { _Warn("sql entry missing 'name' for $dir");       return 0; };
        my $classifier  = $sql->{classifier}  or do { _Warn("sql entry missing 'classifier' for $dir"); return 0; };
        my $extension   = $sql->{extension}   // 'sql';
        my $org         = $sql->{org}         // 'zimbra';
        my $nexus_repo  = $sql->{nexus_repo}  // $CFG{NEXUS_JAR_REPO};
        my $dest_subdir = $sql->{dest_subdir} // 'build/dist';

        my ( $url, $filename ) = _ResolveLatestAsset(
            repo       => $nexus_repo,
            name       => $name,
            org        => $org,
            extension  => $extension,
            classifier => $classifier,
        );

        unless ( $url && $filename ) {
            _Warn("Could not resolve sql: org=$org name=$name classifier=$classifier in repo=$nexus_repo");
            return 0;
        }

        my $dest_dir  = "$CFG{BUILD_SOURCES_BASE_DIR}/$repo_name/$dest_subdir";
        my $dest_file = "$dest_dir/$filename";

        make_path($dest_dir) unless -d $dest_dir;
        unlink glob "$dest_dir/${name}-*.$extension";

        my $final_name = $sql->{sql_filename}
              ? $sql->{sql_filename}
              : "$name-$classifier.$extension";
        my $final_file = "$dest_dir/$final_name";

        unless ( _Download( $url, $dest_file ) ) {
            _Warn("Download failed for $name-$classifier.$extension");
            return 0;
        }

        unless ( rename( $dest_file, $final_file ) ) {
            _Warn("Could not rename $dest_file to $final_file: $!");
            return 0;
        }

        print "  [NEXUS] sql  OK: $repo_name/$dest_subdir/$final_name\n";
    }

    return 1;
}
sub _FetchZips {
    my ( $dir, $repo_name, $artifacts ) = @_;

    my $zips = $artifacts->{zips};
    unless ( $zips && @$zips ) {
        _Warn("No zips defined for $dir in nexus_artifacts");
        return 0;
    }

    my $overall_ok = 1;

    for my $zip (@$zips) {
        my $name        = $zip->{name}       // $repo_name;
        my $nexus_repo  = $zip->{nexus_repo} // $CFG{NEXUS_RAW_REPO};
        my $dest_subdir = $zip->{dest_subdir} // 'build/zimlet';

        my ( $url, $filename ) = _ResolveLatestAsset(
            repo      => $nexus_repo,
            name      => $name,
            extension => 'zip',
        );

        unless ( $url && $filename ) {
            _Warn("Could not resolve zip: name=$name in repo=$nexus_repo");
            $overall_ok = 0;
            next;
        }

        my $dest_dir  = "$CFG{BUILD_SOURCES_BASE_DIR}/$dir/$dest_subdir";
        my $dest_file = "$dest_dir/$filename";

        make_path($dest_dir) unless -d $dest_dir;

        unless ( _Download( $url, $dest_file ) ) {
            _Warn("Download failed for $filename");
            $overall_ok = 0;
            next;
        }

        print "  [NEXUS] zip  OK: $dir/$dest_subdir/$filename\n";
    }

    return $overall_ok;
}

# ==========================================================================
# _FetchBins: fetches "raw" binary artifacts
# ==========================================================================
sub _FetchBins {
    my ( $dir, $repo_name, $artifacts ) = @_;

    my $bins = $artifacts->{bins};
    unless ( $bins && @$bins ) {
        _Warn("No bins defined for $dir in nexus_artifacts");
        return 0;
    }

    my $overall_ok = 1;

    for my $bin (@$bins) {
        my $name        = $bin->{name}       or do { _Warn("bin entry missing 'name' for $dir"); $overall_ok = 0; next; };
        my $nexus_repo  = $bin->{nexus_repo} // $CFG{NEXUS_RAW_REPO};
        my $nexus_group = $bin->{nexus_group} // $repo_name;
        my $dest_subdir = $bin->{dest_subdir} // 'build/dist';
        my $filename    = $bin->{filename}    // $name;

        my ( $download_url, $resolved_filename ) = _ResolveLatestRawAsset(
            repo        => $nexus_repo,
            repo_name   => $nexus_group,
            name_prefix => $name,
        );

        unless ( $download_url ) {
            _Warn("Could not resolve bin: $nexus_group/$name in repo=$nexus_repo");
            $overall_ok = 0;
            next;
        }

        my $dest_dir  = "$CFG{BUILD_SOURCES_BASE_DIR}/$dir/$dest_subdir";
        my $dest_file = "$dest_dir/$filename";

        make_path($dest_dir) unless -d $dest_dir;

        unless ( _Download( $download_url, $dest_file ) ) {
            _Warn("Download failed for $name (resolved: $resolved_filename)");
            $overall_ok = 0;
            next;
        }

        chmod 0755, $dest_file;

        print "  [NEXUS] bin  OK: $dir/$dest_subdir/$filename (from $resolved_filename)\n";
    }

    return $overall_ok;
}

sub _FetchPackages {
    my ( $dir, $repo_name, $artifacts ) = @_;

    my $packages = $artifacts->{packages};
    unless ( $packages && @$packages ) {
        _Warn("No packages defined for $dir in nexus_artifacts");
        return 0;
    }

    my ( $pkg_ext, $default_pkg_repo );
    if ( $CFG{BUILD_OS} =~ /UBUNTU/i ) {
        $pkg_ext = 'deb';

        my %os_to_distro = (
            UBUNTU18_64 => 'bionic',
            UBUNTU20_64 => 'focal',
            UBUNTU22_64 => 'jammy',
            UBUNTU24_64 => 'noble',
        );
        my $distro = $os_to_distro{ $CFG{BUILD_OS} };
        unless ( $distro ) {
            _Warn("Unknown Ubuntu BUILD_OS '$CFG{BUILD_OS}' — cannot compute Nexus APT repo suffix");
            return 0;
        }

        my $apt_base = $CFG{NEXUS_APT_REPO};
        unless ( $apt_base ) {
            _Warn("NEXUS_APT_REPO not set — cannot fetch packages for $dir");
            return 0;
        }
        $default_pkg_repo = "$apt_base-$distro";
    }
    elsif ( $CFG{BUILD_OS} =~ /RHEL|CENTOS|ROCKY|ALMA/i ) {
        $pkg_ext          = 'rpm';
        $default_pkg_repo = $CFG{NEXUS_YUM_REPO};
        unless ( $default_pkg_repo ) {
            _Warn("NEXUS_YUM_REPO not set — cannot fetch packages for $dir");
            return 0;
        }
    }
    else {
        _Warn("Unknown BUILD_OS '$CFG{BUILD_OS}' — cannot fetch packages for $dir");
        return 0;
    }

    my $pkg_os_tag = $CFG{PKG_OS_TAG};

    for my $pkg (@$packages) {
        my $name     = $pkg->{name} or do { _Warn("package entry missing 'name' for $dir"); return 0; };
        my $apt_repo = $pkg->{nexus_apt_repo} // $default_pkg_repo;
        my $yum_repo = $pkg->{nexus_yum_repo} // $default_pkg_repo;
        my $repo     = ( $pkg_ext eq 'deb' ) ? $apt_repo : $yum_repo;

        my ( $url, $filename ) = _ResolveLatestAsset(
            repo      => $repo,
            name      => $name,
            extension => $pkg_ext,
        );

        unless ( $url && $filename ) {
            _Warn("Could not resolve package: $name.$pkg_ext in repo=$repo");
            return 0;
        }

        my $dest_dir  = "$CFG{BUILD_SOURCES_BASE_DIR}/$repo_name/build/dist/$pkg_os_tag";
        my $dest_file = "$dest_dir/$filename";
        make_path($dest_dir) unless -d $dest_dir;
        if ( $pkg_ext eq 'deb' ) {
            unlink glob "$dest_dir/${name}_*.$pkg_ext";
        } else {
            unlink glob "$dest_dir/${name}-[0-9]*.$pkg_ext";
        }

        unless ( _Download( $url, $dest_file ) ) {
            _Warn("Download failed for $name.$pkg_ext");
            return 0;
        }

        print "  [NEXUS] pkg  OK: $repo_name/build/dist/$pkg_os_tag/$filename\n";
    }

    return 1;
}

sub _NexusUser { my $v = $CFG{NEXUS_USER}     // ''; $v =~ s/^\s+|\s+$//g; return $v; }
sub _NexusPass { my $v = $CFG{NEXUS_PASSWORD} // ''; $v =~ s/^\s+|\s+$//g; return $v; }
sub _NexusBase { my $v = $CFG{NEXUS_BASE_URL} // ''; $v =~ s/^\s+|\s+$//g; return $v; }

sub _ResolveLatestAsset {
    my (%args) = @_;

    my $repo      = $args{repo}      or return ( undef, undef );
    my $name      = $args{name}      or return ( undef, undef );
    my $extension = $args{extension} or return ( undef, undef );
    my $org        = $args{org};
    my $classifier = $args{classifier};

    my $base = _NexusBase();
    my $user = _NexusUser();
    my $pass = _NexusPass();

    my $search_url =
        "$base/service/rest/v1/search/assets"
      . "?repository=" . _enc($repo)
      . "&sort=version&direction=desc";

    if ( $extension eq 'jar' ) {
        $search_url .= "&name="            . _enc($name);
        $search_url .= "&maven.extension=jar";
        $search_url .= "&maven.groupId="   . _enc($org) if defined $org;
    }
    elsif ( $extension eq 'sql' ) {
        $search_url .= "&name="             . _enc($name);
        $search_url .= "&maven.extension=sql";
        $search_url .= "&maven.groupId="    . _enc($org)        if defined $org;
        $search_url .= "&maven.classifier=" . _enc($classifier) if defined $classifier;
    }
    
    elsif ( $extension eq 'zip' ) {
        $search_url .= "&q=" . _enc($name);
    }
    else {
        $search_url .= "&name=" . _enc($name);
    }

    my $json = _CurlGet( $search_url, $user, $pass );
    return ( undef, undef ) unless defined $json && $json ne '';

    my @paths = $json =~ /"path"\s*:\s*"([^"]+\.$extension)"/g;
    unless (@paths) {
        if ( $json =~ /"items"\s*:\s*\[\s*\]/ ) {
            _Warn("No assets found: name=$name ext=$extension repo=$repo");
        }
        else {
            _Warn("Could not parse path for $name.$extension from Nexus response");
        }
        return ( undef, undef );
    }

    my $asset_path;
    if ( $extension eq 'jar' || $extension eq 'sql' || $extension eq 'zip' ) {
        $asset_path = $paths[0];
    }
    else {
        my $pkg_os_tag = $CFG{PKG_OS_TAG} // '';
        ($asset_path) = grep { /\Q$pkg_os_tag\E/ } @paths;
        unless ($asset_path) {
            _Warn("No $pkg_os_tag package found for $name in $repo — available: " . join(", ", map { basename($_) } @paths));
            return ( undef, undef );
        }
    }

    $asset_path =~ s|^/||;
    my $download_url = "$base/repository/$repo/$asset_path";
    my $filename     = basename($asset_path);

    print "  [NEXUS] Resolved $name.$extension -> $filename\n";
    return ( $download_url, $filename );
}
sub _ResolveLatestRawAsset {
    my (%args) = @_;

    my $repo        = $args{repo}        or return ( undef, undef );
    my $repo_name   = $args{repo_name}   or return ( undef, undef );
    my $name_prefix = $args{name_prefix} or return ( undef, undef );

    # Strip a trailing compressed-archive extension for the search term,
    # e.g. "appmonitor-dist.tar.gz" -> "appmonitor-dist"
    ( my $search_prefix = $name_prefix ) =~ s/(\.tar\.gz|\.tgz|\.zip|\.gz)$//i;

    my $base = _NexusBase();
    my $user = _NexusUser();
    my $pass = _NexusPass();

    my $search_url =
        "$base/service/rest/v1/search/assets"
      . "?repository=" . _enc($repo)
      . "&q="           . _enc($search_prefix);

    my $json = _CurlGet( $search_url, $user, $pass );
    return ( undef, undef ) unless defined $json && $json ne '';

    my @paths = $json =~ /"path"\s*:\s*"([^"]+)"/g;
    unless (@paths) {
        _Warn("No raw assets found for prefix=$search_prefix in repo=$repo");
        return ( undef, undef );
    }

    # Only keep assets that live under <repo_name>/<version>/<search_prefix>-...
    my @matches = grep {
        m{^/?\Q$repo_name\E/[^/]+/\Q$search_prefix\E-}
    } @paths;

    unless (@matches) {
        _Warn("No raw assets under $repo_name/ matching prefix=$search_prefix in repo=$repo — available: "
              . join(", ", map { basename($_) } @paths));
        return ( undef, undef );
    }

    @matches = sort { $b cmp $a } @matches;
    my $asset_path = $matches[0];

    $asset_path =~ s|^/||;
    my $download_url = "$base/repository/$repo/$asset_path";
    my $filename      = basename($asset_path);

    print "  [NEXUS] Resolved $name_prefix -> $filename\n";
    return ( $download_url, $filename );
}

sub _Download {
    my ( $url, $dest_path ) = @_;

    my $user = _NexusUser();
    my $pass = _NexusPass();

    my @cmd = (
        'curl',
        '-sf',
        '-u', "$user:$pass",
        '--max-time', '120',
        '--retry',    '2',
        '-o', $dest_path,
        $url,
    );

    my ( $ok, $err ) = run( command => \@cmd, verbose => 0 );

    unless ($ok) {
        _Warn("curl failed: $err");
        unlink $dest_path if -f $dest_path;
        return 0;
    }

    unless ( -s $dest_path ) {
        _Warn("Downloaded file is empty: $dest_path");
        unlink $dest_path;
        return 0;
    }

    return 1;
}

sub _CurlGet {
    my ( $url, $user, $pass ) = @_;

    my @cmd = (
        'curl', '-sf',
        '-u', "$user:$pass",
        '--max-time', '30',
        $url,
    );

    my ( $ok, $err, $full_buf ) = run( command => \@cmd, verbose => 0 );
    unless ($ok) {
        _Warn("Nexus API query failed: $err");
        return undef;
    }

    return join( '', @$full_buf );
}

sub _enc {
    my ($s) = @_;
    $s //= '';
    $s =~ s/([^A-Za-z0-9\-_.~])/sprintf( "%%%02X", ord($1) )/ge;
    return $s;
}

sub _Warn {
    my ($msg) = @_;
    print color('yellow') . "  [NEXUS] WARN: $msg\n" . color('reset');
}

sub NexusSummary {
    return unless $CFG{NEXUS_ENABLED};

    my @fetched   = sort grep { ( $NEXUS_BUILD_LOG{$_} // '' ) eq 'skip'     } keys %NEXUS_BUILD_LOG;
    my @provided  = sort grep { ( $NEXUS_BUILD_LOG{$_} // '' ) eq 'provided' } keys %NEXUS_BUILD_LOG;
    my @compiled  = sort grep { ( $NEXUS_BUILD_LOG{$_} // '' ) eq 'compiled' } keys %NEXUS_BUILD_LOG;
    my @fallback  = sort grep { ( $NEXUS_BUILD_LOG{$_} // '' ) eq 'fallback' } keys %NEXUS_BUILD_LOG;

    my $width = 89;
    print "\n";
    print "=" x $width . "\n";
    print color('blue') . " Nexus Integration Summary\n" . color('reset');
    print "=" x $width . "\n";

    _PrintSummaryLine( "Fetched from Nexus:",    scalar @fetched,   \@fetched  );
    _PrintSummaryLine( "Provided/skipped:",      scalar @provided,  \@provided );
    _PrintSummaryLine( "Compiled locally:",      scalar @compiled,  \@compiled );
    _PrintSummaryLine( "Nexus failed/fallback:", scalar @fallback,  \@fallback );

    if (@fallback) {
        print color('yellow')
            . "\n  WARNING: " . scalar(@fallback)
            . " repo(s) fell back to compile due to Nexus fetch failure:\n"
            . color('reset');
        _PrintWrapped( "  ", \@fallback );
        print color('yellow')
            . "  Check Nexus connectivity and nexus_artifacts entries.\n"
            . color('reset');
    }
    print "=" x $width . "\n";
}

sub _PrintSummaryLine {
    my ( $label, $count, $repos ) = @_;
    printf "  %-24s %d repo(s):\n", $label, $count;
    if (@$repos) {
        _PrintWrapped( "    ", $repos );
    } else {
        print "    none\n";
    }
}

sub _PrintWrapped {
    my ( $indent, $repos ) = @_;
    my $max_width = 89;
    my $line      = $indent;

    for my $i ( 0 .. $#$repos ) {
        my $item = $repos->[$i];
        $item .= "," if $i < $#$repos;

        if ( length($line) + length($item) + 1 > $max_width && $line ne $indent ) {
            print "$line\n";
            $line = $indent;
        }
        $line .= ( $line eq $indent ? "" : " " ) . $item;
    }
    print "$line\n" if $line ne $indent;
}

1;
