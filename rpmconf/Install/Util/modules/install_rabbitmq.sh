#!/bin/bash
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016 , 2021 Synacor, Inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software Foundation,
# version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.
# ***** END LICENSE BLOCK *****
#

PLATFORM=`bin/get_plat_tag.sh`

install_on_ubuntu()
{
	install_op=$(apt-get install zimbra-rabbitmq-server -y)
	if [ $? -eq 0 ]; then
	   echo "RabbitMQ Server installation complete."
	else
	   echo "RabbitMQ Server installation failed. ${install_op}"
	fi
}

install_on_rhel()
{
	install_op=$(yum install zimbra-rabbitmq-server -y)
	if [ $? -eq 0 ]; then
	   echo "RabbitMQ Server installation complete."
	else
	   echo "RabbitMQ Server installation failed. ${install_op}"
	fi
}

install_rmq()
{
	echo $PLATFORM | egrep -q "UBUNTU|DEBIAN"
	if [ $? = 0 ]; then
		install_on_ubuntu
	else
		install_on_rhel
	fi
}
