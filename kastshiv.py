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
    
    def __init__(self, runID=runID, interactive=True):
        self.runID = runID
        self.interactive=True  #STILL NEEDS TO BE IMPLEMENTED
    
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

        # define the file lists
        self.robjects = [o for o in self.objects if o[1]==2]
        self.bobjects = [o for o in self.objects if o[1]==1]
        self.rflats = [f for f in self.flats if f[1]==2]
        self.bflats = [f for f in self.flats if f[1]==1]
        self.rarcs = [a for a in self.arcs if a[1]==2]
        self.barcs = [a for a in self.arcs if a[1]==1]

        # define the root filenames for each side
        self.rroot = '%sred'%self.runID + '%.3d.fits'        # before extraction
        self.broot = '%sblue'%self.runID + '%.3d.fits'
        self.erroot = self.rroot.replace('.fits','.ms.fits') # after extraction
        self.ebroot = self.broot.replace('.fits','.ms.fits')
        # define the prefix for current file names
        self.opf = ''  # object
        self.fpf = ''  # flat
        self.apf = ''  # arc

    def find_trim_sections(self):
        """
        Determine the optimal trim sections for each side.
        """
        # find the trim sections for the red and blue images,
        #  using the first red and blue flats
        self.b_ytrim = su.find_trim_sec( self.apf+self.broot%self.barcs[0][0] )
        self.r_ytrim = su.find_trim_sec( self.apf+self.rroot%self.rarcs[0][0] )

    def trim_and_bias_correct(self):
        """
        Trims and bias corrects images.
        """
        assert(self.opf == self.fpf == self.apf)
        blues = [self.opf+self.broot%o[0] for o in self.bobjects+self.bflats+self.barcs]
        su.bias_correct_idl( blues, self.b_ytrim[0], self.b_ytrim[1] )

        reds = [self.opf+self.rroot%o[0]) for o in self.robjects+self.rflats+self.rarcs]
        su.bias_correct_idl( reds, self.r_ytrim[0], self.r_ytrim[1] )

        self.opf = self.fpf = self.apf = 'b'+self.opf

    def update_headers(self):
        """
        Inserts the airmass and optimal PA into the headers for
         each image, along with other header fixes.
        """
        assert(self.opf == self.fpf == self.apf)
        files = [self.opf+self.broot%o[0] for o in self.bobjects+self.bflats+self.barcs] +\
                [self.opf+self.rroot%o[0] for o in self.robjects+self.rflats+self.rarcs]
        su.update_headers( files )

    def make_flats(self):
        """
        Makes combined and normalized flats for each side.
        """
        blues = [self.fpf+self.broot%o[0] for o in self.bflats]
        su.make_flat( blues, 'nflat1', 'blue' )

        # go through and make the combined and normalized red flats for each object
        allgroups = set([o[2] for o in self.objects])
        allgroups.remove(1)    # skip the blues
        for i in allgroups:
            reds = [self.fpf+self.rroot%o[0] for o in self.rflats if o[2]==i]
            if len(redflats) != 0:
                su.make_flat( reds, 'nflat%d'%i, 'red' )

    def apply_flats(self):
        """
        Applies flatfields to each side.
        """
        assert(self.opf == self.apf)
        blues = [self.opf+self.broot%o[0] for o in self.bobjects+self.barcs]
        su.apply_flat( blues, 'nflat1' )

        # go through and apply the correct flat for each object
        allgroups = set([o[2] for o in self.objects])
        allgroups.remove(1)    # skip the blues
        for i in allgroups:
            reds = [self.opf+self.rroot%o[0] for o in self.robjects+self.rarcs if o[2]==i]
            if len(reds) != 0:
                su.apply_flat( reds, 'nflat%d'%i )

        self.opf = self.apf = 'f'+self.opf

    def reject_cosmic_rays(self):
        """
        Performs cosmic ray rejection on all objects.
        """
        blues = [self.opf+self.broot%o[0] for o in self.bobjects]
        for b in blues:
            su.clean_cosmics( b, 'blue' )
        blues = [self.opf+self.rroot%o[0] for o in self.robjects]
        for r in reds:
            su.clean_cosmics( r, 'red' )

        self.opf = 'c'+self.opf

    def extract_object_spectra(self):
        """
        Extracts the spectra from each object.
        """
        # extract all red objects on the first pass
        extracted_objects = []  #used to keep track of multiple observations of the same object
        extracted_images = []
        for o in self.robjects:
            fname = self.opf+self.rroot%o[0]
            # If we've already extracted a spectrum of this object, use the first extraction
            #  as a reference.
            try:
                reference = extracted_images[ extracted_objects.index( o[4] ) ]
                print '\n\nusing',reference,'for reference on',o[4]
                su.extract( fname, 'red', reference=reference )
            except ValueError:
                su.extract( fname, 'red' )
            extracted_objects.append( o[4] )
            extracted_images.append( fname )
        # extract all blue objects on the second pass
        for o in self.bobjects:
            fname = self.opf+self.broot%o[0]
            # If we've already extracted a spectrum of this object, use the first extraction
            #  as a reference or apfile reference (accounting for differences in blue and red pixel scales).
            try:
                reference = extracted_images[ extracted_objects.index( o[4] ) ]
                print '\n\nusing',reference,'for reference on',o[4],'\n'
                if 'blue' in reference:
                    # go ahead and simply use as a reference
                    su.extract( fname, 'blue', reference=reference )
                elif 'red' in reference:
                    # Need to pass along apfile and conversion factor to map the red extraction
                    #  onto this blue image. Blue CCD has a plate scale 1.8558 times larger than the red.
                    apfile = 'database/ap'+reference.strip('.fits')
                    su.extract( fname, 'blue', apfile=apfile, apfact=1.8558)
                else:
                    raise StandardError( 'We have a situation with aperature referencing.' )
            except ValueError:
                su.extract( fname, 'blue' )
            extracted_objects.append( o[4] )
            extracted_images.append( fname )

    def extract_arc_spectra(self):
        """
        Extracts the spectra from each arc.
        """
        # extract the blue arc from the beginning of the night using the first blue
        #  object as the reference
        bluearc = self.apf+self.broot%(self.barcs[0][0])
        refblue = self.opf+self.broot%(self.bobjects[0][0])
        su.extract( bluearc, 'blue', arc=True, reference=refblue )

        # extract the red arcs, using each associated object as a reference
        allgroups = set([o[2] for o in self.objects])
        allgroups.remove(1)    # skip the blues
        for i in allgroups:
            redarcs = [self.apf+self.rroot%o[0] for o in self.rarcs if o[2]==i]
            refred = [self.opf+self.rroot%o[0] for o in objects if o[2]==i][0]
            for redarc in redarcs:
                su.extract( redarc, 'red', arc=True, reference=refred )

    def id_arcs(self):
        """
        Go through and identify and fit for the lines in all arc files.
        """
        # ID the blue side arc
        bluearc = self.apf+self.ebroot%(self.barcs[0][0])
        su.id_arc( bluearc )

        # sum the R1 and R2 red arcs from the beginning of the night and id the result
        R1R2 = [self.apf+self.erroot%o[0] for o in arcs][:2]
        su.combine_arcs( R1R2, 'Combined_0.5_Arc.ms.fits' )
        su.id_arc( 'Combined_0.5_Arc.ms.fits' )

        # ID the first red object arc interactively, making sure
        #  we handle the 0.5" arcs properly
        firstobjarc = [self.apf+self.erroot%o[0] for o in arcs][2]
        su.reid_arc( firstobjarc, 'Combined_0.5_Arc.ms.fits')

        # now go through all other red arcs automatically
        allgroups = set([o[2] for o in self.objects])
        allgroups.remove(1)    # skip the blues
        allgroups.remove(2)    # and the first object's arcs
        for i in allgroups:
            objarc = [self.apf+self.erroot%o[0] for o in self.rarcs if o[2]==i][0]
            su.reid_arc( objarc, firstobjarc, interact=False )

    def apply_wavelength(self):
        """
        Apply the relevant wavelength solution to each object.
        """
        bluearc = self.apf+self.ebroot%(self.barcs[0][0])
        for o in self.bobjects:
            su.disp_correct( self.opf+self.ebroot%o[0], bluearc )

        for o in self.robjects:
            # first red object includes the beginning arcs; account for that
            redarcs = [self.apf+self.ebroot%a[0] for a in self.rarcs if a[2]==o[2]]
            if o[2] == 2:
                redarc = redarcs[2]
            else:
                redarc = redarcs[0]
            su.disp_correct( self.opf+self.erroot%o[0], redarc )

    def flux_calibrate(self):
        """
        Determine and apply the relevant flux calibration to all objects.
        """
        # match objects to standards take at the closest airmass
        allobjects = [self.opf+self.ebroot%o[0] for o in self.bobjects] +\
                     [self.opf+self.erroot%o[0] for o in self.robjects]
        blue_std_dict, red_std_dict = su.match_science_and_standards( allobjects )
        # apply flux calibrations
        su.calibrate_idl( blue_std_dict )
        su.calibrate_idl( red_std_dict )
