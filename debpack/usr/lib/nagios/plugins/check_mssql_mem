#!/usr/bin/env python
################### check_mssql.py #################
# Filename:     check_mssql
# Version :     1.1.0
# Date :        Jul 11th 2014
# Author  :     Rick Rune (rick at runeg dot net)
# Help :        rick at runeg dot net
# Licence :     GPL - http://www.fsf.org/licenses/gpl.txt
# TODO :        
# Changelog:
# Requires:     NSClient++ w/ NRPE enabled & SQL Server Perfmon Counters.
# Notes:        NRPE requires "allow_arguments" and "allow_nasty_meta_chars" enabled.
# Service Example: 
#   define service {
#        use                     generic-service
#        hostgroups              mssql-hosts
#        service_description     Memory: MSSQL Usage
#        check_command           check_mssqlmem!db_memory_calc!85!90!$HOSTNAME$
#   }
# Command Exmaple: 
#   define command{
#        command_name    check_mssqlmem
#        command_line    /usr/lib64/nagios/plugins/check_mssql -H $HOSTADDRESS$ -p 5666 -o $ARG1$ -w $ARG2$ -c $ARG3$ -a $ARG4$
#   }

################################################################
def main():   
    # Standard imports.
    from sys         import exit
    from optparse    import OptionParser
    from subprocess  import Popen, PIPE, call

    # Standard way to exit script.
    def sysExit(statusMessage, exitCode):
        print statusMessage
        exit(exitCode)
    
    # Simple wrapper around subprocess.Popen
    def subProc(command, shell=True):
        try:
            proc = Popen(command, stdout=PIPE, shell=True)
            output = proc.stdout.readlines()
            proc.stdout.close()
            if output[0].startswith("CRIT: Counter not found"):
                return -1
            parsed_output = output[0].split("=")[1][:-1]
            return int(parsed_output)
        except OSError, err:
            sysExit('Error executing check_nrpe. \n(subProc_Popen() exception running "%s": %s)' % (command, err), -1)
    
    # Calculating threshold results.
    def calculateThreshold(value, warn, crit):
        # For interger comparison
        value = int(value)
        warn = int(warn)
        crit = int(crit)

        # For services no thresholds.
        if [warn, crit] == [0, 0]:
            return 0 #'OK:'
        if value < warn:
            return 0 #  OK
        elif warn <= value < crit:
            return 1 #  WARNING
        elif crit <= value:
            return 2 #  CRITICAL
        else:
            return -1 # UNKNOWN
    
    # Execute subProcess against check_nrpe with derived variables.
    def exec_Check_NRPE(check_nrpe, hostname, port, option, warning, critical, sql2k12=False):
        definedCommand  = r'%s -H %s -p %s -n -c CheckCounter -a "%s"' % (check_nrpe, hostname, port, option)
        if option == "db_memory_calc":
            return db_memory_calc(check_nrpe, hostname, port, option, warning, critical, sql2k12)
        else:
            results = subProc(definedCommand)
            if results == -1:
                raise ValueError
            return results

    # Returns data to Nagios related to option.
    def returnedResults(option, optionOutput, queryResults, warning, critical):       
        # Setting Threshold response.
        thresholdStatus = calculateThreshold(queryResults[0], warning, critical)
        
        # Used for any Page based counters
        if optionOutput == 'pageconvert':
            # Converting page (1 Page = 8Kbytes) to byte to MByte.
            try:
                converted = ((int(queryResults)*8)/1024)
            except:
                sysExit("error: 108: Interger conversion error using: %s" % queryResults, -1)
            sysExit("%s: %s MB" % (option, converted), thresholdStatus)
            
        # Used for any percentrage based counters.
        elif optionOutput == 'perc':
            sysExit("%i %s: %s%%" % (option, queryResults), thresholdStatus)
    
        # Used to calculate used SQL memory vs total SQL memory.
        elif optionOutput == 'db_memory_calc':
            # Clarity for exit string.
            memPerc     = queryResults[0]
            usedMem     = queryResults[1]
            totalMem    = queryResults[2]
            #"Memory usage: total:4004.89 Mb - used: 1535.15 Mb (38%) - free: 2469.74 Mb (62%) | 'Memory usage'=1535.15Mb;0.00;0.00;0.00;4004.89\n"
            sysExit(("SQL Memory usage: %.2f%% (%.0f MB Used / %.0f MB Total) | 'SQL Memory usage'=%.2f;%s.00;%s.00;0;100;\n" \
                    % (memPerc, usedMem, totalMem, memPerc, warning, critical)), thresholdStatus)

    # Determines how to manipulate selected option.
    def optionOutput(option):
        if option.startswith("db_pages_"):
            return 'pageconvert'
        elif option in ['db_memory_calc']:
            return 'db_memory_calc'
        else:
            return 'base'

    # Returns used memory as percentage. Calculates used/total pages from SQL counters.
    def db_memory_calc(check_nrpe, hostname, port, option, warningCalcValue, criticalCalcValue, sql2k12=False):
        totalMem = exec_Check_NRPE(check_nrpe, hostname, port, optionList['db_pages_total'], warningCalcValue, criticalCalcValue, sql2k12)
        usedMem  = exec_Check_NRPE(check_nrpe, hostname, port, optionList['db_pages_used'], warningCalcValue, criticalCalcValue, sql2k12)
        # Gaining used memory and converting X.XX% to XX%
        if sql2k12:
            freeMem = usedMem 
            usedMem = totalMem - freeMem
            memResults  = (float(usedMem)/float(totalMem))*100
            return [memResults, ((usedMem)/1024), ((totalMem)/1024)]
        else:
            memResults  = (float(usedMem)/float(totalMem))*100
            return [memResults, ((usedMem*8)/1024), ((totalMem*8)/1024)]

    # This location works for Debian based servers using default installation dirs.
    check_nrpe = "/usr/lib64/nagios/plugins/check_nrpe"
    #cmd_check_nrpe = check_nrpe + ' -H ' + hostname + ' -n -c CheckCounter -a "' + counter + '"'
    
    #Option Parser diaglogues.
    usage = "Nagios plugin for querying against Windows Perfmon to check MSSQL used memory."
    optionDiag  =  'db_memory_calc:     Calculates SQL Memory in use\
                    db_pages_used:      Pages in use in MB\
                    db_pages_total:     Total pages in MB\
                    '

    # Argument parser.
    parser = OptionParser(usage=usage)
    # Argument list.
    parser.add_option('-H', '--hostname',   help='Specify hostname or IP Address',              default=False)
    parser.add_option('-p', '--port',       help='Specify port. [Default: 5666]',              default=5666)
    parser.add_option('-o', '--option',     help=optionDiag,                                    default='none')
    parser.add_option('-w', '--warning',    help='Specify min or max threshold',                default=0)
    parser.add_option('-c', '--critical',   help='Specify min or max threshold',                default=0)
    parser.add_option('-a', '--alias',      help='Specify host alias for SQL instance name',    default=False)
    
    # Making options a dictionary for easier manipulation.
    (options, args) = parser.parse_args()
    index = options.__dict__
    
    # Breaking down arguments.
    hostname = index['hostname']
    port = index['port']
    option = index['option'].lower()
    warning = str(index['warning'])
    critical = str(index['critical'])
    alias = index['alias']

    # MSSQL 2008 Counters
    mssql_2008_no_alias = {
        'db_pages_used':        r'\SQLServer:Buffer Manager\Database pages',
        'db_pages_total':       r'\SQLServer:Buffer Manager\Total pages',
        'db_memory_calc':       'db_memory_calc',
        }

    mssql_2008_alias = {}
    mssql_2008_alias['db_memory_calc'] = 'db_memory_calc'
    mssql_2008_alias['db_pages_total'] = r'\MSSQL\$%s:Buffer Manager\Total pages' % alias
    mssql_2008_alias['db_pages_used'] = r'\MSSQL\$%s:Buffer Manager\Database pages' % alias

    # MSSQL 2012 Counters
    mssql_2012_no_alias =   {
        'db_pages_total':       r'\SQLServer:Memory Node(000)\Total Node Memory (KB)',
        'db_pages_used':        r'\SQLServer:Memory Node(000)\Free Node Memory (KB)',
        'db_memory_calc':       'db_memory_calc',
        }
        
    mssql_2012_alias = {}
    mssql_2012_alias['db_memory_calc'] = 'db_memory_calc'
    mssql_2012_alias['db_pages_total'] = r'\MSSQL\$%s:Memory Node(000)\Total Node Memory (KB)' % alias
    mssql_2012_alias['db_pages_used'] = r'\MSSQL\$%s:Memory Node(000)\Free Node Memory (KB)' % alias

    optionList = mssql_2008_no_alias
    optionList['db_memory_calc'] = 'db_memory_calc'
    # Catch for non-existant options.
    if option not in optionList.keys():
        sysExit("Error: \tMethod \"%s\" not in Method List." % option, -1)
    typeResults     = optionOutput(option)

    #SQL 2008 Logic
    if not alias:
        sysExit("Error: \tNo Alias set? IP: %s" % (hostname), -1)    

    #SQL 2008 w/ no alias
    try:
        queryResults = exec_Check_NRPE(check_nrpe, hostname, port, optionList[option], warning, critical)
    except ValueError:
        # SQL 2008 w/ alias
        try:
            optionList = mssql_2008_alias
            queryResults = exec_Check_NRPE(check_nrpe, hostname, port, optionList[option], warning, critical)
        except ValueError:
            #SQL 2012 w/ no alias
            try:
                optionList = mssql_2012_no_alias
                queryResults = exec_Check_NRPE(check_nrpe, hostname, port, optionList[option], warning, critical, sql2k12=True)
            except ValueError:
                #SQL 2012 w/ alias
                optionList = mssql_2012_alias
                queryResults = exec_Check_NRPE(check_nrpe, hostname, port, optionList[option], warning, critical, sql2k12=True)
    returnedResults(option, typeResults, queryResults, warning, critical)
if __name__ == '__main__':
    main()
