#!/bin/bash
cd "$(dirname "$0")"
if [ "$1" == '-r' ]; then
    echo "Reverting fix for bug 107925 and 108265"
    cp -f backup_files/ZmMailListController.js /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/controller/ZmMailListController.js
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/controller/ZmMailListController.js
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/controller/ZmMailListController.js

    cp -f backup_files/ZmMailMsgView.js /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/view/ZmMailMsgView.js
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/view/ZmMailMsgView.js
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/view/ZmMailMsgView.js

    cp -f backup_files/MailCore_all.js.zgz /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js.zgz
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js.zgz
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js.zgz

    cp -f backup_files/MailCore_all.js /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js

    cp -f backup_files/NewWindow_2_all.js.zgz /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js.zgz
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js.zgz
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js.zgz

    cp -f backup_files/NewWindow_2_all.js /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js

    cp -f backup_files/Tasks_all.js.zgz /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js.zgz
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js.zgz
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js.zgz

    cp -f backup_files/Tasks_all.js /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js

    perl jsVersionUpdate.pl

    echo "Reverted the patch. Please restart the mailbox. "
elif [ "$1" == '-h' ]; then
    echo "Usage: ./install_patch.sh [OPTION]"
    echo "./install_patch.sh install patch for bug 107925 and 108265 on 8.7.11 GA"
    echo "-r  revert the patch."
else
    echo "Backing up ...."
    mkdir backup_files 2>/dev/null
    cp -f /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/controller/ZmMailListController.js backup_files/
    cp -f /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/view/ZmMailMsgView.js backup_files/
    cp -f /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js.zgz backup_files/
    cp -f /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js backup_files/
    cp -f /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js.zgz backup_files/
    cp -f /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js backup_files/
    cp -f /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js.zgz backup_files/
    cp -f /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js backup_files/
    echo "Installing Fix for Bug 107925 and 108265"

    cp -f patched_files/ZmMailListController.js /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/controller/ZmMailListController.js
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/controller/ZmMailListController.js
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/controller/ZmMailListController.js

    cp -f patched_files/ZmMailMsgView.js /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/view/ZmMailMsgView.js
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/view/ZmMailMsgView.js
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/zimbraMail/mail/view/ZmMailMsgView.js

    cp -f patched_files/MailCore_all.js.zgz /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js.zgz
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js.zgz
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js.zgz

    cp -f patched_files/MailCore_all.js /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/MailCore_all.js

    cp -f patched_files/NewWindow_2_all.js.zgz /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js.zgz
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js.zgz
    chmod 664  /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js.zgz

    cp -f patched_files/NewWindow_2_all.js /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/NewWindow_2_all.js

    cp -f patched_files/Tasks_all.js.zgz /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js.zgz
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js.zgz
    chmod 664  /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js.zgz

    cp -f patched_files/Tasks_all.js /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js
    chown zimbra.zimbra /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js
    chmod 664 /opt/zimbra/jetty/webapps/zimbra/js/Tasks_all.js
 
    perl jsVersionUpdate.pl
    echo "Installation completed. Please restart the mailbox. "
fi
