"""
This is a simple setup script for the Kast Shiv.

This should be run once from the code's root directory,
 before attempting to use the code.
 
This script goes into all of the files that require 
 hardcoded paths to other files, etc, and sets them
 properly.
"""

import os, platform
homedir = os.path.realpath('.')

# update the shivutils file
s = open('shivutils.template.py','r').read()
if platform.node() != 'classy':
    idlpath = raw_input('What is the path to the IDL executable?\n')
    reducer = raw_input("What is the reducer's name?\n")
else:
    idlpath = '/home/isaac/Working/code/IDL/idl83/bin/idl'
    reducer = 'Isaac Shivvers'

s = s.replace('replace_me:IDLPATH', idlpath)
s = s.replace('replace_me:HOMEDIR', homedir)
s = s.replace('replace_me:HOMEDIR', reducer)
open('shivutils.py','w').write(s)

# update the login.cl file
s = open('tools/custom_cl/login.template.cl','r').read()
s = s.replace('replace_me:home', homedir+'/tools/custom_cl/')
s = s.replace('replace_me:name', reducer)
open('tools/custom_cl/login.cl','w').write(s)

# update the kastfixhead file
s = open('tools/custom_cl/kastfixhead.template.cl','r').read()
s = s.replace('replace_me:asthedit_commands', homedir+'/tools/custom_cl/cmds.asthedit')
open('tools/custom_cl/kastfixhead.cl','w').write(s)

# update the final.pro file
s = open('tools/custom_idl/final.template.pro','r').read()
s = s.replace('replace_me:skyfilelocation', homedir+'/tools/')
open('tools/custom_idl/final.pro','w').write(s)

print '\nOk, good to go!\n'
print "Add the following lines to your ~/.bashrc file if you haven't yet and restart bash.\n"
print 'export IDL_PATH=$IDL_PATH:+%s/tools\nexport PYTHONPATH=$PYTHONPATH:%s\n' %(homedir, homedir)
