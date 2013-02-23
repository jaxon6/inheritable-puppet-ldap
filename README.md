inheritable-puppet-ldap
=======================

Tools to make Puppet work with LDAP and inherit classes

First, get your LDAP server up and running.  

The Apache Directory Studio is a great tool for managing LDAP servers
http://directory.apache.org/studio/

Follow the steps on the Puppet LDAP site, ensuring your schema includes puppet.schema

http://projects.puppetlabs.com/projects/1/wiki/Ldap_Nodes

Create a test computer object, making sure objectClass includes puppetClient
Add an exiting puppet class manually, setting attribute puppetClass=<classname>

Run puppet on that test computer, and it should:
- Contact the puppet master
- which queries LDAP for the test computer object
- LDAP finds the test computer object, retrieves the puppetClass=<classname> value
- LDAP sends the <classname> value to puppet master
- puppet master parses the <classname> class as per its normal behavior


Once the testing is finished, you are ready to automate the inheritance of puppet classes

To install:
Place the two cron_ files into /etc/cron.d.  Restart the cron daemon to pick them up
Place ldap2puppetsign.sh and puppetHierarchify.pl in /usr/local/bin

Both ldap2puppetsign.sh and puppetHierarchify.pl have variables that need editing.  
Since puppetHierarchify.pl is a perl script, you must make sure the perl modules are installed on the system running the scripts.

To use:
Organize your LDAP tree.  Create OUs and sub-OUs to store your computer objects.
At every OU, you can create an object that must be called cn=puppetClasses.  This cn=puppetClasses object must have objectClass=puppetClient.
Then, create one or more puppetClass attributes on this cn=puppetClasses object.

The puppetClass attributes associated with the cn=puppetClasses object will automatically be applied to every computer object underneath it.
That is, if a computer object lives under an OU which has a cn=puppetClasses entry, then all puppetClass entries in that object will be applied to the computer.

More information can be found in the Hierarchical Systems Policy Management in a Puppet.pdf which is also on github