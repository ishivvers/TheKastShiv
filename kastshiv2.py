"""
The Kast Shiv: a Kast spectrocscopic reduction pipeline
 written by I.Shivvers (modified from the K.Clubb/J.Silverman/T.Matheson
 pipeline and the B.Cenko pipeline - thanks everyone).


Notes:
  - wrap as steps with a logger
   - plan: have a class, which has a set of persistent
           variables, which say where in the pipeline you are
           and if you want to skip any steps, etc.
   - class should be iterable, to just run steps in order
   - should be able to start/stop at any point
   - should be able to stop and adjust parameters then go again
"""

import shivutils as su
import os
from glob import glob

class Shiv(object):
    """
    The Kast Shiv: a Kast spectrocscopic reduction pipeline
     written by I.Shivvers (modified from the K.Clubb/J.Silverman/T.Matheson
     pipeline and the B.Cenko pipeline - thanks everyone).
    """
    
    def __init__(self, runID=runID):
        self.runID = runID
        pass
    
    def build_fs(self):
        """Create the file system hierarchy and enter it."""
        su.make_file_system( self.runID )
        os.chdir( self.runID )

    def get_data(self, dateUT, datePT):
        """
        Download data and populate relevant folders.
        Should be run from root folder, and leaves you in working folder.
        """
        os.chdir( 'rawdata' )
        su.get_kast_data( datePT )
        os.chdir( '../working' )
        self.objects, self.flats, self.arcs = su.wiki2elog( datestring=dateUT, runID=self.runID, outfile='%s.log'%self.runID  )
        su.populate_working_dir( 'uc', logfile='%s.log'%self.runID )
    
    def find_trim_sections(self):
        """
        Determine the optimal trim sections for each side.
        """
        obj_files = ["%sblue%.3d.fits" for o in self.objects if o[1]==1 +\
                    ["%sred%.3d.fits" for o in self.objects if o[1]==2]
        # find the trim sections for the red and blue images,
        #  using the first red and blue flats
        firstblueflat = "%sblue%.3d.fits" %(self.runID, [f[0] for f in self.flats if f[1]==1][0])
        self.b_ytrim = su.find_trim_sec( firstblueflat )

        firstredflat = "%sred%.3d.fits" %(self.runID, [f[0] for f in self.flats if f[1]==2][0])
        self.r_ytrim = su.find_trim_sec( firstredflat )

    def trim_and_bias_correct(self):
        """
        Trims and bias corrects all images.
        """
        # bias correct all blue images
        allblues = ["%sblue%.3d.fits"%(runID,f[0]) for f in self.objects+self.flats+self.arcs if f[1]==1]
        su.bias_correct_idl( allblues, self.b_ytrim[0], self.b_ytrim[1] )

        # bias correct all red images
        allreds = ["%sred%.3d.fits"%(runID,f[0]) for f in self.objects+self.flats+self.arcs if f[1]==2]
        su.bias_correct_idl( allreds, self.r_ytrim[0], self.r_ytrim[1] )


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
allgroups = set([o[2] for o in objects])
allgroups.remove(1)    # skip the blues
for i in allgroups:
    redflats = ["b%sred%.3d.fits" %(runID, f[0]) for f in flats if f[2]==i]
    if len(redflats) == 0: continue
    su.make_flat( redflats, 'nflat%d'%i, 'red' )
    reds = ["b%sred%.3d.fits"%(runID,f[0]) for f in objects+arcs if f[1]==i]
    if len(reds) == 0: continue
    su.apply_flat( reds, 'nflat%d'%i )

# perform cosmic ray rejection on all objects
blues = ["fb%sblue%.3d.fits"%(runID,f[0]) for f in objects if f[1]==1]
for b in blues:
    su.clean_cosmics( b, "c%s"%b, 'blue' )
reds = ["fb%sred%.3d.fits"%(runID,f[0]) for f in objects if f[1]==2]
for r in reds:
    su.clean_cosmics( r, "c%s"%r, 'red', maskpath='mc%s'%r )

# extract all red objects on the first pass
extracted_objects = []  #used to keep track of multiple observations of the same object
extracted_images = []
for o in objects:
    if o[1] != 2:
        continue
    r = "cfb%sred%.3d.fits"%(runID,o[0])
    # If we've already extracted a spectrum of this object, use the first extraction
    #  as a reference.
    try:
        reference = extracted_images[ extracted_objects.index( o[3] ) ]
        su.extract( r, 'red', reference=reference )
    except ValueError:
        su.extract( r, 'red' )
    extracted_objects.append( o[3] )
    extracted_images.append( r )
# extract all blue objects on the second pass
for o in objects:
    if o[1] != 1:
        continue
    b = "cfb%sblue%.3d.fits"%(runID,o[0])
    # If we've already extracted a spectrum of this object, use the first extraction
    #  as a reference or apfile reference (accounting for differences in blue and red pixel scales).
    try:
        reference = extracted_images[ extracted_objects.index( o[3] ) ]
        if 'blue' in reference:
            # go ahead and simply use as a reference
            su.extract( b, 'blue', reference=reference )
        elif 'red' in reference:
            # Need to pass along apfile and conversion factor to map the red extraction
            #  onto this blue image. Blue CCD has a plate scale 1.8558 times larger than the red.
            apfile = 'database/ap'+reference.strip('.fits')
            su.extract( b, 'blue', apfile=apfile, apfact=1.8558)
        else:
            raise StandardError( 'We have a situation with aperature referencing.' )
    except ValueError:
        su.extract( b, 'blue' )
    extracted_objects.append( o[3] )
    extracted_images.append( b )


## replacing arcs.cl ##
# extract the blue arc from the beginning of the night
bluearc = ["fb%sblue%.3d.fits"%(runID, f[0]) for f in arcs if f[1]==1][0]
su.extract( bluearc, 'blue', arc=True, reference=blues[0] )

# extract the red arcs, using each associated object as a reference
for i in allgroups:
    redarcs = ["fb%sred%.3d.fits"%(runID, f[0]) for f in arcs if f[2]==i]
    redobj = ["cfb%sred%.3d.fits"%(runID, f[0]) for f in objects if f[2]==i][0]
    for redarc in redarcs:
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
firstobjarc = ["fb%sred%.3d.ms.fits"%(runID, f[0]) for f in arcs if f[2]==2][2]
su.reid_arc( firstobjarc, 'Combined_0.5_Arc.ms.fits')
# now go through all other arcs automatically
allgroups.remove(2)
for i in allgroups:
    objarc = ["fb%sred%.3d.ms.fits"%(runID, f[0]) for f in arcs if f[2]==i][0]
    su.reid_arc( objarc, firstobjarc, interact=False )

# use the correct arcs to dispersion-correct every object
for o in objects:
    if o[1] == 1:
        obj = "cfb%sblue%.3d.ms.fits" %(runID, o[0])
        su.disp_correct( obj, bluearc )
    elif o[1] == 2:
        obj = "cfb%sred%.3d.ms.fits" %(runID, o[0])
        redarcs = ["fb%sred%.3d.ms.fits" %(runID, a[0]) for a in arcs if a[2]==o[2]]
        if o[2] == 2:
            arc = redarcs[2]
        else:
            arc = redarcs[0]
        su.disp_correct( obj, arc )
    else:
        raise StandardError('uh oh')
    

### replacing make_final_input_lists.py ###
allobjects = ["cfb%sblue%.3d.ms.fits"%(runID,o[0]) for o in objects if o[1]==1] +\
             ["cfb%sred%.3d.ms.fits"%(runID,o[0]) for o in objects if o[1]==2]
blue_std_dict, red_std_dict = su.match_science_and_standards( allobjects )

# run cal.pro on the blue side, and then the red #
su.calibrate_idl( blue_std_dict )
su.calibrate_idl( red_std_dict )

# and, finally, run wombat to combine the spectra
print 'run wombat as needed!'
su.start_idl()
