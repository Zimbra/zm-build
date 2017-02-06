#
# spec file for zimbra.rpm
#
Summary: Zimbra Spell
Name: zimbra-spell
Version: @@VERSION@@
Release: @@RELEASE@@
License: Various
Group: Applications/Messaging
URL: http://www.zimbra.com
Vendor: Zimbra, Inc.
Packager: Zimbra, Inc.
BuildRoot: /opt/zimbra
AutoReqProv: no
requires: zimbra-core, zimbra-spell-components

%description
Best email money can buy

%define __spec_install_pre /bin/true

%prep

%build

%install

%pre

%post

%preun

%postun

%files
