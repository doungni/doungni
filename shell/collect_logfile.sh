#!/bin/bash -xe
#######################################################################################
#  Author        : doungni
#  Email         : doungni@doungni.com
#  Last modified : 2015-11-04 10:53
#  Filename      : collect_logfile.sh
#  Description   : collect logfile, by ssh and scp
#######################################################################################

#######################################################################################
# env variables  : work_path, collect_time, server_list, logfile_list, tail_line
#                  collect_time, ssh_key_file, expired_del
# env value
# work_path:     : ${WORKSPACE}
# collect_time   : `date+'%Y%m%d-%H%M%S'`
# ssh_key_file   : "${JENKINS_HOME}/.ssh/id_rsa"
# server_list    : By jenkins job configuration
# logfile_list   : By jenkins job configuration
# tail_line      : By jenkins job configuration
# expired_del    : By jenkins job configuration
#######################################################################################

############################ collect_logfile.sh Start #################################

function log() {
    local msg=$*

    echo -e `date +['%Y-%m-%d %H-%M-%S']` "\n$msg\n"
}

#######################################################################################
# Paramenter     : server_list, server_arr[], server_split[], server_ip, server_port
#                  server_hostname, ssh_result, logfile_list, logfile_parent_dir
#                  logfile_name, tail_line
# Function       :
#                  split each server
#                  split ip and port
#                  connect server
#                  collect logfile
#                  compress logfile
#######################################################################################
function collect_logfile() {

    # Non NULL judgment of ${server_list}
    if [ -z "${server_list}" ]; then
	    log "Please refer to the correct parameters for the prompt configuration"
	    exit 1
    fi

    # Each server is separated by a comma
    server_arr=(${server_list//,/ })

    local n=1
    for i in ${server_arr[*]}
    do
        echo -e "Need to collect the logfile Server[$n]-IP:PORT\n$i\n"
        n=`expr $n + 1`
    done
    log "####### Will collect ${#server_arr[*]} machine logfile #######"

    for server in ${server_arr[*]}
    do
        log "####### Collect logfile the server_ip:port:${server} #######"

        server_split=(${server//:/ })

        server_ip=${server_split[0]}
      	if [ -z "${server_ip}" ]; then
    	    log "Please check if your IP:${sever_ip} input is correct."
    	fi
        continue

        server_port=${server_split[1]}
      	if [ -z "${server_port}" ]; then
    	    log "Please check if your IP for Port:${sever_port} input is correct."
    	fi
        continue

        log "####### The server ip: ${server_ip}, ssh port: ${server_port} #######"

        # Increase the IP:Port connection judgment
        echo -e "\n" | telnet ${server_ip} ${server_port} | grep Connected 2>/dev/null 1>/dev/null

        if [ $? -eq 0 ]; then
    	    mkdir -p ${work_path}/${server_ip}
    	    cd ${work_path}/${server_ip}
    
            # cycle logfile_list
            for logfile in ${logfile_list[*]}
            do
                # get server_ip hostname
                server_hostname=`ssh -i ${ssh_key_file} -p ${server_port}  -o StrictHostKeyChecking=no root@${server_ip} "hostname"`
                
                # by connect ip collect logfile
                log "####### Start into ${server_hostname}-${server} collect logfile #######"
                log "####### Logfile: $logfile #######"
    
           	    # True if logfile exists and is readable
                ssh_result=`ssh -i ${ssh_key_file} -p ${server_port}  -o StrictHostKeyChecking=no root@${server_ip} "test -r ${logfile}" && echo yes || echo no`
    
                # If exist and readable
                if [ "x${ssh_result}" == "xyes" ]; then
                    # deal with logfile
                	logfile_parent_dir=${logfile%/*}
                    mkdir -p ${logfile_parent_dir#*/}
                    logfile_name=${logfile##*/}
    
                    # ${tail_line} <= 0 or null
                    if [ $tail_line -le 0 ] || [ -z $tail_line ];then
        	            log "####### Please refer to the correct parameters for the prompt configuration #######"
                    else
                        # collect the tail line of the log file.
                        ssh -i ${ssh_key_file} -p ${server_port} -o StrictHostKeyChecking=no root@${server_ip} "tail -n ${tail_line} ${logfile}" > ./${logfile_parent_dir}/${logfile_name}
                    fi
    	        else
        	        log "####### The ${logfile} is not found on the ${server_hostname}-${server} #######"
                fi

                # If you have collected the log file, pack all the log files in the server
                cd ${work_path}
                    
                # compress current ${server_ip} logfile, include empty file
                tar -zcf ${server_hostname}-${server_ip}-${collect_time}.tar.gz ${server_ip}/*
            done

            # Delete ${server_ip}
            rm -rf ${server_ip}
        else
            log "The ${server_ip} can not collect logfile"
        fi
   done
    
    # download logfile
    log "download log package link:${JOB_URL}/ws"
}

#######################################################################################
# Shell Entracnce 
#######################################################################################
# Parameter for current time
collect_time=`date +'%Y%m%d-%H%M%S'`

ssh_key_file="${JENKINS_HOME}/.ssh/id_rsa"

work_path="${WORKSPACE}/${JOB_NAME}-${collect_time}"
[ ! -d ${work_path} ] && mkdir -p ${work_path}
cd ${work_path}

# connect server and collect logfile
collect_logfile

# delete_expired_logfile
find ${WORKSPACE} -mtime +${expired_del} -name "${JOB_NAME}*" -exec rm -rf {} \+

############################ collect_logfile.sh End #################################