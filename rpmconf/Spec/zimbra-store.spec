#
# spec file for zimbra.rpm
#
Summary: Zimbra Mail
Name: zimbra-store
Version: @@VERSION@@
Release: @@RELEASE@@
License: ZPL and other
Group: Applications/Messaging
URL: http://www.zimbra.com
Vendor: Zimbra, Inc.
Packager: Zimbra, Inc.
BuildRoot: /opt/zimbra
AutoReqProv: no
requires: zimbra-core, zimbra-store-components, zimbra-jetty-distribution >= 9.4.46.v20220331-2.@@PKG_OS_TAG@@@@MORE_DEPENDS@@

%description
Best email money can buy

%define __spec_install_pre /bin/true

%if 0%{?rhel} == 9
%define __brp_ldconfig RPM_BUILD_ROOT="" /usr/lib/rpm/redhat/brp-ldconfig
%define __brp_mangle_shebangs RPM_BUILD_ROOT="" /usr/lib/rpm/redhat/brp-mangle-shebangs
%endif

%prep

%build

%install

%pre

%post

%preun

%postun

%files
