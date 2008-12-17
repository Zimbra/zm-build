#
# spec file for zimbra.rpm
#
Summary: Zimbra Customer Care
Name: zimbra-customercare
Version: @@VERSION@@
Release: @@RELEASE@@
Copyright: Various
Group: Applications/Messaging
URL: http://www.zimbra.com
Vendor: Zimbra, Inc.
Packager: Zimbra, Inc.
BuildRoot: /opt/zimbra
AutoReqProv: no
requires: zimbra-core
requires: zimbra-store

%description
Best email money can buy

%define __spec_install_post /usr/lib/rpm/brp-compress /usr/lib/rpm/brp-strip-comment-note %{nil}

%prep

%build

%install

%pre

%post

%preun

%postun

%files
