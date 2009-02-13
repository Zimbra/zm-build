#!/bin/sh

usage() {
   echo "usage: $0 [destdir] [pkgdir] [pkgname] [version]"
   exit 1
}

LOCAL=0
LABEL=conary.rpath.com@rpl:devel

if [ "$1" = "--local" ]; then
    LOCAL=1
    shift
elif [ "$1" = "--label" ]; then
    LABEL=$2
    shift; shift;
fi

if [ $# -ne 4 ]; then
    usage
fi

if [ $LOCAL -eq 0 ]; then
    # if we are to be building in the repository, make sure that we
    # have the needed configuration
    for x in contact name; do
        if ! conary config | grep $x > /dev/null 2>&1; then
            echo "conary configuration is missing the $x setting"
            exit 1
        fi
    done
    # pull out the server name from the label, make sure we have a user
    # line
    server=$(echo $LABEL | sed 's/@.*//g')
    if ! conary config | grep "user.*$server" > /dev/null 2>&1; then
        echo "conary configuration missing user line for server $server"
        exit 1
    fi
fi

DESTDIR=$1
SCRIPTDIR="$DESTDIR/../rpmconf/Spec/Scripts/RPL1"
PKGDIR=$2
PKGNAME=$3
VERSION=$4

WORK=$(mktemp -d /tmp/cvc-wrapper-XXXXXX)

# tar up the build dir
tar czf $WORK/$PKGNAME.tar.gz -C $DESTDIR .

# create a simple recipe to unpack the archive
cat > $WORK/$PKGNAME.recipe <<EOF
class ZimbraBuildRecipe(PackageRecipe):
    name = "$PKGNAME"
    version = "$VERSION"

    def setup(r):
        # extract the pre-built binary archive in /
        r.addArchive("%(name)s.tar.gz", dir="/")
        # avoid java deps for now
        r.Requires(exceptDeps=('.*', 'java:.*'))
        r.Provides('soname: /opt/zimbra/mysql/lib/libmysqlclient.so.15',
                   '.*/libmysqlclient.so.15')
        # FIXME: some perl bits use CPAN::Config, but nothing provides it
        r.Requires(exceptDeps=('.*', 'perl:.*CPAN::Config'))
        # turn of build requirement checks
        del r.EnforceSonameBuildRequirements
        del r.EnforcePerlBuildRequirements
        del r.DanglingSymlinks
        r.RemoveNonPackageFiles(exceptions='.*')
        r.InitialContents('/opt/zimbra/conf/localconfig.xml');
        # don't delete specific empty directories
        if r.name == 'zimbra-core':
          r.MakeDirs('/etc/conary/entitlements')
          r.Symlink ('/opt/zimbra/libexec/zmgenentitlement', '/etc/conary/entitlements/products.rpath.com')
          r.Symlink ('/opt/zimbra/libexec/zmgenentitlement', '/etc/conary/entitlements/conary.rpath.com')
          r.Symlink ('/opt/zimbra/libexec/zmgenentitlement', '/etc/conary/entitlements/zimbra.liquidsys.com')
        if r.name == 'zimbra-mta':
          r.ExcludeDirectories(exceptions='/opt/zimbra/postfix.*')
          r.ExcludeDirectories(exceptions='/opt/zimbra/clamav.*')
          r.ExcludeDirectories(exceptions='/opt/zimbra/amavis.*')
          r.ExcludeDirectories(exceptions='/opt/zimbra/dspam.*')
        if r.name == 'zimbra-store':
          r.MakeDirs('/opt/zimbra/apache-tomcat-5.5.15/work', mode=0755)
          r.MakeDirs('/opt/zimbra/apache-tomcat-5.5.15/work/Catalina', mode=0755)
          r.MakeDirs('/opt/zimbra/apache-tomcat-5.5.15/work/Catalina/localhost', mode=0755)
          r.Ownership('zimbra', 'zimbra' '/opt/zimbra/apache-tomcat-5.5.15/work/Catalina/localhost');
          r.ExcludeDirectories(exceptions='/opt/zimbra/apache-tomcat-5.5.15/?.*')
          r.ExcludeDirectories(exceptions='/opt/zimbra/wiki/?.*')
          r.Config('/opt/zimbra/apache-tomcat-5.5.15/webapps/zimbra/WEB-INF/web.xml')
          r.Config('/opt/zimbra/apache-tomcat-5.5.15/webapps/service/WEB-INF/web.xml')
          r.SetModes('/opt/zimbra/verity/FilterSDK/bin/kvoop', 0755)
        if r.name == 'zimbra-ldap':
          r.ExcludeDirectories(exceptions='/opt/zimbra/openldap.*')
        if r.name == 'zimbra-apache':
          r.ExcludeDirectories(exceptions='/opt/zimbra/httpd.*')
        # set up libraries to be included in /etc/ld.so.conf
        r.SharedLibrary(subtrees='/opt/zimbra/%(lib)s')
        # add PERL5LIB
        r.Environment('PERL5LIB', '/opt/zimbra/zimbramon/lib:/opt/zimbra/zimbramon/lib/i386-linux-thread-multi')
        # glob not supported until conary 1.0.15
        #r.SharedLibrary(subtrees='/opt/zimbra/cyrus-sasl.*/%(lib)s')
        r.SharedLibrary(subtrees='/opt/zimbra/cyrus-sasl-2.1.22.3z/%(lib)s')
        # add a runtime requirements on sudo
        for x in ('postfix', 'qshape', 'postconf', 'tomcat', 'ldap'):
            r.Requires('sudo:runtime', '/opt/zimbra/bin/' + x)
        r.Requires('openssl:runtime', '/opt/zimbra/bin/zmcreateca')
        r.Requires('vixie-cron:runtime', '/opt/zimbra/libexec/zmsetup.pl')
        r.Requires('openssh-client:runtime', '/opt/zimbra/libexec/zmrc')
        r.Requires('openssh-server:runtime', '/opt/zimbra/libexec/zmrc')
        # add requirements on zimbra-core (note that '' is for zimbra-store)
        for pkg in ('apache', 'mta', 'ldap', 'store', 'logger', 'snmp', 'proxy'):
            r.Requires('zimbra-core:runtime',
                       '/opt/zimbra/scripts/zimbra-%s.post' %pkg)
        # add requirement from zimbra-spell -> zimbra-apache
        r.Requires('zimbra-apache:runtime',
                   '/opt/zimbra/scripts/zimbra-spell.post')
        # add requirement from zimbra-mta -> zimbra-store
        r.Requires('zimbra-store:runtime',
                   '/opt/zimbra/scripts/zimbra-mta.post')
        # add requirement from zimbra->mta -> mailbase for /etc/aliases
        r.Requires('mailbase:runtime', '/opt/zimbra/postfix.*/sbin/postalias')
        # add an exclude for convertd libs
        r.Requires(exceptDeps=('.*', 'soname:.*libnotes.*'))
        # zmfixperms uses these user/groups when changing ownerships
        for user in ('zimbra', 'postfix', 'nobody'):
            r.UtilizeUser(user, '/opt/zimbra/libexec/zmfixperms')
            r.UtilizeGroup(user, '/opt/zimbra/libexec/zmfixperms')
        r.UtilizeGroup('postdrop', '/opt/zimbra/libexec/zmfixperms')
EOF

script=$SCRIPTDIR/$PKGNAME.post
if [ -f $script ]; then
    #cp $script $WORK
    sed -e "s/@@VERSION@@/${VERSION}/" -e "s/@@PKGNAME@@/${PKGNAME}/" $script > /tmp/$PKGNAME.post
    cp /tmp/$PKGNAME.post $WORK
    s=$(basename $script)
    cat >> $WORK/$PKGNAME-tagdescription <<EOF
file          %(taghandlerdir)s/%(name)s
description   %(name)s script proxy handler
datasource    args
implements    files update
EOF
    cat >> $WORK/$PKGNAME-taghandler <<EOF
#!/bin/bash
case \$2 in
    update)
        /opt/zimbra/scripts/$s 1
        ;;
esac
exit 0
EOF
    cat >> $WORK/$PKGNAME.recipe <<EOF
        r.addSource("$s", dest="/opt/zimbra/scripts/", mode=0755)
        r.TagSpec("$PKGNAME", "/opt/zimbra/scripts/$s")
        r.addSource("$PKGNAME-tagdescription",
                    dest='%(tagdescriptiondir)s/%(name)s', macros=True)
        r.addSource("$PKGNAME-taghandler",
                    dest='%(taghandlerdir)s/%(name)s', macros=True,
                    mode=0755)
EOF
fi
pushd $WORK
# if we're doing a local cook, just cook the recipe
if [ $LOCAL -eq 1 ]; then
    cvc cook $PKGNAME.recipe
else
    # otherwise, either check out the source component or create a new one
    if conary rq $PKGNAME:source=$LABEL > /dev/null 2>&1; then
        cvc co $PKGNAME=$LABEL
    else
        cvc newpkg $PKGNAME=$LABEL
    fi
    # move the files and add them to the source component
    mv -f $(find -maxdepth 1 -type f) $PKGNAME
    cd $PKGNAME
    # fix up any permissions from files copied from p4
    chmod u+w *
    # add any new files
    new=$((ls | grep -v CONARY; cat CONARY | tail +5 | awk '{print $2}') |
           sort | uniq -u)
    if [ -n "$new" ]; then
        cvc add $new --text
    fi
    cvc commit -m 'automated update from ZimbraBuild'
    cd -
    # build it
    cvc cook $PKGNAME=$LABEL
    # extract the changeset (for convenience)
    conary changeset $PKGNAME=$LABEL $PKGNAME-$VERSION.ccs
fi

cp $PKGNAME*ccs $PKGDIR
popd

rm -rf $WORK
