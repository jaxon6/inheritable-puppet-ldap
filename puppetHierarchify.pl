#!/usr/bin/perl

#make sure the following modules are installed
use strict;
use Sys::Syslog;
use Net::LDAP;
use Net::LDAP::Filter;
use Net::LDAP::Util qw(ldap_error_name ldap_error_text);

#this below is awful to look at :-(
my ($ldap, $findHostsMatch, $bindFilter, $bindMesg, $entry, @hostsArray, $getHostsMax, 
$getHostsMaxLoop, $hostsArrayCount, $fullhostDN, $hostDN, @puppetTemplatesArray, 
@pwkngTemplatesArray, $pwkngTemplatesArrayCount, $pwkngTemplatesArrayLoop, 
$ouValue, @ouArray, $ouloopValue, $ouloopCount, $ouArrayCount, $ouArrayLoop, 
$puppetTemplate, $puppetTemplatesMatch, $puppetTemplatesFilter, $puppetTemplatesMesg, 
$puppetTemplatesEntry, $puppetTemplatesAttr, $puppetTemplatesAttrValue, 
@puppetClassesArray, $puppetTemplatesCounter, $hostinfoCounter, $hostinfoLoop, 
$hostinfo, $hostinfoMatch, $hostinfoFilter, $hostinfoMesg, $hostinfoEntry, 
$hostinfoAttrValue, @hostinfoClassesArray, @ptmplArray, $ptmplac, $ptmplLoop, 
@hinfoArray, $hinfoac, $hinfoLoop, $tmpCounter, $tmpC, %puppetClassesSeen, 
@uniqPuppetClassesArray, $uniqPuppetItem, %htmpHash, $htmpCounter, $htmpC, 
$hinfoItem, %uniqPuppetClassesHash, @pcinfoClassesArray, $PCinfoCounter, 
$PCinfoMatch, $PCinfoFilter, $PCinfoMesg, $PCinfoEntry, $PCinfoAttrValue, @PCinfoArray, 
$PCinfoac, $pcInfoLoop, $pctmpCounter, $pctmpC, $PCinfoLoop, $pcinfoItem, 
%pcinfoClassesHash, $doLdapAttrAction, $doLdapAttrItem, $doLdapAttrValue, 
$doLdapAttrEntry, $PCinfoEntryMesg, $performUpdate);

#change the variables here.  this is just the connection string
#d is debug.  increase when errors occur
#b is the baseOU
#D is username, w is password
#p is port, V is ldap version
#the following does not use encryption, which is acceptable for running the script against localhost, but not for cross-network traffic
my %opt = (
  'b' => 'specify top-level OU under which hosts live in LDAP here.  e.g.- ou=company,ou=Hosts,dc=server,dc=company,dc=com',
  'h' => 'specify hostname here, e.g. - localhost, server.company.com, 127.0.0.1, ...',
  'p' => '389',
  'd' => 0,
  'D' => 'specify bind dn, user account for connecting, e.g., cn=admin,ou=Admins,dc=server,dc=company,dc=com',
  'w' => 'specify password for above user',
  'V' => '3'
);

#prep syslog
openlog("puppetHierarchify Script: ");

#bind
Bind();

#get all of our hosts
getHosts();

#now do work
foreach (@hostsArray) {

	getTemplateHosts($_);
	syslog('info', 'The full host DN is ' . $fullhostDN);


	#print "\n";
	#print "The full host DN is \n";
	#print $fullhostDN;
	#print "\n";
	#print $hostDN;
	#print "\n";


	getPuppetClasses();
	uniqifyPuppetClasses();


#	print "The template Puppet Classes for this host \n";
#	$tmpCounter = @uniqPuppetClassesArray;
#	for ( $tmpC = 0; $tmpC < $tmpCounter; $tmpC++ ) {
#		print $uniqPuppetClassesArray[$tmpC];
#		print "\n";
#	}

	getHostinfo();
	getPCinfo();

#	print "The ldap info attr values for this host \n";
#	$htmpCounter = @hostinfoClassesArray;
#	for ( $htmpC = 0; $htmpC < $htmpCounter; $htmpC++ ) {
#		print $hostinfoClassesArray[$htmpC];
#		print "\n";
#	}

#	print "The ldap puppetClass attr values for this host";
#	$pctmpCounter = @pcinfoClassesArray;
#	print "\n";
#	for ( $pctmpC = 0; $pctmpC < $pctmpCounter; $pctmpC++ ) {
#		print $pcinfoClassesArray[$pctmpC];
#		print "\n";
#	}


#	%htmpHash = map { $_ => $_ } @uniqPuppetClassesArray;
#	foreach $htmpC (@uniqPuppetClassesArray) {
#		print $htmpHash{$htmpC};
#		print "\n";
#	}

#	%htmpHash = map { $_ => $_ } @hostinfoClassesArray;
#	foreach $htmpC (@hostinfoClassesArray) {
#		print $htmpHash{$htmpC};
#		print "\n";
#	}


	processHostinfo();

}


$ldap->unbind;
closelog();
#
#
#
#end










sub doLdapAttr {
#actually do some work.  fullhostdn is already a variable
#the other 3 variables were passed
#we can ride on the coattails of sub getpcinfo, as the $PCinfoEntry
#ldap connection to the host has alread been established
#the action gets called multiple times, adding and deleting whenever
#but only after processHostinfo calls $PCinfoEntry->update ( $ldap );


$doLdapAttrAction = $_[0];#add|delete
$doLdapAttrItem = $_[1];
$doLdapAttrValue = $_[2];
#print $doLdapAttrAction . " " . $doLdapAttrItem . " " . $doLdapAttrValue;
#print "\n";

$PCinfoEntry->$doLdapAttrAction ($doLdapAttrItem => "$doLdapAttrValue");



#end sub
}


sub processHostinfo {
#if hostinfo attr is in the puppetClassesArray, do nothing
#else delete the info attr and corresponding puppetClass
#the doLdapAttr action creates a long list of actions to perform
#but only after we call $PCinfoEntry->update ( $ldap ) directly before
#end sub does anything get commited
undef $performUpdate;
%uniqPuppetClassesHash = map { $_ => $_ } @uniqPuppetClassesArray;

foreach $hinfoItem (@hostinfoClassesArray) {
	#print $uniqPuppetClassesHash{$hinfoItem};
	unless (exists($uniqPuppetClassesHash{$hinfoItem})) {	
		#print "I am going to delete info attr $hinfoItem\n";
		syslog('info', 'Deleting info attribute ' . $hinfoItem);
		doLdapAttr('delete','info',$hinfoItem);
		#print "I am going to delete puppetClass attr $hinfoItem\n";
		syslog('info', 'Deleting puppetClass attribute ' . $hinfoItem);
		doLdapAttr('delete','puppetClass',$hinfoItem);
		$performUpdate = 1;
	}
}

#if puppetClass is in the hosts puppetClass array, do nothing
#else add the puppetClass and corresponding info attr
%pcinfoClassesHash = map { $_ => $_ } @pcinfoClassesArray;

foreach $pcinfoItem (@uniqPuppetClassesArray) {
	unless (exists($pcinfoClassesHash{$pcinfoItem})) {
		#print "I am going to add the puppetClass attr $pcinfoItem\n";
		syslog('info', 'Adding puppetClass attribute ' . $pcinfoItem);
		doLdapAttr('add','puppetClass',$pcinfoItem);
		#print "I am going to add the info attr $pcinfoItem\n";
		syslog('info', 'Adding info attribute ' . $pcinfoItem);
		doLdapAttr('add','info',$pcinfoItem);
		$performUpdate = 1;
	}
}

if ($performUpdate) {
	#now actually commit our changes
	$PCinfoEntryMesg = $PCinfoEntry->update($ldap);
	#print $PCinfoEntryMesg->error_name;
	#print "\n";
	syslog('info', $PCinfoEntryMesg->error_name);

}
#end sub
}



sub uniqifyPuppetClasses {
#we just make sure the array is unique; no need for dup values
%puppetClassesSeen = ();
undef @uniqPuppetClassesArray;

foreach $uniqPuppetItem (@puppetClassesArray) {
	push(@uniqPuppetClassesArray, $uniqPuppetItem) unless $puppetClassesSeen{$uniqPuppetItem}++;
}

#end sub
}


sub getPCinfo {
#get the puppetClasses attributes associated with this host
undef @pcinfoClassesArray;
$PCinfoCounter = 0;

$PCinfoMatch =  "(objectClass=puppetClient)";
$PCinfoFilter = Net::LDAP::Filter->new($PCinfoMatch) or die "Bad bindFilter $PCinfoMatch";
$PCinfoMesg = $ldap->search ( #do the search
				       base   => $fullhostDN,
				       filter => $PCinfoFilter,
				       scope  => "base",
				       attrs  => ['puppetClass'],
) or die $@;


#if error, then print error as host should exist
$PCinfoMesg->code && die $PCinfoMesg->error;

#we only return one host, so just search for entry 0
$PCinfoEntry = $PCinfoMesg->entry ( 0 );
if ($PCinfoEntry->exists( 'puppetClass' )) {
	$PCinfoAttrValue = join( "\n", $PCinfoEntry->get_value( 'puppetClass' ) ), ;
	@PCinfoArray = (split(/\n/, $PCinfoAttrValue));
	$PCinfoac = @PCinfoArray;
	for ( $PCinfoLoop = 0; $PCinfoLoop < $PCinfoac; $PCinfoLoop++ ) {
		$pcinfoClassesArray[$PCinfoCounter] =  $PCinfoArray[$PCinfoLoop];;
		#print $pcinfoClassesArray[$PCinfoCounter];
		#print "\n";
		$PCinfoCounter++;
	}

}

#end sub
}


sub getHostinfo {
undef @hostinfoClassesArray;
$hostinfoCounter = 0;

$hostinfoMatch =  "(objectClass=puppetClient)";
$hostinfoFilter = Net::LDAP::Filter->new($hostinfoMatch) or die "Bad bindFilter $hostinfoMatch";
$hostinfoMesg = $ldap->search ( #do the search
				       base   => $fullhostDN,
				       filter => $hostinfoFilter,
				       scope  => "base",
				       attrs  => ['info'],
) or die $@;


#if error, then print error as host should exist
$hostinfoMesg->code && die $hostinfoMesg->error;

#we only return one host, so just search for entry 0
$hostinfoEntry = $hostinfoMesg->entry ( 0 );
if ($hostinfoEntry->exists( 'info' )) {
	$hostinfoAttrValue = join( "\n", $hostinfoEntry->get_value( 'info' ) ), ;
	@hinfoArray = (split(/\n/, $hostinfoAttrValue));
	$hinfoac = @hinfoArray;
	for ( $hinfoLoop = 0; $hinfoLoop < $hinfoac; $hinfoLoop++ ) {
		#ok, so this is how we get all the values of info in ldap
		#we get the count of the array, $hinfoac, and we loop
		#but, because we want to ignore and not process any admin info=
		#we check the current info value, $hinfoArray[$hinfoLoop]
		#for admin inf.  currently macAddress
		if ($hinfoArray[$hinfoLoop] !~ m/^macAddress/) {
			$hostinfoClassesArray[$hostinfoCounter] = $hinfoArray[$hinfoLoop];
			#print $hostinfoClassesArray[$hostinfoCounter];
			#print "\n";
			$hostinfoCounter++;	
		}
	}

}

#end sub
}



sub getPuppetClasses {
undef @puppetClassesArray;
$ouArrayCount = @ouArray;
$puppetTemplatesCounter = 0;

for ( $ouArrayLoop = 0; $ouArrayLoop < $ouArrayCount; $ouArrayLoop++ ) {
	$puppetTemplate = $ouArray[$ouArrayLoop];
	$puppetTemplatesMatch =  "(objectClass=puppetClient)";
	$puppetTemplatesFilter = Net::LDAP::Filter->new($puppetTemplatesMatch) or die "Bad bindFilter $puppetTemplatesMatch";
	$puppetTemplatesMesg = $ldap->search ( #do the search
					       base   => $puppetTemplate,
					       filter => $puppetTemplatesFilter,
					       scope  => "base",
					       attrs  => ['puppetClass'],
	) or die $@;


	#if error, spit out error - don't die, as some hosts are in OUs without puppetClasses objects
	#$puppetTemplatesMesg->code && print $puppetTemplatesMesg->error;

	#print $puppetTemplate;
	#print "\n";
	#we only search for one object, so no looping, just an if for not 0
	if ( $puppetTemplatesMesg->count != 0) {
		#we only return one host, so just search for entry 0
		$puppetTemplatesEntry = $puppetTemplatesMesg->entry ( 0 );
		if ($puppetTemplatesEntry->exists( 'puppetClass' )) {
			$puppetTemplatesAttrValue = join( "\n", $puppetTemplatesEntry->get_value( 'puppetClass' ) ), ;
			@ptmplArray = (split(/\n/, $puppetTemplatesAttrValue));
			$ptmplac = @ptmplArray;
			#print $ptmplac;
			#print "\n";
			for ( $ptmplLoop = 0; $ptmplLoop < $ptmplac; $ptmplLoop++ ) {
				$puppetClassesArray[$puppetTemplatesCounter] = $ptmplArray[$ptmplLoop];
				#print $puppetClassesArray[$puppetTemplatesCounter];
				#print "\n";
				$puppetTemplatesCounter++;
			}
		}
	}

#	print $puppetTemplate;
#	print "\n";
}

#end sub
}



sub getTemplateHosts {
undef @ouArray;
#get all cn=puppetClasses objects for this hostDN
$hostDN = shift @_;
$fullhostDN = $hostDN;

#get all relevant puppetClass cn's
#then search using scope => base
#strip the base dn
$hostDN =~ s/,$opt{b}//;
#strip the hostname
$hostDN =~ s/^cn\=[a-zA-z0-9\-_]*\,//;
#create an array based on commas - the reverse is needed for proper looping
@pwkngTemplatesArray = reverse(split(/,/, $hostDN));
#print @pwkngTemplatesArray;
#print "\n";
#get number of entries in array
$pwkngTemplatesArrayCount = @pwkngTemplatesArray;
#print $pwkngTemplatesArrayCount;


#loop backwards through the array created from the split op above
#for ( $pwkngTemplatesArrayLoop = $pwkngTemplatesArrayCount; $pwkngTemplatesArrayLoop > 0; $pwkngTemplatesArrayLoop-- ) {
for ( $pwkngTemplatesArrayLoop = 0; $pwkngTemplatesArrayLoop < $pwkngTemplatesArrayCount; $pwkngTemplatesArrayLoop++ ) {
	#print $pwkngTemplatesArrayLoop;
	#print "\n";
	undef $ouValue;
	#now, loop from 0 to size of array, which means how many ous deep is object 
	for ( $ouloopCount = 0; $ouloopCount <= $pwkngTemplatesArrayLoop; $ouloopCount++) {
		#append a comma, then combine with ouvalue
		$ouloopValue = $pwkngTemplatesArray[$ouloopCount] . ",";
		$ouValue = $ouloopValue . $ouValue;
	}
	$ouValue = "cn=puppetClasses," . $ouValue . $opt{b};
#	$ouValue = $ouValue . $opt{b};
	$ouArray[$pwkngTemplatesArrayLoop] = $ouValue;
	
	#print $ouArray[$pwkngTemplatesArrayLoop];
	#print "\n";
}	
#add the Hosts ou to this array
$ouArray[$pwkngTemplatesArrayLoop + 1] = "cn=puppetClasses," . $opt{b};
#end sub
}


sub getHosts {
#this is cn=puppetClient, from options above
#basically, search for all objectClass=puppetClient, but not if cn=puppetClasses or =default
$findHostsMatch = "(&(objectClass=puppetClient)(!(cn=puppetClasses))(!(cn=default)))";
$bindFilter = Net::LDAP::Filter->new($findHostsMatch) or die "Bad bindFilter $findHostsMatch";
#only return the dn, don't need to do a full searhc, that's the 1.1
$bindMesg = $ldap->search( #do the search
                           base   => $opt{b},
                           filter => $bindFilter,
			   attrs => ['1.1'],
) or die $@;
#if error, spit out error
$bindMesg->code && die $bindMesg->error;
#test loop

$getHostsMax = $bindMesg->count;
for ( $getHostsMaxLoop = 0 ; $getHostsMaxLoop < $getHostsMax ; $getHostsMaxLoop++ ) {
	$entry = $bindMesg->entry ( $getHostsMaxLoop );
	$hostsArray[$getHostsMaxLoop] = $entry->dn();
#	print $hostsArray[$getHostsMaxLoop];
#	print $entry->dn();
#	print "\n";

}
$hostsArrayCount = @hostsArray;

#print $hostsArrayCount;
#foreach $entry ($bindMesg->entries) { 
##	$entry->dump;
#	print $entry->get_value ( 'DN' );
#	print $entry->dn();
#	print "\n";
#}

#end sub
}

sub Bind {
#connection string
$ldap = Net::LDAP->new($opt{'h'},
                            port => $opt{'p'},
                         timeout => 10,
                           debug => $opt{'d'},
) or die $@;

#
# Bind to directory.
#
$bindMesg = $ldap->bind($opt{'D'},
             password => "$opt{'w'}",
              version => $opt{'V'},
)or die $@;
$bindMesg->error;
#end sub
}
