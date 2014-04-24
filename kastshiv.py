"""
The Kast Shiv: a Kast spectrocscopic reduction pipeline
 written by I.Shivvers (modified from the K.Clubb/J.Silverman/T.Matheson
 pipeline and the B.Cenko pipeline - thanks everyone).


Notes:
 - for now simply incorporate IDL routines, do not replace them
 - automate absolutely everything you can
 - have a switch with three options:
  1) show every plot and confirm along the way
  2) save every plot for later inspection
  3) create no plots, just do everything
 - include a decorator that logs every step
 - use log to make it so you can pick up and resume
   a reduction from any failure point
 - automate the file structure management
 
Plan:
 - have this be a run-in-place script that does everything in
   a row, and then update with logging, etcetera.
"""

import shivutil as su
import os

# setup the file hierarchy, download the data, and move it around
runID = 'uc'
dateUT = '2013/5/17'
datePT = '2013/5/16'

su.make_file_system( runID )
os.chdir( 'rawdata' )
su.get_kast_data( datePT )
os.chdir( '../working' )
su.wiki2elog( dateUT, runID )
os chdir( '..' )
su.populate_working_dir( 'uc', logfile='working/%s.log'%runID )


# find the trim sections for the red and blue images,
#  using the first red and blue flats
os.chdir( 'working' )
objects, flats, arcs = su.parse_logfile( '%s.log'%runID )

firstblueflat = [f[0] for f in flats if f[1]==1][0]
b_y1, b_y2 = find_trim_sec( '%sblue%.3d.fits'%(runID, firstblueflat) )

firstredflat = [f[0] for f in flats if f[1]==2][0]
r_y1, r_y2 = find_trim_sec( '%sred%.3d.fits'%(runID, firstredflat) )


# bias correct all blue images
allblues = ["%sblue%.3d.fits"%(runID,f[0]) for f in objects+flats+arcs if f[1]==1]
su.bias_correct_idl( allblues, b_y1, b_y2 )

# bias correct all red images
allreds = ["%sred%.3d.fits"%(runID,f[0]) for f in objects+flats+arcs if f[1]==2]
su.bias_correct_idl( allreds, r_y1, r_y2 )


