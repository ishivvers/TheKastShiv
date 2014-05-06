"""
This is a simple setup script for the Kast Shiv.

This should be run once from the code's root directory
 once, before attempting to use the code.
 
This script goes into all of the files that require 
 hardcoded paths to other files, etc, and sets them
 properly.
"""

import os
homedir = os.path.realpath('.')

# update the shivutils file
s = open('shivutils.py.template','r').read()
inn = raw_input('What is the path to the IDL executable?\n')
s = s.replace('replace_me:IDLPATH', inn)
s = s.replace('replace_me:HOMEDIR', homedir)
open('shivutils.py','w').write(s)

# update the login.cl file
s = open('tools/custom_cl/login.cl.template','r').read()
s = s.replace('replace_me:home', homedir+'/tools/custom_cl/')
open('tools/custom_cl/login.cl','w').write(s)

# update the kastfixhead file
s = open('tools/custom_cl/kastfixhead.cl.template','r').read()
s = s.replace('replace_me:asthedit_commands', homedir+'/tools/custom_cl/cmds.asthedit')
open('tools/custom_cl/kastfixhead.cl','w').write(s)

# update the final.pro file
s = open('tools/custom_idl/final.pro.template','r').read()
s = s.replace('replace_me:skyfilelocation', homedir+'/tools/')
open('tools/custom_idl/final.pro','w').write(s)

print '\nOk, good to go!\n'
print 'Add the followng lines to your ~/.bashrc file and restart bash.\n'
print 'export IDL_PATH=$IDL_PATH:+%s/tools\nexport PYTHONPATH=$PYTHONPATH:%s\n' %(homedir, homedir)