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
from glob import glob

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

firstblueflat = "%sblue%.3d.fits" %(runID, [f[0] for f in flats if f[1]==1][0])
b_y1, b_y2 = find_trim_sec( firstblueflat )

firstredflat = "%sred%.3d.fits" %(runID, [f[0] for f in flats if f[1]==2][0])
r_y1, r_y2 = find_trim_sec( '%sred%.3d.fits'%(runID, firstredflat) )


# bias correct all blue images
allblues = ["%sblue%.3d.fits"%(runID,f[0]) for f in objects+flats+arcs if f[1]==1]
su.bias_correct_idl( allblues, b_y1, b_y2 )

# bias correct all red images
allreds = ["%sred%.3d.fits"%(runID,f[0]) for f in objects+flats+arcs if f[1]==2]
su.bias_correct_idl( allreds, r_y1, r_y2 )


## replacing startred.cl ##
# set airmass and fix a few header values
allfiles = glob("b%s*.fits" %runID)
su.update_headers( allfiles )

# make the combined and normalized blue flat
blueflats = ["b%sblue%.3d.fits" %(runID, f[0]) for f in flats if f[1]==1]
su.make_flat( blueflats, 'nflat1', 'blue' )
# and apply it
blues = ["b%sblue%.3d.fits"%(runID,f[0]) for f in objects+arcs if f[1]==1]
su.apply_flat( blues, 'nflat1' )

# go through and make the combined and normalied red flats for each object, and apply them
for i in range(2, max( [o[2] for o in objects] )+1):
    redflats = ["b%sred%.3d.fits" %(runID, f[0]) for f in flats if f[2]==i]
    su.make_flat( redflats, 'nflat%d'%i, 'red' )
    reds = ["b%sred%.3d.fits"%(runID,f[0]) for f in objects+arcs if f[1]==i]
    su.apply_flat( reds, 'nflat%d'%i )

# extract all of the objects
blues = ["fb%sblue%.3d.fits"%(runID,f[0]) for f in objects if f[1]==1]
for b in blues:
    su.extract( b, 'blue' )
reds = ["fb%sred%.3d.fits"%(runID,f[0]) for f in objects if f[1]==2]
for r in reds:
    su.extract( r, 'red' )

## replacing arcs.cl ##
# extract the blue arc from the beginning of the night
bluearc = ["fb%sblue%.3d.fits"%(runID, f[0]) for f in arcs if f[1]==1][0]
su.extract( bluearc, 'blue', arc=True, reference=blues[0] )

# extract the red arcs, using each associated object as a reference
for i in range(2, max( [o[2] for o in objects] )+1):
    redarc = ["fb%sred%.3d.fits"%(runID, f[0]) for f in arcs if f[2]==i][0]
    redobj = ["fb%sred%.3d.fits"%(runID, f[0]) for f in objects if f[2]==i][0]
    su.extract( redarc, 'red', arc=True, reference=redobj )

# ID the blue side arc
bluearc = ["fb%sblue%.3d.ms.fits"%(runID, f[0]) for f in arcs if f[1]==1][0]
su.id_arc( bluearc )

# sum the R1 and R2 red arcs from the beginning of the night and id the result
R1R2 = ["fb%sred%.3d.ms.fits"%(runID, f[0]) for f in arcs if f[2]==2][:2]
su.combine_arcs( R1R2, 'Combined_0.5_Arc.ms.fits' )
su.id_arc( 'Combined_0.5_Arc.ms.fits' )

# ID the first object arc interactively, making sure
#  we handle the 0.5" arcs properly
firstobjarc = ["fb%sred%.3d.ms.fits"%(runID, f[0]) for f in arcs if f[2]==i][2]
su.reid_arc( firstobjarc, 'Combined_0.5_Arc.ms.fits')
# now go through all other arcs automatically
for i in range(3, max( [o[2] for o in objects] )+1):
    objarc = ["fb%sred%.3d.ms.fits"%(runID, f[0]) for f in arcs if f[2]==i][0]
    su.reid_arc( objarc, firstobjarc, interactive=False )

# use the correct arcs to dispersion-correct every object
for o in objects:
    if o[1] == 1:
        obj = "fb%sblue%.3d.ms.fits" %(runID, side, o[0])
        su.disp_correct( obj, bluearc )
    elif o[1] == 2:
        obj = "fb%sred%.3d.ms.fits" %(runID, side, o[0])
        arc = ["fb%sred%.3d.ms.fits" %(runID, a[0]) for a in arcs if a[2]==o[2]][0]
        su.disp_correct( obj, arc )
    else:
        raise StandardError('uh oh')
    
    


