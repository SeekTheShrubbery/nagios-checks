# nagios-checks

#check_3par_par
Same as the one provided from the nagios exchange website, except for added performance data for FC,SSD. For how to use, please make use of the manual, which you can find at:
https://exchange.nagios.org/directory/Plugins/Hardware/Storage-Systems/SAN-and-NAS/3PAR-check-script/details

#check_snmp_win.pl
Changed the format of the output. It was fairly confusing and did not match the other plugins we were using at the time. In addition, I added multiline output for all running service.
It is not possible to get the OID's for stopped services. Which would be a huge benefit for troubleshooting. Therefore it lists only the running services.

#check_win_snmp_disk.pl
Added the magic number functionality, which was developed by check_mk. For any details, please head over to https://mathias-kettner.de/checkmk_filesystems.html
In addition you can also find a perl implemenation of the python script below.

#copy_bp_to_nagios.sh
A handler for thruk to copy over the bp config to nagios.

#df_magic_number.pl
The perl version of the python script by https://mathias-kettner.de/checkmk_filesystems.html

