#
# spec file for liquid.rpm
#
Summary: Liquid QA Tests
Name: liquid-qatest
Version: @@VERSION@@
Release: @@RELEASE@@
Copyright: Copyright 2004 Liquid Systems
Group: Applications/Messaging
URL: http://www.liquid.com
Vendor: Liquid Systems, Inc.
Packager: Liquid Systems, Inc.
BuildRoot: /opt/liquid
AutoReqProv: no
requires: liquid-core

%description
Best email money can buy

%prep

%build

%install

%pre

%post
chown -R liquid:liquid /opt/liquid/qa
chmod a+x /opt/liquid/qa/scripts/*

%preun

%files
