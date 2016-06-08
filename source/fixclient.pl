# **************************************************************************
# Name		fixclient
#
# Function		Remove and reinstall SMS client and backup flag files 
#
# Paramenters		<systemlist>
#
# Requirements	perl installed
#  				clientdeploy_i386.exe extracted to <dir where script is>\clientdeploy
#				Perl Modules:  
#				   Win32/AdminMisc -- From ppm run "perl ppm.pl install http://www.roth.net/perl/packages/win32-adminmisc.ppd"
#				   Win32/FileOp 
#				   Net/Ping -- from ppm run "install Net-Ping-External"
#  	 	               More modules may be needed
# Return code		N/A
#
#
# By	 Lance Rissman lrissman@celestica.com
#
# Change History
# 		 	03/20/2003 - Lance Rissman - Inital Creation 
# 		 	03/27/2003 - Lance Rissman - Added check for flag file before copy
# 		 	05/22/2003 - Lance Rissman - Added switch to install OR fix
# 		 	08/21/2003 - Lance Rissman - Added ability to remove only
# 		 	09/26/2003 - Lance Rissman - Fixed Flag Backup 
#			02/10/2004 - Lance Rissman - Implemented Arguemnt Parsing and psexec
#			02/11/2004 - Lance Rissman - Fixed idiot checking.  Added password question
#			02/12/2004 - Lance Rissman - Fixed uninstall without server trying to ping
#			03/21/2004 - Lance Rissman - Added backup/restore of the id/noid mifs directories
#			08/04/2004 - Lance Rissman - Added code to determine windows version and note unsupported versions
#			08/05/2004 - Lance Rissman - Added code to detect client type and remote approperiate client
#					   	 	   		   - Updated CAP detection code
# **************************************************************************
# strict;Win32::FileOP;Win32::PingICMP;Getopt::Long
use strict;
use Win32::FileOp;
#use Win32::AdminMisc;
use Win32::PingICMP;
use Getopt::Long;
use Term::ReadKey;
use Win32::Registry;


# Variable Initilization
my $scriptver = "2.2.2";
my $systemlist;
my $CAPserver;
my $sitecode;
my $method;
my $error;
my @systems;
my $count;
#my $totaldisk;
#my $freedisk;
my $pingtest;
my $versiontest;
my $result;
my $netbiostest;
my $cliuser;
my $clipass;
my $srvuser;
my $srvpass;
my $manualinstall;
my $char;
my $SysVer;
my $clienttype;

######################
### Display Header ###
######################

print "###############################################\n";
print "#         Systems Management Server           #\n";
print "#      Client Install/Uninstall Script        #\n";
print "#             Version: $scriptver                  #\n";
print "# By: Lance Rissman   lrissman\@celestica.com  #\n";  	
print "###############################################\n";
print "\n\n";

################################
### Get Command line options ###
################################

GetOptions ("f=s" => \$systemlist,
			"s=s" => \$CAPserver,	
			"c=s" => \$sitecode,
			"m=s" => \$method,
			"p" => \$pingtest,
			"n" => \$netbiostest,
			"v" => \$versiontest,			
			"manualinstall" => \$manualinstall,
			"clientuser=s" => \$cliuser,
			"clientpass=s" => \$clipass,
			"serveruser=s" => \$srvuser,
			"serverpass=s" => \$srvpass);

################################
### Check for required files ###
################################
if (! -e "hammer.exe") {
	$error = 1;
	print "Error:  hammer.exe is not found!\n";
}

if (! -e "psexec.exe") {
	$error = 1;
	print "Error:  psexec.exe is not found!\n";
}

if (! -e "rkill.exe") {
	$error = 1;
	print "Error:  rkill.exe is not found!\n";
}

if (! -e "rkillsrv.exe") {
	$error = 1;
	print "Error:  rkillsrv.exe is not found!\n";
}

if (! -e "sc.exe") {
	$error = 1;
	print "Error:  sc.exe is not found!\n";
}

if (! -e "smsman.exe") {
	$error = 1;
	print "Error:  smsman.exe is not found!\n";
}

if (! -e "ccmclean.exe") {
	$error = 1;
	print "Error:  ccmclean.exe is not found!\n";
}
if ($error eq 1) { exit; }

 
##################################
### Clean Command line options ###
##################################
if ($systemlist) { $systemlist = lc("$systemlist") }
if ($CAPserver) { $CAPserver = lc("$CAPserver") }
if ($sitecode) { $sitecode = lc("$sitecode") }
if ($method) { $method = lc("$method") }
if ($pingtest) { $pingtest = lc("$pingtest") }
if ($netbiostest) { $netbiostest = lc("$netbiostest") }
if ($cliuser) { $cliuser = lc("$cliuser") }
if ($srvuser) { $srvuser = lc("$srvuser") }

			
# DEBUG CODE  Uncomment if you want to see variables
#	print "File: $systemlist\n";
#	print "CAP Server: $CAPserver\n";
#	print "SiteCode: $sitecode\n";
#	print "Method: $method\n";
#	if (! $pingtest) { print "Ping test Enabled\n"}elsif ($pingtest) { print "Ping test Disabled\n"}
#	if (! $netbiostest) { print "NetBIOS test Enabled\n"}elsif ($netbiostest) { print "NetBIOS test Disabled\n"}
#	if (! $versiontest) { print "Vesion test Enabled\n"}elsif ($versiontest) { print "Version test Disabled\n"}	
#	if ($manualinstall) { print "Manual Install Enabled\n"}elsif (! $manualinstall) { print "Server install Enabled\n"}
#	print "\n";
# End Debug Code
	
#############################################
### Check Command line options for sanity ###
#############################################
$error = 0;

if ($method eq "fix") {
	# Check for the existance of required options
	if (! $systemlist) {
		$error = 1;
		print "Error:  System list not specified \n";
	}
	if (! $manualinstall) {
		if (! $CAPserver) {
			$error = 1;
			print "Error:  Site server not specified \n";
		}
		if (! $sitecode) {
			$error = 1;
			print "Error:  Site Code not specified \n";
		}
	}
}elsif ($method eq "uninstall"){
	# Check for the existance of required options
	if (! $systemlist) {
		$error = 1;
		print "Error:  System list not specified \n";
	}
}elsif ($method eq "install"){
	# Check for the existance of required options
	if (! $systemlist) {
		$error = 1;
		print "Error:  System list not specified \n";
	}
	if (! $manualinstall) {
		if (! $CAPserver) {
			$error = 1;
			print "Error:  Site server not specified \n";
		}
		if (! $sitecode) {
			$error = 1;
			print "Error:  Site Code not specified \n";
		}
	}
}else {
	$error = 1;
	print "Error: Option not specified or unknown\n";
} 
if ($manualinstall) {
	if (! $cliuser) {
		$error = 1;
		print "Error: You must specify a admin user to perform a manual install\n";
	}
}

if ($cliuser) {
	if (! $clipass) {
		# Get password
		print ("User: $cliuser\nPassword: ");
		ReadMode('noecho');
		
		$clipass = ReadLine(0);
	}
} 

if ($error eq 1){
	print "\n\n";
	print "Press any key to continue\n\n";
	$|=1;
	binmode STDIN;
	ReadMode ('cbreak');
	while (not defined (my $ch = ReadKey())) {
	}
	ReadMode ('restore');
	$|=0;
	print "This script contains many functions.  Each of the switches required\n";
	print "are different depending upon the option chosen.\n";
	print "\n";
	print "OPTIONS\n";
	print "=======\n";
	print "You may choose an option by specifying -m <option>\n";
	print "Available choices for <option> are:\n";
	print "\n";
	print "INSTALL   -- This allows you to install the SMS client on a system\n";
	print " - Available options are:  -f <systemlist>\n";
	print " 						  -s <CAP server name>\n";
	print " 						  -c <SMS Site Code>\n";
	print " 						  -p\n";
	print " 						  -n\n";	  
 	print " 						  --manualinstall\n";
	print " 						  --clientuser\n";
	print " 						  --clientpass\n";
	print "\n";
	print "UNINSTALL -- This allows you to uninstall the SMS client on a system\n";
	print " - Available options are:  -f <systemlist>\n";
	print " 						  -p\n";
	print " 						  -n	\n";  
	print " 						  --clientuser\n";
	print " 						  --clientpass\n";
	print "\n";
	print "FIX -- This runs an UNINSTALL and an INSTALL\n";
	print "\n";
	print "SWITCHES\n";
	print "========\n";
	print " -f <systemlist>\n";
	print "    systemlist is a text file of sytems with 1 system name per line\n";
	print "\n";
	print " -s <CAP Server name>\n";
	print "    CAP Server name is the name of a Client Access Point in your site\n";
	print "\n";	
	print " -c <SiteCode>\n";
	print "    Site Code is the site code of your site\n";
	print "\n";
	print " -p\n";
	print "    This option will disable the ping tests\n";	
	print "\n";
	print " -n\n";
	print "    This option will disable NetBIOS tests\n";
	print "\n";
	print " -v\n";
	print "    This option will disable Version tests\n";
	print "\n";
	print " --clientuser username\n";
	print "    This option will specify a user for client connections\n";	
	print "\n";
	print " --clientpass password\n";
	print "    This option will specify a password for client connections\n";
	print "    Note: If --clientuser is specified and --clientpass is not, \n";
	print "          specified, the script will ask for the password\n";
	print "\n";
	print " --manualinstall\n";
	print "   If this option is not specified, the script will instruct the SMS\n";
	print "   site server to install the SMS Client on the system specified.\n";
	print "   If this option is specified, the script will run smsman.exe on\n";
	print "   the client to install the client.  Note: --clientuser is required\n";
	print "   if this option is used\n";
	print "\n";
	exit;
}

# Check to see if systemlist exists
if (! -e "$systemlist") {
	print "Error: Systemlist \($systemlist\) does not exist";
}
if ($CAPserver) {
	# Check to see if Site Server is pingable
	$result = SUBpingtest ("$CAPserver");
	if ($result eq 1) { 
		print "Error: CAP Server is not pingable\n";
		exit;
	}

	# Check to see if sitecode is correct directory exists
	$result = SUBnetbiostest("//$CAPserver/CAP_$sitecode");
	if ($result eq 1) {
		print "Error: SiteCode is not correct or SMS Share \(\\\\$CAPserver\\CAP_$sitecode\) is not accessable";
		exit;
	}

	# Check to see if ccr.box inbox exists
	$result = SUBnetbiostest("//$CAPserver/CAP_$sitecode/ccr.box");
	if ($result eq 1) {
		print "Error: SMS inbox \(\\\\$CAPserver\\SMS_$sitecode\\inboxes\\ccr.box\) is not accessable or does not exist";
		exit;
	}
}

#################################
### Configuration File Parser ###
#################################
open (INPUT, "< $systemlist") 
	 or die "Couldn't open $systemlist";

	 
	 
# Get list of servers into @servers
print "Parsing $systemlist\n";
while (<INPUT>) {
	  # Comment,whitespace, and null Checker
	  if ((substr($_, 0, 1) eq "#") or (substr($_, 0, 1) eq " " ) or ($_ eq chr(10)) ) { 
		 next;
      }
	  chomp ($_);
	  @systems[$count]=$_;	  
	  $count++;
}
close (INPUT);
#### END Configuration File Parser ###


# Process each server (create directories and dump logs)
if ( -e "result.log") { system ("del result.log") }

foreach (@systems) {
	open (ERRORFILE, ">> result.log");
	
	print (ERRORFILE "$_;");
	print ("$_ -> ");
	$error = 0;

	##### CHECKS to see if system is workable
	# Check if IP is up
#	print ("test -> $_\n");
	$result = SUBpingtest($_); 
	if ($result eq 1) {
	   print (ERRORFILE "Not Pingable;\n");
	   print ("Not Pingable\n");	   
	   $error = 1;
	}else{ 
	   # check if Netbios is up
	   if ($cliuser) {
	   		system ("net use \\\\$_\\ipc\$ /user\:$cliuser $clipass");
	   }
	   $result = SUBnetbiostest("//$_/admin\$/explorer.exe"); 
	   if ($result eq 1) {
   		   print (ERRORFILE "Files Inaccessable;\n");
		   print ("Cannot access files on system\n");
		   $error = 1;
	   }else{
	   	  #Check to see if it is a supported version of windows			
	      $result = SUBWindowsVersion ($_);
		  if ($result eq 1) {
		    print (ERRORFILE "Unsupported Version;$SysVer;\n");
			print ("UnSupported Version -> $SysVer\n");
			$error = 1;
		  }else{
	   	  		#Check to see if client is Installed/Client type			
	      		$result = SUBClientCheck ($_);
				if ($result eq 0) { 
				   $clienttype = "none";
				}elsif ($result eq 1) { 
				   $clienttype = "legacy";
				}elsif ($result eq 2) { 
				   $clienttype = "advanced";
				}
				print (ERRORFILE "$clienttype;");
		   }
		}
		#else{
			 # Check for free disk space
#		   ($totaldisk, $freedisk) = Win32::AdminMisc::GetDriveSpace ("\\\\$_\\c\$\\");
#		   if  ($freedisk <  10485760) {
#		   	   warn "$_ -> Not enough free disk space\n";
#		   	   print (ERRORFILE "$_;Less then 10 Meg Free\n");
#		   	   $error = 1;
#	       }
#	   }
	}
	###### If no errors.. Reinstall Client
	if ($error eq 0) {
	   if ($method eq "fix"){
	        removeclient();
			installclient();
	   }
	   if ($method eq "install"){
	   	    installclient();
	   }
	   if ($method eq "uninstall"){
	        removeclient();
	   }
	   print (ERRORFILE "Success\n");
	   print ("Success\n");
	}

if ($cliuser) {
	system ("net use \\\\$_\\ipc\$ /user\:$cliuser $clipass");
}


close (ERRORFILE);   
}	  



########################
### Test Subroutines ###
########################
sub SUBWindowsVersion ($SUBsystemname) {
	my $SUBsystemname = shift;
	my $SUBerror = 0;
	my $Caption;
	my $CSDVersion;
	my $CurrentBuildNumber;
	my $CurrentVersion;
	my $ProductName;
	my $IEVersion;
	my $Root;
	my $Key;
	my $Type;
	my $Supported = 0;
	
	if (! $versiontest) {
		#Connect to system
		if ($HKEY_LOCAL_MACHINE->Connect ($_, $Root) )
		{
		   if ($Root->Open("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", $Key) )
		   {
   		   	  $Key->QueryValueEx ("CSDVersion", $Type, $CSDVersion);
	       	  $Key->QueryValueEx ("CurrentBuildNumber", $Type, $CurrentBuildNumber);
		   	  $Key->QueryValueEx ("CurrentVersion", $Type, $CurrentVersion);
		   	  $Key->QueryValueEx ("ProductName", $Type, $ProductName);
		   	  $Key->Close;	   	
		   }
		   if ($Root->Open("SOFTWARE\\Microsoft\\Internet Explorer\\Version Vector", $Key) )
		   {
		   	  $Key->QueryValueEx ("IE", $Type, $IEVersion);
		   	  $Key->Close;
		   }
   		   $Root->Close();
		   $SysVer = "$ProductName;$CurrentVersion;$CSDVersion;$IEVersion";
		   if ($CurrentVersion eq "4.0") {
	       	  if ($CSDVersion eq "Service Pack 6") {}
	       	  else{$Supported = 1}
	   	   }
		   if ($IEVersion < 5.0) { $Supported = 1}
		}
		#	print " Supported = $Supported ";
	}
	return $Supported;
}


sub SUBpingtest ($SUBsystemname) {
	my $SUBsystemname = shift;
	my $SUBerror = 0;
#	print "\n Starting ping test on $SUBsystemname\n";
	if (! $pingtest) {
		my $p = Win32::PingICMP->new();

		if (! $p->ping($SUBsystemname)) {
			$SUBerror = 1;
		}
	}
#	print "\n Ending ping test return is $SUBerror \n";
	return $SUBerror;
}



sub SUBnetbiostest ($SUBpath) {
	my $SUBpath = shift;
	my $SUBerror = 0;
#	print "\n starting netbios test on $SUBpath\m";
	if (! $netbiostest) {
	   if (! -e "$SUBpath") {
	   		$error = 1;
	   }
	}
#	print "\n ending netbios test with $error";
	return $error;
}


##########################
### Client Subroutines ###
##########################


sub removeclient {
	#	print "$_ -> Files Accessable\n";
	###  Forcefully Remove Client
	if ( $clienttype eq "none" ) { 
	   print " No Client Detected, attempting removal of both - ";
	   SUBRemoveLegacyClient($_);
	   SUBRemoveAdvancedClient($_);
	}elsif ( $clienttype eq "legacy" ) { 
	   print " Removing Legacy Client - ";
	   SUBRemoveLegacyClient($_);
	}elsif ( $clienttype eq "advanced" ) {
	   print " Removing Advanced Client - ";
	   SUBRemoveAdvancedClient($_);
	}
}

sub installclient {
	if (! $manualinstall) {
#		print "not manual\n";
		#request install of the client
		#create ccr record
		if (-e "$_.ccr") {	 
		 	system ("del $_.ccr");
		}
	    open (CCR, ">$_.ccr");
		print (CCR "[NT Client Configuration Request]\n");
		print (CCR "\n");
		print (CCR "Machine Name = $_\n");
	 	print (CCR "\n");
	 	print (CCR "\n");
		print (CCR "Forced CCR = TRUE\n" );
	 	print (CCR "\n");
	 	print (CCR "\n");
		print (CCR "[IP Address ]\n" );
		print (CCR "\n");		 
		print (CCR "[Resource Names ]\n" );
		print (CCR "\n");
		print (CCR "[Request Processing]\n" );
		print (CCR "\n");
		print (CCR "[IDENT]\n" );
		print (CCR "TYPE=Client Config Request File\n" );
		close (CCR);
#		print ("\\\\$CAPserver\\SMS_$sitecode\\inboxes\\ccr.box\n");
		Move ("$_.ccr" => "\\\\$CAPserver\\CAP_$sitecode\\ccr.box");
	} else {
#		print "manual \n"; 
		if (! $cliuser) {
			system ("psexec \\\\$_ -c SMSMAN.exe /Q /M \\\\$CAPserver\\cap_$sitecode");
		}elsif ($cliuser) {
			system ("psexec \\\\$_ -u $cliuser -p $clipass -c SMSMAN.exe /Q /M \\\\$CAPserver\\cap_$sitecode");
		}
	}
}		 

sub SUBClientCheck ($SUBSystemName) {
	my $SUBSystemName = shift;
	my $SUBError = 0;
	#$SUBError 0 = no client detected
	#$SUBError 1 = legacy client detected
	#$SUBError 2 = advanced client detected
	if ( -e  "\\\\$SUBSystemName\\admin\$\\ms\\sms\\CORE\\BIN\\CliCore.exe") {
	   $SUBError = 1;
	}elsif ( -e  "\\\\$SUBSystemName\\admin\$\\system32\\CCM\\CcmExec.exe") {
	   $SUBError = 2;
	}else{
	   $SUBError = 0;
	}
	return $SUBError;
}

sub SUBRemoveAdvancedClient ($SUBSystemName) {
	my $SUBSystemName = shift;
	my $SUBError = 0;
	if (! $cliuser) {
		system ("psexec \\\\$SUBSystemName -c ccmclean.exe /client /keephistory /q /retry:5,10");
	}elsif ($cliuser) {
		system ("psexec \\\\$SUBSystemName -u $cliuser -p $clipass -c ccmclean.exe /client /keephistory /q /retry:5,10");
	}

}

sub SUBRemoveLegacyClient ($SUBSystemName) {
	my $SUBSystemName = shift;
	my $SUBerror = 0;
	# backup flags (If they Exist)
	if ( -e  "\\\\$_\\admin\$\\ms\\sms\\clicomp\\apa\\Data\\Complete") {
	   print "Backing up flags for $_\n";
	   mkdir "//$_/admin\$/flagbackup";
	   Copy ("\\\\$_\\admin\$\\ms\\sms\\clicomp\\apa\\Data\\Complete\\*.*" => "\\\\$_\\admin\$\\flagbackup");
	   mkdir "//$_/admin\$/idmifsbackup";
	   mkdir "//$_/admin\$/noidmifsbackup";
	   Copy ("\\\\$_\\admin\$\\ms\\sms\\idmifs\\*.*" => "\\\\$_\\admin\$\\idmifs");
	   Copy ("\\\\$_\\admin\$\\ms\\sms\\noidmifs\\*.*" => "\\\\$_\\admin\$\\noidmifs");

   	}
	print "Removing SMS Client from $SUBSystemName\n";
	# Copy required files
	mkdir "//$SUBSystemName/c\$/sms";
	system ("rkill /install \\\\$SUBSystemName");
	system ("sc \\\\$SUBSystemName stop \"sms remote control agent\"");
	if (! $cliuser) {
		system ("psexec \\\\$SUBSystemName -c hammer.exe");
	}elsif ($cliuser) {
		system ("psexec \\\\$SUBSystemName -u $cliuser -p $clipass -c hammer.exe");
	}
 	system ("rkill /nkill \\\\$SUBSystemName wuser32.exe");
 	system ("rkill /nkill \\\\$SUBSystemName hinv32.exe");
 	system ("rkill /nkill \\\\$SUBSystemName sinv32.exe");
 	system ("rkill /nkill \\\\$SUBSystemName ccim32.exe");
 	system ("rkill /nkill \\\\$SUBSystemName clisvcl.exe");
 	system ("rkill /nkill \\\\$SUBSystemName clisvc95.exe");
 	system ("rkill /nkill \\\\$SUBSystemName smsapm32.exe");
 	system ("rkill /nkill \\\\$SUBSystemName smsmon32.exe");
 	system ("rkill /nkill \\\\$SUBSystemName launch32.exe");
	system ("rkill /deinstall \\\\$SUBSystemName");	 		 		 		 		 				 
	#finish cleaning
	system ("del /q /s \\\\$SUBSystemName\\admin\$\\ms");
	#Create Directories to move flag files back
	mkdir "//$SUBSystemName/admin\$/ms";
	mkdir "//$SUBSystemName/admin\$/ms/sms";
	mkdir "//$SUBSystemName/admin\$/ms/sms/clicomp";
	mkdir "//$SUBSystemName/admin\$/ms/sms/clicomp/apa";
	mkdir "//$SUBSystemName/admin\$/ms/sms/clicomp/apa/Data";
	mkdir "//$SUBSystemName/admin\$/ms/sms/clicomp/apa/Data/Complete";
	mkdir "//$SUBSystemName/admin\$/ms/sms/noidmifs";
	mkdir "//$SUBSystemName/admin\$/ms/sms/idmifs";
	#move flags back
	system ("copy \\\\$SUBSystemName\\admin\$\\flagbackup\\*.* \\\\$SUBSystemName\\admin\$\\ms\\sms\\clicomp\\apa\\Data\\Complete");
	system ("copy \\\\$SUBSystemName\\admin\$\\noidmifs\\*.* \\\\$SUBSystemName\\admin\$\\ms\\sms\\noidmifs");
	system ("copy \\\\$SUBSystemName\\admin\$\\idmifs\\*.* \\\\$SUBSystemName\\admin\$\\ms\\sms\\idmifs");
	#cleanup back of flags
	system ("del /q/s \\\\$SUBSystemName\\admin\$\\flagbackup");
	system ("rmdir \\\\$SUBSystemName\\admin\$\\flagbackup");
	system ("del /q/s \\\\$SUBSystemName\\admin\$\\idminsbackup");
	system ("rmdir \\\\$SUBSystemName\\admin\$\\idmifsbackup");
	system ("del /q/s \\\\$SUBSystemName\\admin\$\\noidmifsbackup");
	system ("rmdir \\\\$SUBSystemName\\admin\$\\noidmifsbackup");

	if (-e "\\\\$SUBSystemName\\admin\$\\smscfg.ini") { 
		system ("attrib -r -s -h \\\\$SUBSystemName\\admin\$\\smscfg.ini");
		system ("del /q \\\\$SUBSystemName\\admin\$\\smscfg.ini");
	} 
	#clean up
	system ("del /s/q \\\\$SUBSystemName\\c\$\\sms");
	system ("rmdir \\\\$SUBSystemName\\c\$\\sms");
	
	system ("REG DELETE \\\\$SUBSystemName\\HKLM\\SOFTWARE\\Microsoft\\SMS\\Client /f > temp.txt");
	system ("REG DELETE \\\\$SUBSystemName\\HKLM\\SOFTWARE\\Microsoft\\NAL\\Client /f > temp.txt");	
}