#!/bin/bash

#this is our domain

#autosign.conf wants servers in FQDN format, while they live in LDAP as simple cn=host objects.
#we append the domain name to make autosign happy
DOMAIN=<specify domain here>
PUPPETAUTOSIGN=/etc/puppet/autosign.conf
SERVERNAME=<specify server name here.  127.0.0.1, localhost, server.example.com...)
BINDUSER=<specify bind dn, user account for connecting, e.g., cn=admin,ou=Admins,dc=server,dc=company,dc=com>
BINDPASS=<specify pass here>
SEARCHBASE=<specify top-level OU under which hosts live in LDAP here.  e.g.- ou=company,ou=Hosts,dc=server,dc=company,dc=com>

#if encryption is used, alternate ldapsearch parameters will be needed

#we grab all the hosts in the tree in ldap, appending the proper domain
#we query the fqdn in /etc/puppet/autosign.conf, and if it doesn't exist, add it
#run once per minute from cron and you have instant-add, instant-sign, instant instance boot

for i in `ldapsearch -H ldap://${SERVERNAME} -w ${PASS} \
-D ${BINDUSER} -b ${SEARCHBASE} \
"(&(objectClass=puppetClient)(!(cn=puppetClasses)))" cn|grep ^cn|awk '{print $2}'`

do
LDAPHOST=$i."${DOMAIN}"

#do the search (-x means full line search), and if we fail, jam it in there
/bin/grep -q -x "${LDAPHOST}" "${PUPPETAUTOSIGN}" || ( echo "${LDAPHOST}" >> "${PUPPETAUTOSIGN}"; echo "${LDAPHOST}"  )

done

