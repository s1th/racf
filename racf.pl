#==============================================
# Script to analyze the RACFDB 
#
# Input: the text file created by the IRRDBU00 utility
#==============================================
use strict;
#use warnings;
use IAD::MiscFunc;
use IAD::WPXL;
use Date::Calc qw( Date_to_Days );

#=====
#Vars
#=====
my $racfdb = "d:\\racf\\racfdb.txt";	            #racf database unload file
my %rec_analysis;						            #record type analysis/stats
my %group_basic_data_record;        	            #hold all 0100 records - key = $gpbd_name
my %group_subgroups_record;         	            #hold all 0101 records - keyed by group and then all subgroups for that groups -> {$gpsgrp_name}->{$gpsgrp_subgrp_id} = 1
my %group_members_record;           	            #hold all 0102 records - keyed by group name, then user id, then auth type -> $group_memebers_record{$gpmem_name}->{$gpmem_member_id}->{auth} = $gpmem_auth
my %group_dfp_data_record;          	            #hold all 0110 records - keyed by group name, application name, and data class - $group_dfp_data_record{$gpdfp_name}->{$gpdfp_dataappl}->{$gpdfp_dataclas} = 1
my %group_omvs_data_record;         	            #hold all 0120 records - keyed by omvs group name - $group_omvs_data_record{$gpomvs_name}->{gid} = $gpomvs_gid
my %user_basic_data_record;         	            #hold all 0200 records - keyed by user profile name - $user_basic_data_record{$usbd_name}->{create_date} = $usbd_create_date;
my %user_group_connections_record;  	            #hold all 0203 records - keyed by user profile - $user_group_connections_record{$usgcon_name}->{$usgcon_grp_id} = 1;
my %user_connect_data_record;       	            #hold all 0205 records - keyed by user profile, then group profile - $user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{grp_audit}    = $uscon_grp_audit;
my %user_certificate_name_record;   	            #hold all 0207 records - keyed by given cert name, then the crazy cert string - $user_certificate_name_record{$uscert_name}->{$uscert_cert_name}->{label} = $uscert_certlabl;
my %user_tso_data_record;          	 	            #hold all 0220 records - keyed by user profile name - $user_tso_data_record{$ustso_name}->{account}      = $ustso_account;
my %user_cics_data_record;          	            #hold all 0230 records - keyed by user profile name - $user_cics_data_record{$uscics_name}->{opident} = $uscics_opident;
my %user_operparm_data_record;      	            #hold all 0250 records - keyed by user profile name - $user_operparm_data_record{$usopr_name}->{storage}    = $usopr_storage;
my %user_operparm_scope;           	 	            #hold all 0251 records - keyed by user profile name - $user_operparm_scope{$usopr_name}->{$usopr_system} = 1;
my %user_omvs_data_record;          	            #hold all 0270 records - keyed by omvs user profile name - $user_omvs_data_record{$usomvs_name}->{uid}       = $usomvs_uid;
my %user_netview_segment_record;    	       	    #hold all 0280 records - keyed by user profile name - $user_netview_segment_record{$usnetv_name}->{ic}       = $usnetv_ic;
my %user_kerb_data_record;          	  	  	    #hold all 02D0 records - keyed by user profile name - $user_kerb_data_record{$uskerb_name}->{kerbname}     = $uskerb_kerbname;
my %data_set_basic_data_record;     	      	    #hold all 0400 records - keyed by data set name - $data_set_basic_data_record{$dsbd_name}->{vol}          = $dsbd_vol;
my %data_set_volumes_record;       		 	  	    #hold all 0403 records - keyed by data set name - $data_set_volumes_record{$dsvol_name}->{$dsvol_vol}->{vol_name} = $dsvol_vol_name;
my %data_set_access_record;                  		#hold all 0404 records - keyed by data set name - $data_set_access_record{$dsacc_name}->{$dsacc_auth_id}->{vol}        = $dsacc_vol;
my %general_resource_basic_data_record;  	   		#hold all 0500 records - keyed by general resource name - $general_resource_basic_data_record{$grbd_name}->{class_name}    = $grbd_class_name;
my %general_resource_members_record;           		#hold all 0503 records - keyed by member name - $general_resource_members_record{$grmem_member}->{name}         = $grmem_name;
my %general_resource_access_record;            		#hold all 0505 records - keyed by member name then user/group id - $general_resource_access_record{$gracc_name}->{$gracc_auth_id}->{class_name} = $gracc_class_name;
my %general_resource_started_task_data_record; 		#hold all 0540 records - keyed by task name - $general_resource_started_task_data_record{$grst_name}->{class_name} = $grst_class_name;
my %general_resource_certificate_data_record;  		#hold all 0560 records - keyed by certificate name - $general_resource_certificate_data_record{$grcert_name}->{class_name}  = $grcert_class_name;
my %general_resource_certificate_references_record; #hold all 0561 records - keyed by certificate name - $general_resource_certificate_references_record{$certr_name}->{class_name} = $certr_class_name;
my %general_resource_key_ring_data_record;          #hold all 0562 records - keyed by certificate name - $general_resource_key_ring_data_record{$keyr_name}->{class_name} = $keyr_class_name;
my %general_resource_alias_data_record;             #hold all 05B0 records - keyed by general resource name - $general_resource_alias_data_record{$gralias_name}->{class_name} = $gralias_class_name;

#==============
#Parsing Section
#==============
open RDB, "$racfdb"
	or die "Can't open the racf db ($racfdb): $!\n";
while (<RDB>)
{
	chomp;
	my $line = $_;
	my($rec_type) = substr($line,0,4);
	
	#track record stats
	$rec_analysis{$rec_type}->{count}++;
	$rec_analysis{total}++;
	
	#parse out information based on record type
	if ( $rec_type eq "0100" )
	{
		#-----Group basic data record-----
		my($gpbd_name)         = IAD::MiscFunc::trim( substr($line,5,8) );    #group name as taken from the profile name
		my($gpbd_subgrp_id)    = IAD::MiscFunc::trim( substr($line,14,8) );   #name of the superior group to this group
		my($gpbd_create_date)  = IAD::MiscFunc::trim( substr($line,23,10) );  #date group was defined
		my($gpbd_owner_id)     = IAD::MiscFunc::trim( substr($line,34,8) );   #the user ID or group name which owns the profile
		my($gpbd_uacc)         = IAD::MiscFunc::trim( substr($line,43,8) );   #default universal access [NONE or VSAMDSET group which has CREATE]
		my($gpbd_notermuacc)   = IAD::MiscFunc::trim( substr($line,52,4) );   #indicates if the group must be specifically authorized to use a particular terminal through use of PERMIT cmd
		my($gpbd_install_data) = IAD::MiscFunc::trim( substr($line,57,255) ); #installation-defined data [e.g. at TRU this is the group description]
		my($gpbd_model)        = IAD::MiscFunc::trim( substr($line,313,43) ); #data set profile that is used as a model for this group
		my($gpbd_universal)    = IAD::MiscFunc::trim( substr($line,358,4) );  #data set profile that is used as a model for this group
		
		#store
		$group_basic_data_record{$gpbd_name}->{sub_grp_id}   = $gpbd_subgrp_id;
		$group_basic_data_record{$gpbd_name}->{create_date}  = $gpbd_create_date;
		$group_basic_data_record{$gpbd_name}->{owner_id}     = $gpbd_owner_id;
		$group_basic_data_record{$gpbd_name}->{uacc}         = $gpbd_uacc;
		$group_basic_data_record{$gpbd_name}->{notermuacc}   = $gpbd_notermuacc;
		$group_basic_data_record{$gpbd_name}->{install_data} = $gpbd_install_data; #really group description
		$group_basic_data_record{$gpbd_name}->{model}        = $gpbd_model;
		$group_basic_data_record{$gpbd_name}->{universal}    = $gpbd_universal;	
	}
	elsif ( $rec_type eq "0101" )
	{
		#----Group subgroups record-----
		my($gpsgrp_name)      = IAD::MiscFunc::trim( substr($line,5,8) );  #group name as taken from the profile name
		my($gpsgrp_subgrp_id) = IAD::MiscFunc::trim( substr($line,14,8) ); #the name of a subgroup within the group
		
		#store
		$group_subgroups_record{$gpsgrp_name}->{$gpsgrp_subgrp_id} = 1;
	}
	elsif ( $rec_type eq "0102" )
	{
		#-----Group Members Record-----
		my($gpmem_name)      = IAD::MiscFunc::trim( substr($line,5,8) );  #group name as taken from the profile name 
		my($gpmem_member_id) = IAD::MiscFunc::trim( substr($line,14,8) ); #a user id within the group
		my($gpmem_auth)      = IAD::MiscFunc::trim( substr($line,23,8) ); #indicates the authority that the user id has within the group...valid values are [USE, CONNECT, JOIN, and CREATE]
		
		#store 
		$group_members_record{$gpmem_name}->{$gpmem_member_id}->{auth} = $gpmem_auth;
		
		if ( $gpmem_name eq "SYSTEMS")
		{
			print "$gpmem_name: $gpmem_member_id\n";
		}
		
	}
	elsif ( $rec_type eq "0103" )
	{
		#-----Group installation data record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0110" )
	{
		#-----Group DFP data record-----
		my($gpdfp_name)     = IAD::MiscFunc::trim( substr($line,5,8) );   #group name as taken from the profile name
		my($gpdfp_dataappl) = IAD::MiscFunc::trim( substr($line,14,8) );  #default application name for the group
		my($gpdfp_dataclas) = IAD::MiscFunc::trim( substr($line,23,8) );  #default data class for the group
		
		#default mgmt class - data inconsistencies
		eval( my($gpdfp_mgmtclas) = substr($line,32,8) );   #default management class for the group
		if ($gpdfp_mgmtclas) { $gpdfp_mgmtclas = IAD::MiscFunc::trim($gpdfp_mgmtclas); }
		
		#default storage class - data inconsistencies
		eval( my($gpdfp_storclas) = substr($line,41,8) );   #default storage class for the group
		if ($gpdfp_storclas) { $gpdfp_storclas = IAD::MiscFunc::trim($gpdfp_storclas); }
		
		#store
		$group_dfp_data_record{$gpdfp_name}->{$gpdfp_dataappl}->{dataclas} = $gpdfp_dataclas;
		$group_dfp_data_record{$gpdfp_name}->{$gpdfp_dataappl}->{mgmtclas} = $gpdfp_mgmtclas;
		$group_dfp_data_record{$gpdfp_name}->{$gpdfp_dataappl}->{storclas} = $gpdfp_storclas;		
	}
	elsif ( $rec_type eq "0120" )
	{
		#Group OMVS data record
		my($gpomvs_name) = IAD::MiscFunc::trim( substr($line,5,8) );   #group name as taken from the profile name
		my($gpomvs_gid)  = IAD::MiscFunc::trim( substr($line,14,10) ); #omvs z/OS unix group identifier (GID) associated with the group name form the profile
		
		#store
		$group_omvs_data_record{$gpomvs_name}->{gid} = $gpomvs_gid;
	}
	elsif ( $rec_type eq "0130" )
	{
		#-----Group OMVS data record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0141" )
	{
		#-----Group TIME role record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0200" )
	{
		#-----User basic data record-----
		my($usbd_name)          = IAD::MiscFunc::trim( substr($line,5,8) );     #user id as taken from the profile name
		my($usbd_create_date)   = IAD::MiscFunc::trim( substr($line,14,10) );   #the date that the profile was created
		my($usbd_owner_id)      = IAD::MiscFunc::trim( substr($line,25,8) );    #the user id or group name that owns the profile
		my($usbd_adsp)          = IAD::MiscFunc::trim( substr($line,34,4) );    #does the user have the ADSP (automatic data set protection) attribute (yes/no)?
		my($usbd_special)       = IAD::MiscFunc::trim( substr($line,39,4) );    #does the user have the SPECIAL attribute (yes/no)?
		my($usbd_oper)          = IAD::MiscFunc::trim( substr($line,44,4) );    #does the user have the OPERATIONS attribute (yes/no)?
		my($usbd_revoke)        = IAD::MiscFunc::trim( substr($line,49,4) );    #is the user REVOKEd (yes/no)?
		my($usbd_grpacc)        = IAD::MiscFunc::trim( substr($line,54,4) );    #does the user have the GRPACC attribute (yes/no)?
		my($usbd_pwd_interval)  = IAD::MiscFunc::trim( substr($line,59,3) );    #the number of days that the user's password can be used
		my($usbd_pwd_date)      = IAD::MiscFunc::trim( substr($line,63,10) );   #the date that the password was last changed
		my($usbd_programmer)    = IAD::MiscFunc::trim( substr($line,74,20) );   #the name associated with the user id
		my($usbd_defgrp_id)     = IAD::MiscFunc::trim( substr($line,95,8) );    #the default group associated with the user
		my($usbd_lastjob_time)  = IAD::MiscFunc::trim( substr($line,104,8) );   #the time that the user last entered the system
		my($usbd_lastjob_date)  = IAD::MiscFunc::trim( substr($line,113,10) );  #the time that the user last entered the system
		my($usbd_install_data)  = IAD::MiscFunc::trim( substr($line,125,255) ); #the time that the user last entered the system
		my($usbd_uaudit)        = IAD::MiscFunc::trim( substr($line,380,4) );   #do all RACHECK and RACDEF SVCs cause logging (yes/no)?
		my($usbd_auditor)       = IAD::MiscFunc::trim( substr($line,385,4) );   #does the user have the AUDITOR attribute (yes/no)?
		my($usbd_nopwd)         = IAD::MiscFunc::trim( substr($line,390,4) );   #"YES" indicates that this user can logon without a password using OID card.  "NO" indicates that this 
																			    #user must specify a password.  "PRO" indicates a protected user id. "PHR" indicates that the user
																				#has a password phrase.
		my($usbd_oidcard)       = IAD::MiscFunc::trim( substr($line,395,4) );   #does this user have OIDCARD data (yes/no)?
		my($usbd_pwd_gen)       = IAD::MiscFunc::trim( substr($line,400,3) );   #the current password generation number
		my($usbd_revoke_cnt)    = IAD::MiscFunc::trim( substr($line,404,3) );   #the number of unsuccessful logon attempts
		my($usbd_model)         = IAD::MiscFunc::trim( substr($line,409,44) );  #the data set model profile name
		my($usbd_seclevel)      = IAD::MiscFunc::trim( substr($line,453,3) );   #the user's security level - not in use at TRU
		my($usbd_revoke_date)   = IAD::MiscFunc::trim( substr($line,457,10) );  #the date that the user will be revoked
		my($usbd_resume_date)   = IAD::MiscFunc::trim( substr($line,468,10) );  #the date that the user will be resumed
		my($usbd_access_sun)    = IAD::MiscFunc::trim( substr($line,479,4) );   #can the user access the system on Sunday (yes/no)?
		my($usbd_access_mon)    = IAD::MiscFunc::trim( substr($line,484,4) );   #can the user access the system on Monday (yes/no)?
		my($usbd_access_tue)    = IAD::MiscFunc::trim( substr($line,489,4) );   #can the user access the system on Tuesday (yes/no)?
		my($usbd_access_wed)    = IAD::MiscFunc::trim( substr($line,494,4) );   #can the user access the system on Wednesday (yes/no)?
		my($usbd_access_thu)    = IAD::MiscFunc::trim( substr($line,499,4) );   #can the user access the system on Thursday (yes/no)?
		my($usbd_access_fri)    = IAD::MiscFunc::trim( substr($line,504,4) );   #can the user access the system on Friday (yes/no)?
		my($usbd_access_sat)    = IAD::MiscFunc::trim( substr($line,509,4) );   #can the user access the system on Saturday (yes/no)?
		my($usbd_start_time)    = IAD::MiscFunc::trim( substr($line,514,8) );   #after what time can the user logon?
		my($usbd_end_time)      = IAD::MiscFunc::trim( substr($line,523,8) );   #after what time can the user not logon?
		my($usbd_seclabel)      = IAD::MiscFunc::trim( substr($line,532,8) );   #the user's default security label
		my($usbd_attribs)       = IAD::MiscFunc::trim( substr($line,541,8) );   #other user attributes (RSTD for users with RESTRICTED attribute)
																				#a user with the RESTRICTED attribute is only granted access to a dataset or resource if its userid
																				#or group is EXPLICITLY permitted to the dataset or resource file.  This means that RACHECK and
																				#FRACHECK basic RACF functions will NOT grant such userids access based on:
																				#	-UACC
																				#	-ID(*)
																				#	-GLOBAL rules
																				#an elegant solution to prevent universal access
		my($usbd_pwdenv_exists) = IAD::MiscFunc::trim( substr($line,550,4) );   #has a PKCS#7 envelope been created for the user's current password (yes/no)?
		my($usbd_pwd_asis)      = IAD::MiscFunc::trim( substr($line,555,4) );   #should the password be evaluated in the case entered?
		my($usbd_phr_date)      = IAD::MiscFunc::trim( substr($line,560,10) );  #the date the password phrase was last changed
		my($usbd_phr_gen)       = IAD::MiscFunc::trim( substr($line,571,3) );   #the current password phrase generation number
		my($usbd_cert_seqn)     = IAD::MiscFunc::trim( substr($line,575,10) );  #sequence number that is incremented whenever a certificate for the user is added, deleted, or altered
		
		#pkcs#7 envelope - data inconsistencies
		eval( my($usbd_pphenv_exists) = substr($line,586,1) );   #has a PKCS#7 envelope been created for the user's current password phrase (yes/no)?
		if ($usbd_pphenv_exists) { $usbd_pphenv_exists = IAD::MiscFunc::trim($usbd_pphenv_exists); }
		
		#store
		$user_basic_data_record{$usbd_name}->{create_date}   = $usbd_create_date;
		$user_basic_data_record{$usbd_name}->{owner_id}      = $usbd_owner_id;
		$user_basic_data_record{$usbd_name}->{adsp}          = $usbd_adsp;
		$user_basic_data_record{$usbd_name}->{special}       = $usbd_special;
		$user_basic_data_record{$usbd_name}->{oper}          = $usbd_oper;
		$user_basic_data_record{$usbd_name}->{revoked}       = $usbd_revoke;
		$user_basic_data_record{$usbd_name}->{grpacc}        = $usbd_grpacc;
		$user_basic_data_record{$usbd_name}->{pwd_interval}  = $usbd_pwd_interval;
		if ( $usbd_programmer =~ /^####.*/ ) 
		{
			#name got cut off, so indicate this
			$usbd_programmer = "Unknown Name (### issue)\n";
		}
		$user_basic_data_record{$usbd_name}->{programmer}    = $usbd_programmer;  #really just the user profile name
		$user_basic_data_record{$usbd_name}->{defgrp_id}     = $usbd_defgrp_id;
		$user_basic_data_record{$usbd_name}->{lastjob_time}  = $usbd_lastjob_time;
		$user_basic_data_record{$usbd_name}->{lastjob_date}  = $usbd_lastjob_date;
		$user_basic_data_record{$usbd_name}->{install_data}  = $usbd_install_data; #sometimes used for additional data like job title (ex. APPLICATIONS PROGRAMMER)
		$user_basic_data_record{$usbd_name}->{uaudit}        = $usbd_uaudit;
		$user_basic_data_record{$usbd_name}->{auditor}       = $usbd_auditor;
		$user_basic_data_record{$usbd_name}->{nopwd}         = $usbd_nopwd;
		$user_basic_data_record{$usbd_name}->{oidcard}       = $usbd_oidcard;
		$user_basic_data_record{$usbd_name}->{pwd_gen}       = $usbd_pwd_gen;
		$user_basic_data_record{$usbd_name}->{revoke_cnt}    = $usbd_revoke_cnt;
		$user_basic_data_record{$usbd_name}->{model}         = $usbd_model;
		$user_basic_data_record{$usbd_name}->{seclevel}      = $usbd_seclevel;
		$user_basic_data_record{$usbd_name}->{revoke_date}   = $usbd_revoke_date;
		$user_basic_data_record{$usbd_name}->{resume_date}   = $usbd_resume_date;
		$user_basic_data_record{$usbd_name}->{access_sun}    = $usbd_access_sun;
		$user_basic_data_record{$usbd_name}->{access_mon}    = $usbd_access_mon;
		$user_basic_data_record{$usbd_name}->{access_tue}    = $usbd_access_tue;
		$user_basic_data_record{$usbd_name}->{access_wed}    = $usbd_access_wed;
		$user_basic_data_record{$usbd_name}->{access_thu}    = $usbd_access_thu;
		$user_basic_data_record{$usbd_name}->{access_fri}    = $usbd_access_fri;
		$user_basic_data_record{$usbd_name}->{access_sat}    = $usbd_access_sat;
		$user_basic_data_record{$usbd_name}->{start_time}    = $usbd_start_time;
		$user_basic_data_record{$usbd_name}->{end_time}      = $usbd_end_time;
		$user_basic_data_record{$usbd_name}->{seclabel}      = $usbd_seclabel;
		$user_basic_data_record{$usbd_name}->{attribs}       = $usbd_attribs;
		$user_basic_data_record{$usbd_name}->{pwdenv_exists} = $usbd_pwdenv_exists;
		$user_basic_data_record{$usbd_name}->{pwd_asis}      = $usbd_pwd_asis;
		$user_basic_data_record{$usbd_name}->{phr_date}      = $usbd_phr_date;
		$user_basic_data_record{$usbd_name}->{cert_seqn}     = $usbd_cert_seqn;
		$user_basic_data_record{$usbd_name}->{pphenv_exists} = $usbd_pphenv_exists;		
	}
	elsif ( $rec_type eq "0201" )
	{
		#-----User categories record (0201)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0202" )
	{
		#-----User classes record (0202)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0203" )
	{
		#-----User group connections record-----
		my($usgcon_name)   = IAD::MiscFunc::trim( substr($line,5,8) );   #user id as taken from the profile name
		my($usgcon_grp_id) = IAD::MiscFunc::trim( substr($line,14,8) ); #the group with which the user is associated
		
		#store
		$user_group_connections_record{$usgcon_name}->{$usgcon_grp_id} = 1;
	}
	elsif ( $rec_type eq "0204" )
	{
		#-----User installation data record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0205" )
	{
		#-----User connect data record-----
		my($uscon_name)         = IAD::MiscFunc::trim( substr($line,5,8) );    #user id as taken from the profile name
		my($uscon_grp_id)       = IAD::MiscFunc::trim( substr($line,14,8) );   #the group name
		my($uscon_connect_date) = IAD::MiscFunc::trim( substr($line,23,10) );  #the date that the user was connected
		my($uscon_owner_id)     = IAD::MiscFunc::trim( substr($line,34,8) );   #the owner of the user-group connection
		my($uscon_lastcon_time) = IAD::MiscFunc::trim( substr($line,43,8) );   #time that the user last connected to this group
		my($uscon_lastcon_date) = IAD::MiscFunc::trim( substr($line,52,10) );  #date that the user last connected to this group
		my($uscon_uacc)         = IAD::MiscFunc::trim( substr($line,63,8) );   #the default universal access authority for all new resources the user defines while connected to the
																			   #specified group.  valid values are [NONE, READ, UPDATE, CONTROL, and ALTER]
		my($uscon_init_cnt)     = IAD::MiscFunc::trim( substr($line,72,5) );   #the number of RACINITs issued for this user/group combination
		my($uscon_grp_adsp)     = IAD::MiscFunc::trim( substr($line,78,4) );   #does this user have the ADSP attribute in this group (yes/no)?
		my($uscon_grp_special)  = IAD::MiscFunc::trim( substr($line,83,4) );   #does this user have GROUP-SPECIAL in this group (yes/no)?
		my($uscon_grp_oper)     = IAD::MiscFunc::trim( substr($line,88,4) );   #does this user have GROUP-OPERATIONS in this group (yes/no)?
		my($uscon_revoke)       = IAD::MiscFunc::trim( substr($line,93,4) );   #is this user revoked (yes/no)?
		my($uscon_grp_acc)      = IAD::MiscFunc::trim( substr($line,98,4) );   #does this user have the GRPACC attribute (yes/no)?
		my($uscon_notermuacc)   = IAD::MiscFunc::trim( substr($line,103,4) );  #does this user have the NOTERMUACC attribute in this group (yes/no)?
		my($uscon_grp_audit)    = IAD::MiscFunc::trim( substr($line,108,4) );  #does this user have the GROUP-AUDITOR attribute in this group (yes/no)?
		
		#revoke date - data inconsistencies
		eval( my($uscon_revoke_date) = substr($line,113,10) );   #the date the user's connection to the group will be revoked
		if ($uscon_revoke_date) { $uscon_revoke_date = IAD::MiscFunc::trim($uscon_revoke_date); }
		
		#resume date - data inconsistencies
		eval( my($uscon_resume_date) = substr($line,124,10) );   #the date the user's connection to the group will be resumed
		if ($uscon_resume_date) { $uscon_resume_date = IAD::MiscFunc::trim($uscon_resume_date); }
		
		#store
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{connect_date} = $uscon_connect_date;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{owner_id}     = $uscon_owner_id;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{lastcon_time} = $uscon_lastcon_time;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{lastcon_date} = $uscon_lastcon_date;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{uacc}         = $uscon_uacc;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{init_cnt}     = $uscon_init_cnt;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{grp_adsp}     = $uscon_grp_adsp;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{grp_special}  = $uscon_grp_special;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{grp_oper}     = $uscon_grp_oper;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{revoke}       = $uscon_revoke;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{grp_acc}      = $uscon_grp_acc;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{notermuacc}   = $uscon_notermuacc;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{grp_audit}    = $uscon_grp_audit;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{revoke_date}  = $uscon_revoke_date;
		$user_connect_data_record{$uscon_name}->{$uscon_grp_id}->{resume_date}  = $uscon_resume_date;
	}
	elsif ( $rec_type eq "0206" )
	{
		#-----User RRSF data record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0207" )
	{
		#-----User certificate name record-----
		my($uscert_name)      = IAD::MiscFunc::trim( substr($line,5,8) );    #user id as taken from the profile name
		my($uscert_cert_name) = IAD::MiscFunc::trim( substr($line,14,246) ); #digital certificate name
		my($uscert_certlabl)  = IAD::MiscFunc::trim( substr($line,261,32) ); #digital certificate label
		
		#store
		$user_certificate_name_record{$uscert_name}->{$uscert_cert_name}->{label} = $uscert_certlabl;
	}
	elsif ( $rec_type eq "0208" )
	{
		#-----User associated mappings record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0210" )
	{
		#-----User DFP data record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0220" )
	{
		#-----User TSO data record-----
		my($ustso_name)         = IAD::MiscFunc::trim( substr($line,5,8) );    #user id as taken from the profile name
		my($ustso_account)      = IAD::MiscFunc::trim( substr($line,14,40) );  #the default account number
		my($ustso_command)      = IAD::MiscFunc::trim( substr($line,55,80) );  #the command issued at logon
		my($ustso_dest)         = IAD::MiscFunc::trim( substr($line,136,8) );  #the default destination identifier
		my($ustso_hold_class)   = IAD::MiscFunc::trim( substr($line,145,1) );  #the default hold class
		my($ustso_job_class)    = IAD::MiscFunc::trim( substr($line,147,1) );  #the default job class
		my($ustso_logon_proc)   = IAD::MiscFunc::trim( substr($line,149,8) );  #the default logon procedure
		my($ustso_logon_size)   = IAD::MiscFunc::trim( substr($line,158,10) ); #the default logon region size
		my($ustso_msg_class)    = IAD::MiscFunc::trim( substr($line,169,1) );  #the default message class
		my($ustso_logon_max)    = IAD::MiscFunc::trim( substr($line,171,10) ); #the maximum logon region size
		my($ustso_perf_group)   = IAD::MiscFunc::trim( substr($line,182,10) ); #the performance group associated with the user
		my($ustso_sysout_class) = IAD::MiscFunc::trim( substr($line,193,1) );  #the default sysout class
		my($ustso_user_data)    = IAD::MiscFunc::trim( substr($line,195,8) );  #the tso user data, in hexadecimal in the form x<cccc>
		
		#unit name - data inconsistencies
		eval( my($ustso_unit_name) = substr($line,204,8) );   #the default SYSDA device
		if ($ustso_unit_name) { $ustso_unit_name = IAD::MiscFunc::trim($ustso_unit_name); }
		
		#seclabel - data inconsistencies
		eval( my($ustso_seclabel) = substr($line,213,8) );    #the default logon security label
		if ($ustso_seclabel) { $ustso_seclabel = IAD::MiscFunc::trim($ustso_seclabel); }
		
		#store
		$user_tso_data_record{$ustso_name}->{account}      = $ustso_account;
		$user_tso_data_record{$ustso_name}->{command}      = $ustso_command;
		$user_tso_data_record{$ustso_name}->{dest}         = $ustso_dest;
		$user_tso_data_record{$ustso_name}->{hold_class}   = $ustso_hold_class;
		$user_tso_data_record{$ustso_name}->{job_class}    = $ustso_job_class;
		$user_tso_data_record{$ustso_name}->{logon_proc}   = $ustso_logon_proc;
		$user_tso_data_record{$ustso_name}->{logon_size}   = $ustso_logon_size;
		$user_tso_data_record{$ustso_name}->{msg_class}    = $ustso_msg_class;
		$user_tso_data_record{$ustso_name}->{logon_max}    = $ustso_logon_max;
		$user_tso_data_record{$ustso_name}->{perf_group}   = $ustso_perf_group;
		$user_tso_data_record{$ustso_name}->{sysout_class} = $ustso_sysout_class;
		$user_tso_data_record{$ustso_name}->{user_data}    = $ustso_user_data;
		$user_tso_data_record{$ustso_name}->{unit_name}    = $ustso_unit_name;
		$user_tso_data_record{$ustso_name}->{seclabel}     = $ustso_seclabel;
	}
	elsif ( $rec_type eq "0230" )
	{
		#-----User CICS data record-----
		my($uscics_name)    = IAD::MiscFunc::trim( substr($line,5,8) );    #user id as taken from the profile name
		my($uscics_opident) = IAD::MiscFunc::trim( substr($line,14,3) );   #the cics operator identifier
		my($uscics_opprty)  = IAD::MiscFunc::trim( substr($line,18,5) );   #the cics operator priority
		my($uscics_noforce) = IAD::MiscFunc::trim( substr($line,24,4) );   #is the extended recovery facility (XRF) NOFORCE option in effect (yes/no)?
		my($uscics_timeout) = IAD::MiscFunc::trim( substr($line,29,5) );   #the terminal time-out value, expressed as hh:mm
				
		#store
		$user_cics_data_record{$uscics_name}->{opident} = $uscics_opident;
		$user_cics_data_record{$uscics_name}->{opprty} = $uscics_opprty;
		$user_cics_data_record{$uscics_name}->{noforce} = $uscics_noforce;
		$user_cics_data_record{$uscics_name}->{timeout} = $uscics_timeout;
	}
	elsif ( $rec_type eq "0231" )
	{
		#-----User CICS operator classes record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0232" )
	{
		#-----User CICS RSL keys record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0233" )
	{
		#-----User CICS TSL keys record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0240" )
	{
		#-----User language data record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0250" )
	{
		#-----User OPERPARM data record-----
		my($usopr_name)      			= IAD::MiscFunc::trim( substr($line,5,8) );    #user id as taken from the profile name
		my($usopr_storage)    			= IAD::MiscFunc::trim( substr($line,14,5) );   #number of megbytes of storage that can be used for message queueing
		my($usopr_masterauth)			= IAD::MiscFunc::trim( substr($line,20,4) );   #does this user have MASTER console authority (yes/no)?
		my($usopr_allauth)   			= IAD::MiscFunc::trim( substr($line,25,4) );   #does this user have ALL console authority (yes/no)?
		my($usopr_sysauth)   			= IAD::MiscFunc::trim( substr($line,30,4) );   #does this user have SYSAUTH console authority (yes/no)?
		my($usopr_ioauth)    			= IAD::MiscFunc::trim( substr($line,35,4) );   #does this user have IO console authority (yes/no)?
		my($usopr_consauth)  			= IAD::MiscFunc::trim( substr($line,40,4) );   #does this user have CONS console authority (yes/no)?
		my($usopr_infoauth)  			= IAD::MiscFunc::trim( substr($line,45,4) );   #does this user have INFO console authority (yes/no)?
		my($usopr_timestamp) 			= IAD::MiscFunc::trim( substr($line,50,4) );   #do console messages contain a timestamp (yes/no)?
		my($usopr_systemid)   			= IAD::MiscFunc::trim( substr($line,55,4) );   #do console messages contain a system ID (yes/no)?
		my($usopr_jobid)      			= IAD::MiscFunc::trim( substr($line,60,4) );   #do console messages contain a job ID (yes/no)?
		my($usopr_msgid)     			= IAD::MiscFunc::trim( substr($line,65,4) );   #do console messages contain a message ID (yes/no)?
		my($usopr_x)        			= IAD::MiscFunc::trim( substr($line,70,4) );   #are the job name and systems name to be suppressed for messages issued from the JES3 global processor (yes/no)?
		my($usopr_wtor)       			= IAD::MiscFunc::trim( substr($line,75,4) );   #does the console receive WTOR messages (yes/no)?
		my($usopr_immediate)  			= IAD::MiscFunc::trim( substr($line,80,4) );   #does the console receive immediate messages (yes/no)?
		my($usopr_critical)   			= IAD::MiscFunc::trim( substr($line,85,4) );   #does the console receive critical event messages (yes/no)?
		my($usopr_eventual)   			= IAD::MiscFunc::trim( substr($line,90,4) );   #does the console receive eventual event messages (yes/no)?
		my($usopr_info)       			= IAD::MiscFunc::trim( substr($line,95,4) );   #does the console receive informational messages (yes/no)?
		my($usopr_nobrodcast) 			= IAD::MiscFunc::trim( substr($line,100,4) );  #are broadcast messages to this console suppressed (yes/no)?
		my($usopr_all)        			= IAD::MiscFunc::trim( substr($line,105,4) );  #does the console receive all messages (yes/no)?
		my($usopr_jobnames)  	        = IAD::MiscFunc::trim( substr($line,110,4) );  #are job names monitored?
		my($usopr_jobnamest)  			= IAD::MiscFunc::trim( substr($line,115,4) );  #are job names monitored with timestamps displayed (yes/no)?
		my($usopr_sess)       			= IAD::MiscFunc::trim( substr($line,120,4) );  #are user IDs displayed with each TSO initiation and termination (yes/no)?
		my($usopr_sesst)      			= IAD::MiscFunc::trim( substr($line,125,4) );  #are user IDs and timestamps displayed with each TSO initiation and termination (yes/no)?
		my($usopr_status)     			= IAD::MiscFunc::trim( substr($line,130,4) );  #are data set names and dispositions displayed with each data set that is freed?
		my($usopr_routecode_001_to_128) = IAD::MiscFunc::trim( substr($line,135,639) );#is console enable for route code 001 to 128 [long string - split on /\s+/ for each individual rc]
		my($usopr_logcmdresp)     		= IAD::MiscFunc::trim( substr($line,775,8) );  #specifies the logging of command responses received by the extended operator...values are
																					   #[SYSTEM, NO and BLANK]
		my($usopr_migrationid)     		= IAD::MiscFunc::trim( substr($line,784,4) );  #is the extended operator to receive a migration ID (yes/no)?
		my($usopr_delopermsg)     		= IAD::MiscFunc::trim( substr($line,789,8) );  #does this extended operator receive delete operator messages? values are:
																					   #[NORMAL, ALL and NONE]
		my($usopr_retrieve_key)         = IAD::MiscFunc::trim( substr($line,798,8) );  #specifies a retrieval key used for searching...a null value is indicated by NONE
		my($usopr_cmdsys)               = IAD::MiscFunc::trim( substr($line,807,8) );  #the name of the system that the extended operator is connect to for command processing
		my($usopr_ud)                   = IAD::MiscFunc::trim( substr($line,816,4) );  #is this operator to receive undeliverable messages (yes/no)?
		my($usopr_altgrp_id)            = IAD::MiscFunc::trim( substr($line,821,8) );  #the default group associated with this operator
		my($usopr_auto)                 = IAD::MiscFunc::trim( substr($line,830,4) );  #is this operator to receive messages automated within the sysplex (yes/no)?
		my($usopr_hc)                   = IAD::MiscFunc::trim( substr($line,835,4) );  #is this operator to receive messages that are directed to hard copy (yes/no)?
		my($usopr_int)                  = IAD::MiscFunc::trim( substr($line,840,4) );  #is this operator to receive messages that are directed to console ID zero (yes/no)?
		my($usopr_unkn)                 = IAD::MiscFunc::trim( substr($line,845,4) );  #is this operator to receive messages that are directed to unknown console IDs (yes/no)?
		
		#store
		$user_operparm_data_record{$usopr_name}->{storage}    = $usopr_storage;
		$user_operparm_data_record{$usopr_name}->{masterauth} = $usopr_masterauth;
		$user_operparm_data_record{$usopr_name}->{allauth}    = $usopr_allauth;
		$user_operparm_data_record{$usopr_name}->{sysauth}    = $usopr_sysauth;
		$user_operparm_data_record{$usopr_name}->{ioauth}     = $usopr_ioauth;
		$user_operparm_data_record{$usopr_name}->{consauth}   = $usopr_consauth;
		$user_operparm_data_record{$usopr_name}->{infoauth}   = $usopr_infoauth;
		$user_operparm_data_record{$usopr_name}->{timestamp}  = $usopr_timestamp;
		$user_operparm_data_record{$usopr_name}->{systemid}   = $usopr_systemid;
		$user_operparm_data_record{$usopr_name}->{jobid}      = $usopr_jobid;
		$user_operparm_data_record{$usopr_name}->{msgid}      = $usopr_msgid;
		$user_operparm_data_record{$usopr_name}->{x}          = $usopr_x;
		$user_operparm_data_record{$usopr_name}->{wtor}       = $usopr_wtor;
		$user_operparm_data_record{$usopr_name}->{immediate}  = $usopr_immediate;
		$user_operparm_data_record{$usopr_name}->{critical}   = $usopr_critical;
		$user_operparm_data_record{$usopr_name}->{eventual}   = $usopr_eventual;
		$user_operparm_data_record{$usopr_name}->{info}       = $usopr_info;
		$user_operparm_data_record{$usopr_name}->{nobrodcast} = $usopr_nobrodcast;
		$user_operparm_data_record{$usopr_name}->{all}        = $usopr_all;
		$user_operparm_data_record{$usopr_name}->{jobnames}   = $usopr_jobnames;
		$user_operparm_data_record{$usopr_name}->{jobnamest}  = $usopr_jobnamest;
		$user_operparm_data_record{$usopr_name}->{sess}       = $usopr_sess;
		$user_operparm_data_record{$usopr_name}->{sesst}      = $usopr_sesst;
		$user_operparm_data_record{$usopr_name}->{status}     = $usopr_status;
		$user_operparm_data_record{$usopr_name}->{routecode_001_to_128} = $usopr_routecode_001_to_128;
		$user_operparm_data_record{$usopr_name}->{logcmdresp}   = $usopr_logcmdresp;
		$user_operparm_data_record{$usopr_name}->{migrationid}  = $usopr_migrationid;
		$user_operparm_data_record{$usopr_name}->{delopermsg}   = $usopr_delopermsg;
		$user_operparm_data_record{$usopr_name}->{retrieve_key} = $usopr_retrieve_key;
		$user_operparm_data_record{$usopr_name}->{cmdsys}       = $usopr_cmdsys;
		$user_operparm_data_record{$usopr_name}->{ud}           = $usopr_ud;
		$user_operparm_data_record{$usopr_name}->{altgrp_id}    = $usopr_altgrp_id;
		$user_operparm_data_record{$usopr_name}->{auto}         = $usopr_auto;
		$user_operparm_data_record{$usopr_name}->{hc}           = $usopr_hc;
		$user_operparm_data_record{$usopr_name}->{int}          = $usopr_int;
		$user_operparm_data_record{$usopr_name}->{unkn}         = $usopr_unkn;
	}
	elsif ( $rec_type eq "0251" )
	{
		#-----User OPERPARM scope-----
		my($usopr_name)   = IAD::MiscFunc::trim( substr($line,5,8) );    #user id as taken from the profile name
		my($usopr_system) = IAD::MiscFunc::trim( substr($line,14,8) );   #system name
		
		#store 
		$user_operparm_scope{$usopr_name}->{$usopr_system} = 1;
	}
	elsif ( $rec_type eq "0260" )
	{
		#-----User WORKATTR data record-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0270" )
	{
		#-----User OMVS data record-----
		my($usomvs_name) = IAD::MiscFunc::trim( substr($line,5,8) ); #user id as taken from the profile name
		
		#uid - data inconsistencies
		eval( my($usomvs_uid) = substr($line,14,10) );
		if ($usomvs_uid) { $usomvs_uid = IAD::MiscFunc::trim($usomvs_uid); }
				
		#home path - data inconsistencies
		eval( my($usomvs_home_path) = substr($line,25,1023) );
		if ($usomvs_home_path) { $usomvs_home_path = IAD::MiscFunc::trim($usomvs_home_path); }
		
		#program - data inconsistencies
		eval( my($usomvs_program) = substr($line,1049,1023) );
		if ($usomvs_program) { $usomvs_program = IAD::MiscFunc::trim($usomvs_program); }
		
		#max cpu time - data inconsistencies
		eval( my($usomvs_cputimemax) = substr($line,2073,10) );            #maximum CPU time associated with the UID
		if ($usomvs_cputimemax) { $usomvs_cputimemax = IAD::MiscFunc::trim($usomvs_cputimemax); }
		
		#max addr space - data inconsistencies
		eval( my($usomvs_assizemax) = substr($line,2084,10) );             #maximum address space size associated with UID
		if ($usomvs_assizemax) { $usomvs_assizemax = IAD::MiscFunc::trim($usomvs_assizemax); }
		
		#max active or open files - data inconsistencies
		eval( my($usomvs_fileprocmax) = substr($line,2095,10) );           #maximum active or open files associated with UID
		if ($usomvs_fileprocmax) { $usomvs_fileprocmax = IAD::MiscFunc::trim($usomvs_fileprocmax); }
		
		#max number of processors - data inconsistencies
		eval( my($usomvs_procusermax) = substr($line,2106,10) );           #maximum number of processors associated with the UID         
		if ($usomvs_procusermax) { $usomvs_procusermax = IAD::MiscFunc::trim($usomvs_procusermax); }
		
		#max number of threads - data inconsistencies
		eval( my($usomvs_threadsmax) = substr($line,2117,10) );            #maximum number of threads associated with the UID
		if ($usomvs_threadsmax) { $usomvs_threadsmax = IAD::MiscFunc::trim($usomvs_threadsmax); }
		
		#max mappable storage - data inconsistencies
		eval( my($usomvs_mmapareamax) = substr($line,2128,10) );           #maximum mappable storage amount associated with the UID
		if ($usomvs_mmapareamax) { $usomvs_mmapareamax = IAD::MiscFunc::trim($usomvs_mmapareamax); }
		
		#max non-shared memory - data inconsistencies
		eval( my($usomvs_memlimit) = substr($line,2139,9) );               #maximum size of non-shared memory
		if ($usomvs_memlimit) { $usomvs_memlimit = IAD::MiscFunc::trim($usomvs_memlimit); }
		
		#max shared memory - data inconsistencies
		eval( my($usomvs_shmemax) = substr($line,2149,9) );               #maximum size ofshared memory
		if ($usomvs_shmemax) { $usomvs_shmemax = IAD::MiscFunc::trim($usomvs_shmemax); }
		
		#store
		$user_omvs_data_record{$usomvs_name}->{uid}         = $usomvs_uid;
		$user_omvs_data_record{$usomvs_name}->{home_path}   = $usomvs_home_path;
		$user_omvs_data_record{$usomvs_name}->{program}     = $usomvs_program;
		$user_omvs_data_record{$usomvs_name}->{cputimemax}  = $usomvs_cputimemax;
		$user_omvs_data_record{$usomvs_name}->{assizemax}   = $usomvs_assizemax;
		$user_omvs_data_record{$usomvs_name}->{fileprocmax} = $usomvs_fileprocmax;
		$user_omvs_data_record{$usomvs_name}->{procusermax} = $usomvs_procusermax;
		$user_omvs_data_record{$usomvs_name}->{threadsmax}  = $usomvs_threadsmax;
		$user_omvs_data_record{$usomvs_name}->{mmapareamax} = $usomvs_mmapareamax;
		$user_omvs_data_record{$usomvs_name}->{memlimit}    = $usomvs_memlimit;
		$user_omvs_data_record{$usomvs_name}->{shmemax}     = $usomvs_shmemax;		
	}
	elsif ( $rec_type eq "0280" )
	{
		#-----User NETVIEW segment record-----
		my($usnetv_name)     = IAD::MiscFunc::trim( substr($line,5,8) );    #user id as taken from the profile name
		my($usnetv_ic)       = IAD::MiscFunc::trim( substr($line,14,255) ); #command list processed at logon
		my($usnetv_consname) = IAD::MiscFunc::trim( substr($line,270,8) );  #default console name
		my($usnetv_ctl)      = IAD::MiscFunc::trim( substr($line,279,8) );  #ctl value: GENERAL, GLOBAL, or SPECIFIC
		my($usnetv_msgrecvr) = IAD::MiscFunc::trim( substr($line,288,4) );  #eligible to receive unsolicited messages (yes/no)?
		my($usnetv_mgmfadmn) = IAD::MiscFunc::trim( substr($line,293,4) );  #authoirzed to netview graphic monitoring facility (yes/no)?
		
		#view span options - data inconsistencies
		eval( my($usnetv_ngmfvspn) = substr($line,298,8) );                 #value of view span options
		if ($usnetv_ngmfvspn) { $usnetv_ngmfvspn = IAD::MiscFunc::trim($usnetv_ngmfvspn); }
		
		#store
		$user_netview_segment_record{$usnetv_name}->{ic}       = $usnetv_ic;
		$user_netview_segment_record{$usnetv_name}->{consname} = $usnetv_consname;
		$user_netview_segment_record{$usnetv_name}->{ctl}      = $usnetv_ctl;
		$user_netview_segment_record{$usnetv_name}->{msgrecvr} = $usnetv_msgrecvr;
		$user_netview_segment_record{$usnetv_name}->{mgmfadmn} = $usnetv_mgmfadmn;
		$user_netview_segment_record{$usnetv_name}->{ngmfvspn} = $usnetv_ngmfvspn;
	}
	elsif ( $rec_type eq "0281" )
	{
		#-----User OPCLASS record (0281)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0282" )
	{
		#-----User domains record (0282)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0290" )
	{
		#-----User DCE data record (0290)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "02A0" )
	{
		#-----User OVM data record (02A0)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "02B0" )
	{
		#-----User LNOTES data record (02B0)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "02C0" )
	{
		#-----User NDS data record (02C0)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "02D0" )
	{
		#-----User KERB data record-----
		my($uskerb_name)         = IAD::MiscFunc::trim( substr($line,5,8) );     #user id as taken from the profile name
		my($uskerb_kerbname)     = IAD::MiscFunc::trim( substr($line,14,240) );  #the kerberos principal name
		my($uskerb_max_life)     = IAD::MiscFunc::trim( substr($line,255,10) );  #maximum ticket life
		my($uskerb_key_vers)     = IAD::MiscFunc::trim( substr($line,266,3) );   #current key version
		my($uskerb_encrypt_des)  = IAD::MiscFunc::trim( substr($line,270,4) );   #is key encryption using DES enbaled (yes/no)?
		my($uskerb_encrypt_des3) = IAD::MiscFunc::trim( substr($line,275,4) );   #is key encryption using DES3 enbaled (yes/no)?
		my($uskerb_encrypt_desd) = IAD::MiscFunc::trim( substr($line,280,4) );   #is key encryption using DES with derivation enbaled (yes/no)?
		
		#encrypt a128 - data inconsistencies
		eval( my($uskerb_encrypt_a128) = substr($line,285,4) );                  #is key encryption using AES128 enbaled (yes/no)?
		if ($uskerb_encrypt_a128) { $uskerb_encrypt_a128 = IAD::MiscFunc::trim($uskerb_encrypt_a128); }
		
		#encrypt a256 - data inconsistencies
		eval( my($uskerb_encrypt_a256) = substr($line,290,4) );                  #is key encryption using AES256 enbaled (yes/no)?
		if ($uskerb_encrypt_a256) { $uskerb_encrypt_a256 = IAD::MiscFunc::trim($uskerb_encrypt_a256); }
		
		#store 
		$user_kerb_data_record{$uskerb_name}->{kerbname}     = $uskerb_kerbname;
		$user_kerb_data_record{$uskerb_name}->{max_life}     = $uskerb_max_life;
		$user_kerb_data_record{$uskerb_name}->{key_vers}     = $uskerb_key_vers;
		$user_kerb_data_record{$uskerb_name}->{encrypt_des}  = $uskerb_encrypt_des;
		$user_kerb_data_record{$uskerb_name}->{encrypt_des3} = $uskerb_encrypt_des3;
		$user_kerb_data_record{$uskerb_name}->{encrypt_desd} = $uskerb_encrypt_desd;
		$user_kerb_data_record{$uskerb_name}->{encrypt_a128} = $uskerb_encrypt_a128;
		$user_kerb_data_record{$uskerb_name}->{encrypt_a256} = $uskerb_encrypt_a256;
	}
	elsif ( $rec_type eq "02E0" )
	{
		#-----User PROXY record (02E0)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "02F0" )
	{
		#-----User EIM data record (02F0)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "02C0" )
	{
		#-----User NDS data record (02C0)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0400" )
	{
		#-----Data set basic data record-----
		my($dsbd_name)         = IAD::MiscFunc::trim( substr($line,5,44) );    #data set name as taken from the profile name
		my($dsbd_vol)          = IAD::MiscFunc::trim( substr($line,50,6) );    #volume upon which this data set resides.  blank if profile is generic, and *MODEL if the profile is 
								   											   #a model profile
		my($dsbd_generic)      = IAD::MiscFunc::trim( substr($line,57,4) );    #is this a generic profile (yes/no)?
		my($dsbd_create_date)  = IAD::MiscFunc::trim( substr($line,62,10) );   #date the profile was created
		my($dsbd_owner_id)     = IAD::MiscFunc::trim( substr($line,73,8) );    #the user id or group name that owns the profile
		my($dsbd_lastref_date) = IAD::MiscFunc::trim( substr($line,82,10) );   #the date that the data set was last referenced
		my($dsbd_lastchg_date) = IAD::MiscFunc::trim( substr($line,93,10) );   #the date that the data set was last changed
		my($dsbd_alter_cnt)    = IAD::MiscFunc::trim( substr($line,104,5) );   #the number of times that the data set was accessed with ALTER authority
		my($dsbd_control_cnt)  = IAD::MiscFunc::trim( substr($line,110,5) );   #the number of times that the data set was accessed with CONTROL authority
		my($dsbd_update_cnt)   = IAD::MiscFunc::trim( substr($line,116,5) );   #the number of times that the data set was accessed with UPDATE authority
		my($dsbd_read_cnt)     = IAD::MiscFunc::trim( substr($line,122,5) );   #the number of times that the data set was accessed with READ authority
		my($dsbd_uacc)         = IAD::MiscFunc::trim( substr($line,128,8) );   #the universal access of this data set.  valid values are [NONE, EXECUTE, READ, UPDATE, CONTROL 
																			   #and ALTER]
		my($dsbd_grpds)        = IAD::MiscFunc::trim( substr($line,137,4) );   #is this a group data set (yes/no)?
		my($dsbd_audit_level)  = IAD::MiscFunc::trim( substr($line,142,8) );   #indicates the level of resource-owner-specified auditing that is performed.  valid valuse are [ALL, 
																			   #SUCCESS, FAIL, and NONE]
		my($dsbd_grp_id)       = IAD::MiscFunc::trim( substr($line,151,8) );   #the connect group of the user who created this data set
		my($dsbd_ds_type)      = IAD::MiscFunc::trim( substr($line,160,8) );   #the type of data set. valid values are [VSAM, NONVSAM, TAPE, MODEL]
		my($dsbd_level)        = IAD::MiscFunc::trim( substr($line,169,3) );   #the level of the data set
		my($dsbd_device_name)  = IAD::MiscFunc::trim( substr($line,173,8) );   #the EBCDIC name of the device type on which the data set resides
		my($dsbd_gaudit_level) = IAD::MiscFunc::trim( substr($line,182,8) );   #indicates the level of auditor-specified auditing that is performed.  valid values are [ALL, SUCCESS,
																			   #FAIL, and NONE]
		my($dsbd_install_data) = IAD::MiscFunc::trim( substr($line,191,255) ); #installation defined data - sometimes data set description, may be usable for parsing
		my($dsbd_audit_okqual) = IAD::MiscFunc::trim( substr($line,447,8) );   #the resource-owner-specified successful access audit qualifier.  this is set to blanks if AUDIT_LEVEL
																			   #is NONE.  Otherwise, it is set to either READ, UPDATE, CONTROL or ALTER.
		my($dsbd_audit_faqual) = IAD::MiscFunc::trim( substr($line,456,8) );   #the resource-owner-specified failing access audit qualifier.  this is set to blanks if AUDIT_LEVEL
																			   #is NONE.  Otherwise, it is set to either READ, UPDATE, CONTROL or ALTER.
		my($dsbd_warning)      = IAD::MiscFunc::trim( substr($line,483,4) );   #does this data set have the WARNING attribute (yes/no)?
		my($dsbd_seclevel)     = IAD::MiscFunc::trim( substr($line,488,3) );   #the data set security level 
		my($dsbd_notify_id)    = IAD::MiscFunc::trim( substr($line,492,8) );   #user id that is notified when violations occur
		my($dsbd_retention)    = IAD::MiscFunc::trim( substr($line,501,5) );   #retention period of the data set
		my($dsbd_erase)        = IAD::MiscFunc::trim( substr($line,507,4) );   #for a dasd data set, is this data set scratched when the data set is deleted (yes/no)?
		
		#seclabel - data inconsistencies
		eval( my($dsbd_seclabel) = substr($line,512,8) );                      #security label of the data set
		if ($dsbd_seclabel) { $dsbd_seclabel = IAD::MiscFunc::trim($dsbd_seclabel); }
		
		if ($dsbd_name eq "SYS1.RACF" || $dsbd_name eq "SYS1.RACFSEC")
		{
			print "$dsbd_name -> $dsbd_uacc\n";
		}
		
		#store
		$data_set_basic_data_record{$dsbd_name}->{vol}          = $dsbd_vol;
		$data_set_basic_data_record{$dsbd_name}->{generic}      = $dsbd_generic;
		$data_set_basic_data_record{$dsbd_name}->{create_date}  = $dsbd_create_date;
		$data_set_basic_data_record{$dsbd_name}->{owner_id}     = $dsbd_owner_id;
		$data_set_basic_data_record{$dsbd_name}->{lastref_date} = $dsbd_lastref_date;
		$data_set_basic_data_record{$dsbd_name}->{lastchg_date} = $dsbd_lastchg_date;
		$data_set_basic_data_record{$dsbd_name}->{alter_cnt}    = $dsbd_alter_cnt;
		$data_set_basic_data_record{$dsbd_name}->{control_cnt}  = $dsbd_control_cnt;
		$data_set_basic_data_record{$dsbd_name}->{update_cnt}   = $dsbd_update_cnt;	
		$data_set_basic_data_record{$dsbd_name}->{read_cnt}     = $dsbd_read_cnt;	
		$data_set_basic_data_record{$dsbd_name}->{uacc}         = $dsbd_uacc;	
		$data_set_basic_data_record{$dsbd_name}->{grpds}        = $dsbd_grpds;	
		$data_set_basic_data_record{$dsbd_name}->{audit_level}  = $dsbd_audit_level;	
		$data_set_basic_data_record{$dsbd_name}->{grp_id}       = $dsbd_grp_id;	
		$data_set_basic_data_record{$dsbd_name}->{ds_type}      = $dsbd_ds_type;	
		$data_set_basic_data_record{$dsbd_name}->{level}        = $dsbd_level;	
		$data_set_basic_data_record{$dsbd_name}->{device_name}  = $dsbd_device_name;	
		$data_set_basic_data_record{$dsbd_name}->{gaudit_level} = $dsbd_gaudit_level;	
		$data_set_basic_data_record{$dsbd_name}->{install_data} = $dsbd_install_data;	
		$data_set_basic_data_record{$dsbd_name}->{audit_okqual} = $dsbd_audit_okqual;	
		$data_set_basic_data_record{$dsbd_name}->{audit_faqual} = $dsbd_audit_faqual;		
		$data_set_basic_data_record{$dsbd_name}->{warning}      = $dsbd_warning;	
		$data_set_basic_data_record{$dsbd_name}->{seclevel}     = $dsbd_seclevel;	
		$data_set_basic_data_record{$dsbd_name}->{notify_id}    = $dsbd_notify_id;	
		$data_set_basic_data_record{$dsbd_name}->{retention}    = $dsbd_retention;	
		$data_set_basic_data_record{$dsbd_name}->{erase}        = $dsbd_erase;	
		$data_set_basic_data_record{$dsbd_name}->{seclabel}     = $dsbd_seclabel;	
	}
	elsif ( $rec_type eq "0401" )
	{
		#-----Data set categories record (0401)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0402" )
	{
		#-----Data set conditional access record (0402)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0403" )
	{
		#-----Data set volumes record (0403)-----
		my($dsvol_name)     = IAD::MiscFunc::trim( substr($line,5,44) );    #data set name as taken from the profile name
		my($dsvol_vol)      = IAD::MiscFunc::trim( substr($line,50,6) );    #volume upon which this data set resides
		my($dsvol_vol_name) = IAD::MiscFunc::trim( substr($line,57,6) );    #a volume upon which the data set resides
		
		#store 
		$data_set_volumes_record{$dsvol_name}->{$dsvol_vol}->{vol_name} = $dsvol_vol_name;
	}
	elsif ( $rec_type eq "0404" )
	{
		#-----Data set access record (0404)-----
		my($dsacc_name)       = IAD::MiscFunc::trim( substr($line,5,44) );  #data set name as taken from the profile name
		my($dsacc_vol)        = IAD::MiscFunc::trim( substr($line,50,6) );  #volume upon which this data set resides. blank if the profile is generic, and *MODEL if the profile is a 
								    										#model profile
		my($dsacc_auth_id)    = IAD::MiscFunc::trim( substr($line,57,8) );  #the user id or group name that is authorized to the data set
		my($dsacc_access)     = IAD::MiscFunc::trim( substr($line,66,8) );  #the access allowed to the user.  valid values are NONE, EXECUTE, READ, UPDATE, CONTROL, and ALTER
		my($dsacc_access_cnt) = IAD::MiscFunc::trim( substr($line,75,5) );  #the number of times that the data set was accessed
		
		if ($dsacc_name eq "SYS1.RACF" || $dsacc_name eq "SYS1.RACFSEC")
		{
			print "$dsacc_name -> $dsacc_auth_id: $dsacc_access\n";
		}
		
		#store 
		$data_set_access_record{$dsacc_name}->{$dsacc_auth_id}->{vol}        = $dsacc_vol;
		$data_set_access_record{$dsacc_name}->{$dsacc_auth_id}->{access}     = $dsacc_access;
		$data_set_access_record{$dsacc_name}->{$dsacc_auth_id}->{access_cnt} = $dsacc_access_cnt;
	}
	elsif ( $rec_type eq "0405" )
	{
		#-----Data set installation data record (0405)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0410" )
	{
		#-----Data set DFP data record (0410)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0421" )
	{
		#-----Data set TIME role record (0421)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0500" )
	{
		#-----General resource basic data record (0500)-----
		my($grbd_name)          = IAD::MiscFunc::trim( substr($line,5,246) );  #general resource name as taken from the profile name
		my($grbd_class_name)    = IAD::MiscFunc::trim( substr($line,252,8) );  #name of the class to which the genral resource profile belongs
		my($grbd_generic)       = IAD::MiscFunc::trim( substr($line,261,4) );  #is this a generic profile (yes/no)?
		my($grbd_class)         = IAD::MiscFunc::trim( substr($line,266,3) );  #the class number of the profile
		my($grbd_create_date)   = IAD::MiscFunc::trim( substr($line,270,10) ); #date the profile was created
		my($grbd_owner_id)      = IAD::MiscFunc::trim( substr($line,281,8) );  #the user id or group name which owns the profile
		my($grbd_lastref_date)  = IAD::MiscFunc::trim( substr($line,290,10) ); #the date that the resource was last referenced
		my($grbd_lastchg_date)  = IAD::MiscFunc::trim( substr($line,301,10) ); #the date that the resource was last changed
		my($grbd_alter_cnt)     = IAD::MiscFunc::trim( substr($line,312,5) );  #the number of times that the resource was accessed with ALTER authority
		my($grbd_control_cnt)   = IAD::MiscFunc::trim( substr($line,318,5) );  #the number of times that the resource was accessed with CONTROL authority
		my($grbd_update_cnt)    = IAD::MiscFunc::trim( substr($line,324,5) );  #the number of times that the resource was accessed with UPDATE authority
		my($grbd_read_cnt)      = IAD::MiscFunc::trim( substr($line,330,5) );  #the number of times that the resource was accessed with READ authority
		my($grbd_uacc)          = IAD::MiscFunc::trim( substr($line,330,5) );  #the universal access of this resource.  for profiles in classes other than DIGTCERT, the valid values
								 											   #are: [NONE, READ, EXECUTE, UPDATE, CONTROL, and ALTER].  For DIGTCERT profiles, the valid
																			   #values are: [TRUST, NOTRUST, and HIGHTRST].
		my($grbd_audit_level)   = IAD::MiscFunc::trim( substr($line,345,8) );  #indicates the level of resource-owner-specified auditing that is performed.  valid values are: [ALL, 
																			   #SUCCESS, FAIL and NONE].
		my($grbd_level)         = IAD::MiscFunc::trim( substr($line,354,3) );  #the level of the resource
		my($grbd_gaudit_level)  = IAD::MiscFunc::trim( substr($line,358,8) );  #indicates the level of auditor-specified auditing that is performed.  valid values are: [ALL, SUCCESS,
																			   #FAIL, and NONE].
		my($grbd_install_data)  = IAD::MiscFunc::trim( substr($line,367,255) );#installation-defined data
		my($grbd_audit_okqual)  = IAD::MiscFunc::trim( substr($line,623,8) );  #the resource-owner-specified successful access audit qualifier.  this is set to blanks if AUDIT_LEVEL
								 											   #is NONE.  Otherwise, it is set to either READ, UPDATE, CONTROL, or ALTER
		my($grbd_audit_faqual)  = IAD::MiscFunc::trim( substr($line,632,8) );  #the resource-owner-specified failing access audit qualifier.  this is set to blanks if AUDIT_LEVEL
								  											   #is NONE.  Otherwise, it is set to either READ, UPDATE, CONTROL, or ALTER
		my($grbd_gaudit_okqual) = IAD::MiscFunc::trim( substr($line,641,8) );  #the auditor-specified successful access audit qualifier.  this is set to blanks if AUDIT_LEVEL
																			   #is NONE.  Otherwise, it is set to either READ, UPDATE, CONTROL, or ALTER
		my($grbd_gaudit_faqual) = IAD::MiscFunc::trim( substr($line,650,8) );  #the auditor-specified failing access audit qualifier.  this is set to blanks if AUDIT_LEVEL
																			   #is NONE.  Otherwise, it is set to either READ, UPDATE, CONTROL, or ALTER
		my($grbd_warning)       = IAD::MiscFunc::trim( substr($line,659,4) );  #does this resource have the WARNING attribute (yes/no)?
		my($grbd_singleds)      = IAD::MiscFunc::trim( substr($line,664,4) );  #if this is a TAPEVOL profile, is there only one data set on this tape (yes/no)?
		my($grbd_auto)          = IAD::MiscFunc::trim( substr($line,669,4) );  #if this is a TAPEVOL profile, is the TAPEVOL protection automatic (yes/no)?
		my($grbd_tvtoc)         = IAD::MiscFunc::trim( substr($line,674,4) );  #if this is a TAPEVOL profile, is there a tape volume table of contents on this taps (yes/no)?
		my($grbd_notify_id)     = IAD::MiscFunc::trim( substr($line,679,8) );  #user id that is notified when voilations occur
		my($grbd_access_sun)    = IAD::MiscFunc::trim( substr($line,688,4) );  #can the terminal be used on sunday (yes/no)?
		my($grbd_access_mon)    = IAD::MiscFunc::trim( substr($line,693,4) );  #can the terminal be used on monday (yes/no)?
		my($grbd_access_tue)    = IAD::MiscFunc::trim( substr($line,698,4) );  #can the terminal be used on tuesday (yes/no)?
		my($grbd_access_wed)    = IAD::MiscFunc::trim( substr($line,703,4) );  #can the terminal be used on wednesday (yes/no)?
		my($grbd_access_thu)    = IAD::MiscFunc::trim( substr($line,708,4) );  #can the terminal be used on thursday (yes/no)?
		my($grbd_access_fri)    = IAD::MiscFunc::trim( substr($line,713,4) );  #can the terminal be used on friday (yes/no)?
		my($grbd_access_sat)    = IAD::MiscFunc::trim( substr($line,718,4) );  #can the terminal be used on saturday (yes/no)?
		my($grbd_start_time)    = IAD::MiscFunc::trim( substr($line,723,8) );  #after what time can a user logon from this terminal?
		my($grbd_end_time)      = IAD::MiscFunc::trim( substr($line,732,8) );  #after what time can a user not logon from this terminal?
		my($grbd_zone_offset)   = IAD::MiscFunc::trim( substr($line,741,7) );  #the time zone in which the terminal is located.  expressed as hh:mm.  blank if time zone not specified
		my($grbd_zone_direct)   = IAD::MiscFunc::trim( substr($line,747,1) );  #the direction of the time zone shift.  valid values are: [E (east), W (west), and blank]
		my($grbd_seclevel)      = IAD::MiscFunc::trim( substr($line,749,3) );  #the security level of the general resource
		
		#appl data - data inconsistencies
		eval( my($grbd_appl_data) = substr($line,753,255) );                   #installtion-defined data
		if ($grbd_appl_data) { $grbd_appl_data = IAD::MiscFunc::trim($grbd_appl_data); }
		
		#seclabel - data inconsistencies
		eval( my($grbd_seclabel) = substr($line,1009,8) );                     #the security label of the general resource
		if ($grbd_seclabel) { $grbd_seclabel = IAD::MiscFunc::trim($grbd_seclabel); }
		
		#store
		$general_resource_basic_data_record{$grbd_name}->{class_name}    = $grbd_class_name;
		$general_resource_basic_data_record{$grbd_name}->{generic}       = $grbd_generic;
		$general_resource_basic_data_record{$grbd_name}->{class}         = $grbd_class;
		$general_resource_basic_data_record{$grbd_name}->{create_date}   = $grbd_create_date;
		$general_resource_basic_data_record{$grbd_name}->{owner_id}      = $grbd_owner_id;
		$general_resource_basic_data_record{$grbd_name}->{lastref_date}  = $grbd_lastref_date;
		$general_resource_basic_data_record{$grbd_name}->{lastchg_date}  = $grbd_lastchg_date;
		$general_resource_basic_data_record{$grbd_name}->{alter_cnt}     = $grbd_alter_cnt;
		$general_resource_basic_data_record{$grbd_name}->{control_cnt}   = $grbd_control_cnt;
		$general_resource_basic_data_record{$grbd_name}->{update_cnt}    = $grbd_update_cnt;
		$general_resource_basic_data_record{$grbd_name}->{read_cnt}      = $grbd_read_cnt;
		$general_resource_basic_data_record{$grbd_name}->{uacc}          = $grbd_uacc;
		$general_resource_basic_data_record{$grbd_name}->{audit_level}   = $grbd_audit_level;
		$general_resource_basic_data_record{$grbd_name}->{level}         = $grbd_level;
		$general_resource_basic_data_record{$grbd_name}->{gaudit_level}  = $grbd_gaudit_level;
		$general_resource_basic_data_record{$grbd_name}->{install_data}  = $grbd_install_data;
		$general_resource_basic_data_record{$grbd_name}->{audit_okqual}  = $grbd_audit_okqual;
		$general_resource_basic_data_record{$grbd_name}->{audit_faqual}  = $grbd_audit_faqual;
		$general_resource_basic_data_record{$grbd_name}->{gaudit_okqual} = $grbd_gaudit_okqual;
		$general_resource_basic_data_record{$grbd_name}->{gaudit_faqual} = $grbd_gaudit_faqual;
		$general_resource_basic_data_record{$grbd_name}->{warning}       = $grbd_warning;
		$general_resource_basic_data_record{$grbd_name}->{singleds}      = $grbd_singleds;
		$general_resource_basic_data_record{$grbd_name}->{auto}          = $grbd_auto;
		$general_resource_basic_data_record{$grbd_name}->{tvtoc}         = $grbd_tvtoc;
		$general_resource_basic_data_record{$grbd_name}->{notify_id}     = $grbd_notify_id;
		$general_resource_basic_data_record{$grbd_name}->{access_sun}    = $grbd_access_sun;
		$general_resource_basic_data_record{$grbd_name}->{access_mon}    = $grbd_access_mon;
		$general_resource_basic_data_record{$grbd_name}->{access_tue}    = $grbd_access_tue;
		$general_resource_basic_data_record{$grbd_name}->{access_wed}    = $grbd_access_wed;
		$general_resource_basic_data_record{$grbd_name}->{access_thu}    = $grbd_access_thu;
		$general_resource_basic_data_record{$grbd_name}->{access_fri}    = $grbd_access_fri;
		$general_resource_basic_data_record{$grbd_name}->{access_sat}    = $grbd_access_sat;
		$general_resource_basic_data_record{$grbd_name}->{start_time}    = $grbd_start_time;
		$general_resource_basic_data_record{$grbd_name}->{end_time}      = $grbd_end_time;
		$general_resource_basic_data_record{$grbd_name}->{zone_offset}   = $grbd_zone_offset;
		$general_resource_basic_data_record{$grbd_name}->{zone_direct}   = $grbd_zone_direct;
		$general_resource_basic_data_record{$grbd_name}->{seclevel}      = $grbd_seclevel;
		$general_resource_basic_data_record{$grbd_name}->{appl_data}     = $grbd_appl_data;
		$general_resource_basic_data_record{$grbd_name}->{seclabel}      = $grbd_seclabel;
	}
	elsif ( $rec_type eq "0501" )
	{
		#-----General resource tape volume data record (0501)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0502" )
	{
		#-----General resource tape volume data record (0502)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0503" )
	{
		#-----General resource members record (0503)-----
		my($grmem_name)       = IAD::MiscFunc::trim( substr($line,5,246) );   #general resource name as taken from the profile name
		my($grmem_class_name) = IAD::MiscFunc::trim( substr($line,252,8) );   #name of the class to which the general resource profile belongs
		my($grmem_member)     = IAD::MiscFunc::trim( substr($line,261,255) ); #member value for this general resource:
																			  # --for VMXEVENT profiles, this is the element that is being audited
																			  # --for PROGRAM profiles, this is the name of the data set which contains the program
																			  # --for GLOBAL profiles, this is the name of the resource for which a global access applies
																			  # --for SECDATA security level (SECLEVEL) profiles, this is the level name.  for SECDATA CATEGORY
																			  #    profiles, this is the category name.
																			  # --for NODES profiles, this i the user id, group name, and security label translation data
																			  # --for SECLABEL profiles, this is a 4-byte SMF id
		#global acc - data inconsistencies		
		eval( my($grmem_global_acc) = substr($line,517,8) );                  #if this is a GLOBAL profile, this is the access that is allowed. valid values are [NONE, READ, UPDATE,																	    
		if ($grmem_global_acc) { $grmem_global_acc = IAD::MiscFunc::trim($grmem_global_acc); }    #CONTROL, and ALTER]
		
		#global acc - data inconsistencies		
		eval( my($grmem_pads_data) = substr($line,526,8) );                   #if this is a PROGRAM profile, this field contains the Program Access to Data Set (PADS) information for
		if ($grmem_pads_data) { $grmem_pads_data = IAD::MiscFunc::trim($grmem_pads_data); } #the profile.  valid values are: [PADCHK and NOPADCHK]
		
		#vol name - data inconsistencies		
		eval( my($grmem_vol_name) = substr($line,535,6) );                    #if this is a PROGRAM profile, this field defines the volume upon which the program resides
		if ($grmem_vol_name) { $grmem_vol_name = IAD::MiscFunc::trim($grmem_vol_name); } 
		
		#vmevent - data inconsistencies		
		eval( my($grmem_vmevent_data) = substr($line,542,5) );                #if this is a VMXEVENT profile, this field defines the level of auditing that is being performed. valid
		if ($grmem_vmevent_data) { $grmem_vmevent_data = IAD::MiscFunc::trim($grmem_vmevent_data); } #values are: [CTL, AUDIT, and NOCTL]
		
		#seclevel - data inconsistencies		
		eval( my($grmem_seclevel) = substr($line,548,5) );                    #if this is a SECLEVEL profile in the SECDATA class, this is the numeric security level that is associated
		if ($grmem_seclevel) { $grmem_seclevel = IAD::MiscFunc::trim($grmem_seclevel); } #with the SECLEVEL
	
		#category - data inconsistencies		
		eval( my($grmem_category) = substr($line,548,5) );                    #if this is a CATEGORY profile in the SECDATA class, this is the numeric category that is associated with
		if ($grmem_category) { $grmem_category = IAD::MiscFunc::trim($grmem_category); } #the CATEGORY
		
		#store
		$general_resource_members_record{$grmem_member}->{name}         = $grmem_name;
		$general_resource_members_record{$grmem_member}->{class_name}   = $grmem_class_name;
		$general_resource_members_record{$grmem_member}->{global_acc}   = $grmem_global_acc;
		$general_resource_members_record{$grmem_member}->{pads_data}    = $grmem_pads_data;
		$general_resource_members_record{$grmem_member}->{vol_name}     = $grmem_vol_name;
		$general_resource_members_record{$grmem_member}->{vmevent_data} = $grmem_vmevent_data;
		$general_resource_members_record{$grmem_member}->{seclevel}     = $grmem_seclevel;
		$general_resource_members_record{$grmem_member}->{category}     = $grmem_category;
	}
	elsif ( $rec_type eq "0504" )
	{
		#-----General resource volumes record (0504)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0505" )
	{
		#-----General resource access record (0505)-----
		my($gracc_name)       = IAD::MiscFunc::trim( substr($line,5,246) );   #general resource name as taken from the profile name
		my($gracc_class_name) = IAD::MiscFunc::trim( substr($line,252,8) );   #name of the class to which the general resource profile belongs
		my($gracc_auth_id)    = IAD::MiscFunc::trim( substr($line,261,8) );   # user id or group name which is authorized to use the general resource
		my($gracc_access)     = IAD::MiscFunc::trim( substr($line,270,8) );   #the authority that the user or group has over the resource.  valid values are [NONE, READ, UPDATE,
																			  #CONTROL, and ALTER]
		my($gracc_access_cnt) = IAD::MiscFunc::trim( substr($line,279,5) );   #the number of times that the resource was accessed
	
		#store
		$general_resource_access_record{$gracc_name}->{$gracc_auth_id}->{class_name} = $gracc_class_name;
		$general_resource_access_record{$gracc_name}->{$gracc_auth_id}->{access}     = $gracc_access;
		$general_resource_access_record{$gracc_name}->{$gracc_auth_id}->{access_cnt} = $gracc_access_cnt;		
	}
	elsif ( $rec_type eq "0506" )
	{
		#-----General resource installation record (0506)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0507" )
	{
		#-----General resource conditional access record (0507)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0508" )
	{
		#-----General resource filter data record (0508)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0510" )
	{
		#-----General resource session data record (0510)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0511" )
	{
		#-----General resource session entities record (0511)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0520" )
	{
		#-----General resource DLF data record (0520)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0521" )
	{
		#-----General resource DLF job names record (0521)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0540" )
	{
		#-----General resource started task data record (0540)-----
		my($grst_name)       = IAD::MiscFunc::trim( substr($line,5,246) );   #general resource name as taken from the profile name
		my($grst_class_name) = IAD::MiscFunc::trim( substr($line,252,8) );   #the class name, STARTED
		my($grst_user_id)    = IAD::MiscFunc::trim( substr($line,261,8) );   #user id assigned
		my($grst_group_id)   = IAD::MiscFunc::trim( substr($line,270,8) );   #group name assigned
		my($grst_trusted)    = IAD::MiscFunc::trim( substr($line,279,4) );   #is process to run trusted (yes/no)?
		my($grst_privileged) = IAD::MiscFunc::trim( substr($line,284,4) );   #is process to run privileged (yes/no)?
		my($grst_trace)      = IAD::MiscFunc::trim( substr($line,289,4) );   #is entry to be traced (yes/no)?
		
		#store
		$general_resource_started_task_data_record{$grst_name}->{class_name} = $grst_class_name;
		$general_resource_started_task_data_record{$grst_name}->{user_id}    = $grst_user_id;
		$general_resource_started_task_data_record{$grst_name}->{group_id}   = $grst_group_id;
		$general_resource_started_task_data_record{$grst_name}->{trusted}    = $grst_trusted;
		$general_resource_started_task_data_record{$grst_name}->{privileged} = $grst_privileged;
		$general_resource_started_task_data_record{$grst_name}->{trace}      = $grst_trace;
	}
	elsif ( $rec_type eq "0550" )
	{
		#-----General resource SystemView data record (0550)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0560" )
	{
		#-----General resource certificate data record (0560)-----
		my($grcert_name)        = IAD::MiscFunc::trim( substr($line,5,246) );   #general resource name as taken from the profile name
		my($grcert_class_name)  = IAD::MiscFunc::trim( substr($line,252,8) );   #name of the class to which the general resource profile belongs
		my($grcert_start_date)  = IAD::MiscFunc::trim( substr($line,261,10) );  #the date from which this certificate is valid
		my($grcert_start_time)  = IAD::MiscFunc::trim( substr($line,272,8) );   #the time from which this certificate is valid
		my($grcert_end_date)    = IAD::MiscFunc::trim( substr($line,281,10) );  #the date after which this certificate is no longer valid
		my($grcert_end_time)    = IAD::MiscFunc::trim( substr($line,292,8) );   #the time after which this certificate is no longer valid
		my($grcert_key_type)    = IAD::MiscFunc::trim( substr($line,301,8) );   #the type of key associated with the certificate. valid values are [PKCSDER, ICSFTOKN, PCICCTKN,
								 											    #DSA, or all blanks indicating no private key.  the value PUBTOKEN indicates that the public key
																			    #(without the private key) is stored in ICSF.
		my($grcert_key_size)    = IAD::MiscFunc::trim( substr($line,310,10) );  #the size of private key associated with the certificate, expressed in bits
		my($grcert_last_serial) = IAD::MiscFunc::trim( substr($line,321,16) );  #the hexadecimal representation of the low-order eight bytes of the serial number of the last 
																				#certificate signed with this key
		my($grcert_ring_seqn)   = IAD::MiscFunc::trim( substr($line,338,10) );  #a sequence number for certificates within the ring
		
		#store
		$general_resource_certificate_data_record{$grcert_name}->{class_name}  = $grcert_class_name;
		$general_resource_certificate_data_record{$grcert_name}->{start_date}  = $grcert_start_date;
		$general_resource_certificate_data_record{$grcert_name}->{start_time}  = $grcert_start_time;
		$general_resource_certificate_data_record{$grcert_name}->{end_date}    = $grcert_end_date;
		$general_resource_certificate_data_record{$grcert_name}->{end_time}    = $grcert_end_time;
		$general_resource_certificate_data_record{$grcert_name}->{key_type}    = $grcert_key_type;
		$general_resource_certificate_data_record{$grcert_name}->{key_size}    = $grcert_key_size;
		$general_resource_certificate_data_record{$grcert_name}->{last_serial} = $grcert_last_serial;
		$general_resource_certificate_data_record{$grcert_name}->{ring_seqn}   = $grcert_ring_seqn;
	}
	elsif ( $rec_type eq "0561" )
	{
		#-----General resource certificate references record (0561)-----
		my($certr_name)       = IAD::MiscFunc::trim( substr($line,5,246) );   #general resource name as taken from the profile name
		my($certr_class_name) = IAD::MiscFunc::trim( substr($line,252,8) );   #name of the class to which the general resource profile belongs
		my($certr_ring_name)  = IAD::MiscFunc::trim( substr($line,261,246) ); #the name of the profile which represents a key ring with which this certificate is associated
				
		#store
		$general_resource_certificate_references_record{$certr_name}->{class_name} = $certr_class_name;
		$general_resource_certificate_references_record{$certr_name}->{ring_name}  = $certr_ring_name;		
	}
	elsif ( $rec_type eq "0562" )
	{
		#-----General resource key ring data record (0562)-----
		my($keyr_name)         = IAD::MiscFunc::trim( substr($line,5,246) );   #general resource name as taken from the profile name
		my($keyr_class_name)   = IAD::MiscFunc::trim( substr($line,252,8) );   #name of the class to which the general resource profile belongs
		my($keyr_cert_name)    = IAD::MiscFunc::trim( substr($line,261,246) ); #the name of the profile which contains the certificate which is in this key ring
		my($keyr_cert_usage)   = IAD::MiscFunc::trim( substr($line,509,516) ); #the usage of the certificate within the ring. valid values are: [PERSONAL, SITE, and CERTAUTH]
		my($keyr_cert_default) = IAD::MiscFunc::trim( substr($line,517,4) );   #is this certificate the default certificate within the ring (yes/no)?
		my($keyr_cert_label)   = IAD::MiscFunc::trim( substr($line,522,32) );  #the label associated with the certificate
		
		#store
		$general_resource_key_ring_data_record{$keyr_cert_name}->{key_ring_name} = $keyr_name;
		$general_resource_key_ring_data_record{$keyr_cert_name}->{class_name}    = $keyr_class_name;
		$general_resource_key_ring_data_record{$keyr_cert_name}->{cert_usage}    = $keyr_cert_usage;
		$general_resource_key_ring_data_record{$keyr_cert_name}->{cert_default}  = $keyr_cert_default;
		$general_resource_key_ring_data_record{$keyr_cert_name}->{cert_label}    = $keyr_cert_label;		
	}
	elsif ( $rec_type eq "0570" )
	{
		#-----General resource TME data record (0570)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0571" )
	{
		#-----General resource TME child record (0571)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0572" )
	{
		#-----General resource TME resource record (0572)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0573" )
	{
		#-----General resource TME group record (0573)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0574" )
	{
		#-----General resource TME role record (0574)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0580" )
	{
		#-----General resource KERB data record (0580)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "0590" )
	{
		#-----General resource PROXY record (0590)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "05A0" )
	{
		#-----General resource EIM record (05A0)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "05B0" )
	{
		#-----General resource alias data record (05B0)-----
		my($gralias_name)       = IAD::MiscFunc::trim( substr($line,5,246) );   #general resource name as taken from the profile name
		my($gralias_class_name) = IAD::MiscFunc::trim( substr($line,252,8) );   #name of the class to which the general resource belongs
		my($gralias_iplook)     = IAD::MiscFunc::trim( substr($line,261,16) );  #ip lookup value in SERVAUTH class
		
		#store
		$general_resource_alias_data_record{$gralias_name}->{class_name} = $gralias_class_name;
		$general_resource_alias_data_record{$gralias_name}->{iplook}     = $gralias_iplook;		
	}
	elsif ( $rec_type eq "05C0" )
	{
		#-----General resource CDTINFO data record (05C0)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	elsif ( $rec_type eq "05D0" )
	{
		#-----General resource ICTX data record (05D0)-----
		
		#None used at TRU for audit, code later!
		print "$rec_type found...code me!\n";
		my $get = <STDIN>;
	}
	
	
	
}

#==============
# Report Section
#==============
my $sheet_name;
my $purpose;
my $procedure;
my $domain;
my $reference;
IAD::WPXL::init_xl("RACF Audit Program");

#-----------------------------
# .:: universal groups ::.
#-----------------------------
$sheet_name = "RACF.GRP.UNIV";

#add w/p
IAD::WPXL::add_sheet($sheet_name);

#add title and column headings
IAD::WPXL::add_header("Universal Groups","Group Name","Group Description","Universal?");

#add ppc to audit program
$purpose   = "Verify that any universal groups are appropriate.  Universal groups are user groups that do " . 
		     "not have complete membership information stored in their group profiles. The benefit is that " . 
			 "there is no limit on the number of group members.  However, these groups may be used in access " . 
			 "control lists inappropriately, allowing too many users access to a given resource.";

$procedure = "Using the output from IRRDBU00 (RACF database unload utility) is the best way to list the " . 
             "universal groups.  Simply extract out all 0100 records and verify the GPBD_UNIVERSAL settings. " . 
			 "Additionally, the LISTGRP command could be used to verify groups on an individual basis.";

$domain    = "Groups";
$reference = $sheet_name;
IAD::WPXL::add_ppc($purpose,$domain,$procedure,$reference);

for my $group ( sort keys %group_basic_data_record ) 
{
	if ( lc($group_basic_data_record{$group}->{universal}) eq "yes" )
	{
		IAD::WPXL::write_row($group,
		                     $group_basic_data_record{$group}->{install_data},
							 $group_basic_data_record{$group}->{universal});
	}
} 

#link to audit program
IAD::WPXL::add_ap_link($sheet_name);

#-------------------------------------
#.:: groups with no members ::.
#-------------------------------------
$sheet_name = "RACF.GRP.NOMBRS";

#add w/p
IAD::WPXL::add_sheet($sheet_name);

#add title and column headings
IAD::WPXL::add_header("Groups with 0 or 1 members","Group Name","Group Desc","Members");

#add ppc to audit program
$purpose   = "Any groups that have 1 or no members should not exist or should have a documented purpose.";
	         
$procedure = "Using the output from IRRDBU00 (RACF database unload utility) is the best way to verify groups with no members. " .
			 "Extract out all 0102 records and analyze any groups that have no associated profiles in it.  Additionally " . 
			 "one could issue the LISTGRP command for each group individually to get the members and verify any without members.";

$domain    = "Groups";
$reference = $sheet_name;
IAD::WPXL::add_ppc($purpose,$domain,$procedure,$reference);

for my $group ( sort keys %group_members_record ) 
{
	my @ids = keys %{ $group_members_record{$group} };
	my $id_str = join(" ",@ids);
	
	if ( scalar @ids == 1 || scalar @ids == 0) 
	{ 	
		IAD::WPXL::write_row($group,
							 $group_basic_data_record{$group}->{install_data},
							 $id_str);
	}	
} 

#link to audit program
IAD::WPXL::add_ap_link($sheet_name);

#----------------------------------------------
# .:: group member authority check ::. 
#----------------------------------------------
$sheet_name = "RACF.GRP.AUTH";

#add w/p
IAD::WPXL::add_sheet($sheet_name);

#add title and column headings
IAD::WPXL::add_header("Group Authorities greater than USE","Group Name","Group Desc","Superior?","Sub?","UserID","UserID Desc","Revoked?","Authority");

#add ppc to audit program
$purpose   = "User IDs have a set of group authorities within a group profile they are a member of.  These authorities " .
	         "are one of the following (in order from least authority to most): USE, CREATE, CONNECT, and JOIN.  Each " . 
			 "higher level includes all of the authorities given in the level(s) below it.  Thus, for example the JOIN " . 
			 "authority is the most powerful and includes all of the authorities granted at the USE, CREATE, and CONNECT " . 
			 "levels.  The authorities allow the following: USE allows you to access resources to which the group is authorized. " .
			 "CREATE allows you to create RACF data set profiles for the group. CONNECT allows you to connect other users " . 
			 "to the group. JOIN allows you to add new subgroups or users to the group, as well as assign group authorities " . 
			 "to the new members. Verify that all user authorities greater than USE within each group and subgroups of the group " . 
			 "are appropriate.";

$procedure = "Using the output from IRRDBU00 (RACF database unload utility) is the best way to verify group members and their " . 
			 "group authorities.  Extract out all 0102 records and analyze the GPMEM_AUTH field for all User IDs.  Additionally " . 
			 "one could issue the LISTGRP command for the group to view the group authorities/members on an individual basis.";

$domain    = "Groups";
$reference = $sheet_name;
IAD::WPXL::add_ppc($purpose,$domain,$procedure,$reference);

my %grp_auth_anz;
for my $group ( sort keys %group_members_record ) 
{
	$grp_auth_anz{$group}->{sup} = 0;
	$grp_auth_anz{$group}->{sub} = 0;
	
	for my $id ( sort keys %{ $group_members_record{$group} } )
	{
		unless ( lc($group_members_record{$group}->{$id}->{auth}) eq "use" )
		{
			$grp_auth_anz{$group}->{name} = $group_basic_data_record{$group}->{install_data};
			$grp_auth_anz{$group}->{sup}  = 1;
			$grp_auth_anz{$group}->{ids}->{$id}->{name} = $user_basic_data_record{$id}->{programmer};		
			$grp_auth_anz{$group}->{ids}->{$id}->{auth} = $group_members_record{$group}->{$id}->{auth};
		}
	}
	
	#process all subgroups
	for my $sub_grp ( sort keys %{ $group_subgroups_record{$group} } )
	{
		for my $id ( sort keys %{ $group_members_record{$sub_grp} } )
		{
			unless ( lc($group_members_record{$sub_grp}->{$id}->{auth}) eq "use" )
			{
				$grp_auth_anz{$group}->{name} = $group_basic_data_record{$group}->{install_data};
				$grp_auth_anz{$group}->{sub}  = 1;
				$grp_auth_anz{$group}->{ids}->{$id}->{name} = $user_basic_data_record{$id}->{programmer};
				$grp_auth_anz{$group}->{ids}->{$id}->{auth} = $group_members_record{$group}->{$id}->{auth};				
			}
		}
	}
}

#write results
for my $group ( sort keys %grp_auth_anz )
{
	my $name = $grp_auth_anz{$group}->{name};
	my $sup  = $grp_auth_anz{$group}->{sup};
	my $sub  = $grp_auth_anz{$group}->{sub};
	if ($sup == 1) { $sup = "Yes"; } else { $sup = "No"; }
	if ($sub == 1) { $sub = "Yes"; } else { $sub = "No"; }
	
	for my $id ( sort keys %{ $grp_auth_anz{$group}->{ids} } )
	{
		IAD::WPXL::write_row($group,
							 $name,
							 $sup,
							 $sub,
							 $id,
							 get_revoked_status($id),
							 $user_basic_data_record{$id}->{programmer},
							 $group_members_record{$group}->{$id}->{auth}); 			
	}
}


#link to audit program
IAD::WPXL::add_ap_link($sheet_name);

#-------------------------------------
#.:: systems group members ::.
#-------------------------------------
$sheet_name = "RACF.GRP.SYS";

#add w/p
IAD::WPXL::add_sheet($sheet_name);

#add title and column headings
IAD::WPXL::add_header("Group Authorities greater than USE","Group Name","Group Desc","UserID","UserID Desc","Authority","Subgroup?");

#add ppc to audit program
$purpose   = "Verify that the users within any SYS [SYSADMIN, SYSTEMS, SYS1, etc.] are appropriate.";
	         
$procedure = "Using the output from IRRDBU00 (RACF database unload utility) is the best way to verify members of any SYS groups. " . 
			 "Extract out all 0102 records and analyze the GPMEM_NAME field for all SYS groups.  Additionally " . 
			 "one could issue the LISTGRP command for each SYS group individually to get the members.";

$domain    = "Groups";
$reference = $sheet_name;
IAD::WPXL::add_ppc($purpose,$domain,$procedure,$reference);

for my $group ( sort keys %group_members_record ) 
{
	unless ( $group =~ /^sys.*/i ) { next; }	
	
	for my $id ( sort keys %{ $group_members_record{$group} } )
	{
		unless ( lc($group_members_record{$group}->{$id}->{auth}) eq "use" )
		{
			IAD::WPXL::write_row($group,
								 $group_basic_data_record{$group}->{install_data},
								 $id,
								 $user_basic_data_record{$id}->{programmer},
								 $group_members_record{$group}->{$id}->{auth},
								 "NONE");
		}
	}	
} 

#link to audit program
IAD::WPXL::add_ap_link($sheet_name);

#----------------------------------------------------------------
# .:: check OMVS groups for any duplicate GID  ::.
#----------------------------------------------------------------
$sheet_name = "RACF.GRP.OMVSGID";

#add w/p
IAD::WPXL::add_sheet($sheet_name);

#add title and column headings
IAD::WPXL::add_header("Duplicate GIDs","GID","Group Name","Group Desc","Members of Group");

#add ppc to audit program
$purpose   = "Verify that there are no OMVS group profiles with duplicate GIDs.  There should be no duplicate GIDs as this " . 
			 "could result in two groups having the same level of access when they should not.";
	         
$procedure = "Using the output from IRRDBU00 (RACF database unload utility) extract out all 0120 records. " . 
			 "Analyze the records for any ones that have the same GPOMVS_GID number.";

$domain    = "Groups";
$reference = $sheet_name;
IAD::WPXL::add_ppc($purpose,$domain,$procedure,$reference);

my %omvs_gid;
for my $group ( sort keys %group_omvs_data_record ) 
{
	#store GID
	my $gid = $group_omvs_data_record{$group}->{gid};
	$omvs_gid{$gid}->{count}++;
	$omvs_gid{$gid}->{groups}->{$group} = 1;
}

for my $gid (sort keys %omvs_gid)
{
	if ( $omvs_gid{$gid}->{count} > 1 )
	{
		#duplicate found, write details - with a list of user IDs in group
		for my $group ( sort keys %{ $omvs_gid{$gid}->{groups} } )
		{
			my @ids = sort keys %{ $group_members_record{$group} };
			my ($id_str,$i);
			for my $id ( @ids )
			{
				$i++;
				if ( $i > 5 )
				{
					$i=0;
					$id_str .= "$id\n";
				}
				else
				{
					$id_str .= "$id ";
				}
			}
			IAD::WPXL::write_row($gid,
							     $group,
								 $group_basic_data_record{$group}->{install_data},
								 $id_str);
		}
	}	
}

#link to audit program
IAD::WPXL::add_ap_link($sheet_name);















# .:: _the_end_ 
IAD::WPXL::end_formatting;
my $filename = "d:\\racf\\RACF_reports.xlsx";
IAD::WPXL::exit_xl($filename);
print "\n\n";
print "Saved report to: $filename","\n";




















#testing
#print "\n\n\n\n\n";
#print "+++++++++++++++++++++++++++++++++++++++++++++++++++++++\n";
#my $group = "SYSTEMS";
#print $group_basic_data_record{$group}->{owner_id} . "\n";
#my @sg = keys %{ $group_subgroups_record{$group} };
#print join(" ",@sg) . "\n";
#print "+++++++++++++++++++++++++++++++++++++++++++++++++++++++\n";
#print "\n";

#record type analysis
#open OUT, ">rec_analysis.txt" or die "I'm dead in the analysis water...\n";
#my $total = $rec_analysis{total};
#for my $rec (sort keys %rec_analysis)
#{
#	unless ($rec eq "total") { print OUT "$rec -> $rec_analysis{$rec}->{count} of $total\n"; }
#}
#close OUT;

for my $id ( sort keys %user_basic_data_record )
{
	my $revoke_date  = $user_basic_data_record{$id}->{revoke_date};
	my $resume_date  = $user_basic_data_record{$id}->{resume_date};
	my $revoked_flag = $user_basic_data_record{$id}->{revoked};
	my $rv = get_revoked_status($id);
	if ($rv) 
	{
		#print "$id -> revoked ($revoke_date | $resume_date | $revoked_flag)\n";
	}
	else
	{
		#print "$id -> not revoked ($revoke_date | $resume_date | $revoked_flag)\n";
	}
}

#=========
#Functions
#=========
sub get_revoked_status
{
	#returns a 1 if the user profile passed IS REVOKED or returns a 0 if the user profile is NOT revoked
	my($id) = @_;
	my $revoke_date  = $user_basic_data_record{$id}->{revoke_date};
	my $resume_date  = $user_basic_data_record{$id}->{resume_date};
	my $revoked_flag = $user_basic_data_record{$id}->{revoked};
	my $run_mon = "04";
	my $run_day = "04";
	my $run_yr  = "2008";
		
	if ( $resume_date && $revoke_date )
	{
		#both defined
		print "both defined: $resume_date && $revoke_date\n";
		my($rv_yr,$rv_mon,$rv_day) = split/-/, $revoke_date;
		my($rs_yr,$rs_mon,$rs_day) = split/-/, $resume_date;
		
		if ( Date_to_Days($run_yr,$run_mon,$run_day) >= Date_to_Days($rv_yr,$rv_mon,$rv_day) &&
			 Date_to_Days($run_yr,$run_mon,$run_day) <  Date_to_Days($rs_yr,$rs_mon,$rs_day) )
		{
			return "Yes"; #revoked
		}
		else
		{
			return "No"; #not revoked;
		}
		
	}
	elsif ( $resume_date && !$revoke_date )
	{
		#resume date defined, but revoke date undefined
		my($rs_yr,$rs_mon,$rs_day) = split/-/, $resume_date;
	
		if ( Date_to_Days($run_yr,$run_mon,$run_day) <  Date_to_Days($rs_yr,$rs_mon,$rs_day) )
		{
			return "Yes"; #revoked
		}
		else
		{
			return "No"; #not revoked;
		}
	
	}
	elsif ( !$resume_date && $revoke_date )
	{
		#resume date undefined, but revoked date is defined
		my($rv_yr,$rv_mon,$rv_day) = split/-/, $revoke_date;
	
		if ( Date_to_Days($run_yr,$run_mon,$run_day) >=  Date_to_Days($rv_yr,$rv_mon,$rv_day) )
		{
			return "Yes"; #revoked
		}
		else
		{
			return "No"; #not revoked;
		}
	
	}
	elsif ( !$resume_date && !$revoke_date )
	{
		#neither defined
		if ( lc($revoked_flag) eq 'yes' )
		{
			return "Yes"; #revoked
		}
		else
		{	
			return "No"; #not revoked
		}	
	}
	else
	{
		#error
		print "error in get_revoked_status: unknown revoke/resume date combination.\n";
	}
}
