#!/bin/sh
#simple samba settings
#01micko 111122, 120215
#gpl3 

#check for 1 running instance
RUNNING=`ps |grep SMBGUI|grep -v grep`
[ "$RUNNING" != "" ] && exit 0

# sort out the message app
type gxmessage 2>&1 >/dev/null && MSGAPP=gxmessage border='-borderless' || MSGAPP=xmessage border=
export MSGAPP border
#just in case
chmod 755 /etc/init.d/rc.samba

#is this config generated by this script?
head -n2 /etc/samba/smb.conf|grep -q rcrsn51
if [ $? -ne 0 ];then
	Xdialog --title "Samba Simple Setup"  --ok-label "Continue?" --cancel-label "Quit?" --yesno "It is recommended you \
quit this setup \n as you have a custom smb.conf.\
\nIf you continue a backup will be made of your config." 0 0
	[ $? -ne 0 ]&& exit
	cp -af /etc/samba/smb.conf /etc/samba/smb.conf.old
fi

##check for custom smb.conf hmmmm multiple shares would conflict with this... would be better to work with ANY samba config..ie use sed or take the wbar approach. Rejects if longer than 3 entries.
#CUSTOM=`grep '^\[' /etc/samba/smb.conf|wc -l`
#if [ "$CUSTOM" -gt "3" ];then
#	Xdialog --title "Simple Samba Management" --ok-label="Continue" --cancel-label="Quit" --yesno "You have a custom Samba #configuration. \nThis tool will overwrite your /etc/samba/smb.conf \nhowever a backup will be made automatically. \nIt is #recommended you quit and \nconfigure Samba manually" 0 0 0
#	[ $? -ne 0 ]&& exit
#	cp -af /etc/samba/smb.conf /etc/samba/smb.conf.old
#fi

#detect if samba is running
_status(){
	SAMBARUNNING=`pidof smbd|head -c1`
	if [ "$SAMBARUNNING" != "" ];then
		ln -sf /usr/share/pixmaps/samba/on.png /tmp/samba.png
	else
		ln -sf /usr/share/pixmaps/samba/off.png /tmp/samba.png
	fi
}

#switch samba daemon on/off
togglesamba(){
	SAMBARUNNING=`pidof smbd|head -c1`	
	if [ "$SAMBARUNNING" != "" ];then
		/etc/init.d/rc.samba stop
	else
		/etc/init.d/rc.samba start
	fi
	sleep 1
	_status
}

#generate smb.conf
swapvalues(){
	NETBIOSNAME="netbios name = $SERVERNAME"
	if [ "$SERVERNAME" = "" ];then
	#	SERVERNAME=""
		NETBIOSNAME=""
	fi

	echo "#this is a very simple smb.conf to get you started
#coutesy rcrsn51 and gcmartin
[global]
	workgroup = $WGROUP
	$NETBIOSNAME
	server string = Puppy Samba Server
	security = user
	map to guest = Bad Password
	printing = cups
	printcap name = cups
	load printers = yes

[$SHARENAME]
	path = $MYPATH
	writable = yes
" > /tmp/smb.conf

[ $MYPATH2 ]&& echo "
[$SHARENAME2]
	path = $MYPATH2
	writable = yes
" >> /tmp/smb.conf

[ $MYPATH3 ]&& echo "
[$SHARENAME3]
	path = $MYPATH3
	writable = yes
" >> /tmp/smb.conf

echo "
[printers]
	comment = All Printers
	path = /var/spool/samba
	browseable = no
	guest ok = yes
	writable = no
	printable = yes
" >> /tmp/smb.conf
#	[ "`grep BLANK /tmp/smb.conf`" != "" ]&& sed -i 's%BLANK%%' /tmp/smb.conf

}

#config test
testconfig(){
	testparm -s /tmp/smb.conf >/tmp/testparm.log 2>&1

	[ $? -ne 0 ]&& "$MSGAPP" -center -bg "#e77" -timeout 5 "ERROR: your smb.conf is not correct, try again" && return

	echo ""  >> /tmp/testparm.log
	SVPATH=`grep "path" /tmp/smb.conf|awk '{print $3}'|head -n1`
	[ ! $SVPATH ] && echo "ERROR: SHARED PATH IS MISSING" >> /tmp/testparm.log || echo "Ok" >> /tmp/testparm.log
	WORKGROUPSET=`grep "workgroup" /tmp/smb.conf|awk '{print $3}'`
	[ ! $WORKGROUPSET ] && echo "ERROR: WORKGROUP IS MISSING" >> /tmp/testparm.log || echo "Ok" >> /tmp/testparm.log
	"$MSGAPP" -file /tmp/testparm.log
}

#apply new settings if passes similar test to above... gui may have been altered after test to fresh config created anyway.
_apply(){
	[ ! $MYPATH ] && "$MSGAPP" -center -bg "#e77" -timeout 5 $border -buttons "" "ERROR: Aborting, you must enter a share path" && return
	[ ! $WGROUP ] && "$MSGAPP" -center -bg "#e77" -timeout 5 $border -buttons "" "ERROR: Aborting, you must enter a workgroup" && return
	
	testparm -s /tmp/smb.conf >/tmp/testparm.log 2>&1
	[ $? -ne 0 ]&& "$MSGAPP" -center -bg "#e77" -timeout 20  "ERROR: Aborting, Something went wrong with the Samba configuration.
	 Check the log at /tmp/testparm.log. 
	 Please try again or consult the documentation in /usr/share/help
	 Your SAMBA config has NOT been changed" && return

	cp -af /tmp/smb.conf /etc/samba/ #instate new smb.conf IF passes test
	/etc/init.d/rc.samba restart &
	"$MSGAPP" -center -bg "#4c4" -timeout 6 $border -buttons ""  "Samba is  starting/restarting. 
	You can check the log at /tmp/testparm.log"
	 
}

export -f swapvalues
export -f testconfig
export -f _status
export -f togglesamba
export -f _apply

#just in case..I suspect not needed as would write a fresh one...should clean up at the end really
[ -f /tmp/smb.conf ] &&  rm -f /tmp/smb.conf

#initialise status button
_status

#extract parameters or use fallbacks
MYPATH=`grep -iE 'path' /etc/samba/smb.conf|grep -v 'var'|grep -v 'tmp'|awk 'NR==1{print $3}'`
[ ! $MYPATH ]&& MYPATH=/root

SHARENAME=`grep -iE '^\[' /etc/samba/smb.conf|grep -v 'global'|grep -v 'printers'|sed -e 's%\[%%' -e 's%\]%%'| awk 'NR==1'`
[ ! $SHARENAME ]&& SHARENAME="puppyshare"

MYPATH2=`grep -iE 'path' /etc/samba/smb.conf|grep -v 'var'|grep -v 'tmp'|awk 'NR==2{print $3}'`
SHARENAME2=`grep -iE '^\[' /etc/samba/smb.conf|grep -v 'global'|grep -v 'printers'|sed -e 's%\[%%' -e 's%\]%%'| awk 'NR==2'`
[ $MYPATH2 ]&& PATH2="<default>$MYPATH2</default>" && SHARE2="<default>$SHARENAME2</default>"

MYPATH3=`grep -iE 'path' /etc/samba/smb.conf|grep -v 'var'|grep -v 'tmp'|awk 'NR==3{print $3}'`
SHARENAME3=`grep -iE '^\[' /etc/samba/smb.conf|grep -v 'global'|grep -v 'printers'|sed -e 's%\[%%' -e 's%\]%%' | awk 'NR==3'`
[ $MYPATH3 ]&& PATH3="<default>$MYPATH3</default>" && SHARE3="<default>$SHARENAME3</default>"

CURSERVER=`grep "netbios" /etc/samba/smb.conf|awk '{print $4}'`
[ ! $CURSERVER ] && CURSERVER="$(hostname)"

WGROUP=`grep "workgroup" /etc/samba/smb.conf|awk '{print $3}'`


#GUI
export SMBGUI="<window title=\"Samba Simple Management\" icon-name=\"gtk-network\" resizable=\"false\">
 <vbox>
  <hbox homogeneous=\"true\">
   <text use-markup=\"true\"><label>\"<b>You can personalise some Samba settings here</b>\"</label></text>
  </hbox> 
  <hbox homogeneous=\"true\">
   <text use-markup=\"true\"><label>\"The default <b>user</b> is: <b>root</b>\"</label></text>
  </hbox> 
  <hbox homogeneous=\"true\">
   <text use-markup=\"true\"><label>\"The default <b>password</b> is: <b>woofwoof</b>\"</label></text>
  </hbox> 
  <hbox homogeneous=\"true\">
   <text use-markup=\"true\"><label>\"You can change this and add users later\"</label></text>
  </hbox>
  <hseparator></hseparator>
  
  <hbox>
   <pixmap>
    <height>40</height>
    <input file>/usr/share/pixmaps/samba/samba.png</input>
   </pixmap>
   <text><label>Switch Samba Daemon on or off.</label></text>
   <button tooltip-text=\"hitting this button when Green will turn off Samba, when Red will turn off Samba\">
     <variable>ARTWORK</variable>
	 <input file>/tmp/samba.png</input>
	 <action>togglesamba</action>
     <action type=\"refresh\">ARTWORK</action>
    </button>
  </hbox>
  <hseparator></hseparator>
  
  <hbox homogeneous=\"true\">
   <text use-markup=\"true\"><label>\"You can change the default server <b>netbios</b> name if you wish.\"</label></text> 
  </hbox> 
  <hbox homogeneous=\"true\">
   <text use-markup=\"true\"><label>\"The default is <b>$(hostname)</b>\"</label></text>
   <entry tooltip-text=\"If $(hostname) is in this entry or it is left blank then your netbios name will be $(hostname) which is your computer's hostname. You can change it to anything you like as long as there are no spaces and chars are alpha/numeric. Dots, dashes and underscores are allowed\">
    <default>$CURSERVER</default>
    <variable>SERVERNAME</variable>
   </entry>
   </hbox>
  <hseparator></hseparator>
  
  <hbox homogeneous=\"true\">
   <text use-markup=\"true\"><label>\"The current Sharename is <b>$SHARENAME</b> and the default share path is <b>/root</b>, change either or both if you wish. You can have up to three shares.\"</label></text>
  </hbox>
  
  <hbox>
   <entry tooltip-text=\"$SHARENAME is the default mount point of your server. You can change it to anything you like as long as there are no spaces and chars are alpha/numeric. Dots, dashes and underscores are allowed\">
    <variable>SHARENAME</variable>
    <default>$SHARENAME</default>
   </entry>
   <entry fs-action=\"folder\">
    <variable>MYPATH</variable>
    <default>$MYPATH</default>
   </entry>
   <button tooltip-text=\"Browse for suitable share path\">
	<input file stock=\"gtk-open\"></input>
	<action>fileselect:MYPATH</action>
   </button>
  </hbox>
  
    <hbox>
   <entry tooltip-text=\"Add a second share here\">
    <variable>SHARENAME2</variable>
	$SHARE2
   </entry>
   <entry fs-action=\"folder\">
    <variable>MYPATH2</variable>
   $PATH2
   </entry>
   <button tooltip-text=\"Browse for suitable share path\">
	<input file stock=\"gtk-open\"></input>
	<action>fileselect:MYPATH2</action>
   </button>
  </hbox>
  
     <hbox>
   <entry tooltip-text=\"Add a third share here\">
    <variable>SHARENAME3</variable>
    $SHARE3
   </entry>
   <entry fs-action=\"folder\">
    <variable>MYPATH3</variable>
  $PATH3
   </entry>
   <button tooltip-text=\"Browse for suitable share path\">
	<input file stock=\"gtk-open\"></input>
	<action>fileselect:MYPATH3</action>
   </button>
  </hbox>
  
  <hseparator></hseparator>
  
  <hbox>
   <text use-markup=\"true\"><label>\"Change the default <b>workgroup</b> name\"</label></text> 
   <entry tooltip-text=\"If you have Microsoft Windows machines on your network you should set the Workgroup to the same name as the Windows Workgroup\">
    <default>$WGROUP</default>
    <variable>WGROUP</variable>
    </entry>
  </hbox>
  <hseparator></hseparator>

  <hbox homogeneous=\"true\">
   <button image-position=\"1\" use-stock=\"true\" label=\"gtk-apply\" tooltip-text=\"Perform a sanity check before applying your settings and restarting Samba.\">
   <action>swapvalues</action>
    <action>_apply</action>
    <action>_status</action>
    <action type=\"refresh\">ARTWORK</action>
   </button>
   <button tooltip-text=\"Click to check your new settings without applying.\">
    <label>Test</label>
	<input file stock=\"gtk-index\"></input>
    <action>swapvalues</action>
	<action>testconfig</action>
   </button>
   <button image-position=\"1\" use-stock=\"true\" label=\"gtk-quit\" tooltip-text= \"Exit leaving your current settings and status alone\">
    <action>exit:quit</action>
   </button>
  </hbox>
 </vbox>
</window>"

gtkdialog4 -c --program=SMBGUI
