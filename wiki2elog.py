# Read in a wiki night summary from a Kast run and turn that into an e-log
#
# The input wiki page should be structured as follows:
#        Any number of paragraphs of comments
#        A table with a header row with the entries:
#                 Obs. # 	Object    Side 	 Group 	 Type 	 Notes
#        where Obs. # is the observation number (can be a range of numbers, 
#	 e.g. 7-11, but ONLY for flats), Object is a string that describes
#	 the object, Side is the side number (usually 1 for Blue, 2 for Red),
#	 Group is the group number (each set of objects that share a given
#	 red arc and set of red flats gets its own group number), Type is the
#	 type of observation ( "flat", "arc", or "obj"), and Notes is an
#	 optional field for notes.
#    NOTE: the first arcs listed should be the 0.5" arcs!
#
#    NOTE: the prototype wiki night summary can be found on the Flipper wiki
#          under "9/04 Kast (OC)" (id=9_04_kast_oc)
#
# Output is an e-log in the same form as kp.log in this folder and
#  named as XX.log (where XX is the run code that you enter at the 
#  beginning of the program)
#
# Hopefully observers will run this program during all obesrving runs
#  so that reducers don't have to run it themselves before an starting
#  a reduction
#

# import os module for various input and output functions
import os

# import URL library module to read the FlipperWiki
import urllib

# import get password library and credentials file to get the Wiki password
from getpass import getpass
import credentials

# define lists to hold observation data
obs= []
side = []
group = []
type = []

# get Wiki username and password
#user = raw_input("Enter your FlipperWiki username: ")
#pword = getpass("Enter your FlipperWiki password: ")
user = credentials.wiki_un
pword = credentials.wiki_pw

# ask user for run code
run = raw_input('Please enter the run code (***lowercase***): ')
run = run.lower()

# ask user for Night Summary page name
pagename = raw_input('Please enter the Night Summary page name (i.e. what comes after "id=" in the web address): ')

# define the username and password as data to be sent to the FlipperWiki
data=urllib.urlencode({"u" : user, "p" : pword})

# open the Night Summary page for the run
f=urllib.urlopen("http://hercules.berkeley.edu/wiki/doku.php?id="+pagename,data)
lines2=f.readlines()
f.close()
# go through the HTML to find the beginning of the actual wiki page
line_num=0
while lines2[line_num].strip()!='<!-- wikipage start -->':
	line_num += 1 
line_num += 1
while lines2[line_num].strip()=='':
	line_num += 1
# if permission was denied, alert user and end program
if lines2[line_num].find("Permission Denied")!=-1:
	print 'Username/password combination invalid for the FlipperWiki!'
else:
	# loop through the entire table (assuming that all of the observations are listed there)
	while lines2[line_num].strip()!='</table>':

		# assume each table row tag is an image (or run of images)
		if lines2[line_num].find('</td>')!=-1:

			# break line into each table entry
			pieces = lines2[line_num].split('</td>')

			if pieces[2].strip().split('>')[1].strip()!='x':

				# get Obs #
				obs += [pieces[0].strip().split('>')[1].strip()]

				# get Side
				side += [pieces[2].strip().split('>')[1].strip()]

				# get Group
				group += [pieces[3].strip().split('>')[1].strip()]

				# get Type
				type += [pieces[4].strip().split('>')[1].strip()]

		# go to next line
		line_num += 1

	# write to <run_code>.log
	outfile = run + '.log'
	h = open(outfile,'w')

	# write all observations to file and close it
	h.write('Obs     Side  Group  Type\n')
	for n in range(len(obs)):
		h.write(obs[n]+' '*(8-len(obs[n]))+side[n]+' '*(6-len(side[n]))+group[n]+' '*(7-len(group[n]))+type[n]+'\n')
	h.close()

	# print the lists of all fields for error checking
	#for k in range(len(obs)):
	#	print '|'+obs[k]+'|'+side[k]+'|'+group[k]+'|'+type[k]+'|'
