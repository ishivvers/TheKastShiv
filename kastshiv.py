"""
The Kast Shiv: a Kast spectrocscopic reduction pipeline
 written by I.Shivvers (modified from the K.Clubb/J.Silverman/R.Foley/R.Chornock/T.Matheson
 pipeline and the B.Cenko pipeline - thanks everyone).

"""

import shivutils as su
yes = su.yes
no = su.no
import os
import re
import logging
import pickle
from tools import check_log
from glob import glob
from copy import copy
try:
    from pathos import multiprocessing
    PARALLEL = True
except ImportError as e:
    print 'ERROR:',e
    print 'Multi-core usage not available.'
    PARALLEL = False
import numpy as np

class Shiv(object):
    """
    The Kast Shiv: a Kast spectrocscopic reduction pipeline
     written by I.Shivvers (modified from the K.Clubb/J.Silverman/T.Matheson
     pipeline and the B.Cenko pipeline - thanks everyone).
    """
    
    def __init__(self, runID, interactive=False, savefile=None, logfile=None,
                 datePT=None, dateUT=None, inlog=None, pagename=None, parallel=False):
        self.runID = runID
        self.interactive = interactive
        self.datePT = datePT
        self.dateUT = dateUT
        self.inlog = inlog
        self.pagename = pagename
        # have the iraf yes/no variables accessible
        self.yes = su.yes
        self.no = su.no
        if savefile == None:
            self.savefile = os.path.abspath('.') + '/' + self.runID + '.sav'
        else:
            self.savefile = savefile
        if PARALLEL and parallel:
            self.parallel = True
        else:
            self.parallel = False

        self.steps = [self.build_fs,
                      self.get_data,
                      self.move_data,
                      self.define_lists,
                      self.bias_correct,  
                      self.reject_cosmic_rays,
                      self.rotate_red, 
                      self.find_trim_sections, 
                      self.trim, 
                      self.update_headers,
                      self.make_flats,
                      self.apply_flats,
                      self.calc_seeing,
                      self.extract_object_spectra,
                      self.extract_arc_spectra,
                      self.id_arcs,
                      self.apply_wavelength,
                      self.flux_calibrate,
                      self.coadd_join_output]
        self.current_step = 0

        self.extracted_images = [[],[]]  #[red,blue]; used to keep track of multiple observations of the same object

        # load from savefile, if it exists locally
        if os.path.exists( self.savefile ):
            inn = raw_input('Load saved state from {}? (y/n)[y]\n'.format(self.savefile) )
            if 'n' not in inn.lower():
                self.load()

        # set up the logfile
        if logfile == None:
            self.logfile = os.path.abspath('.') + '/' + self.runID+'.reduction.log'
        else:
            self.logfile = logfile
        self.build_log()


    def __iter__(self):
        return self
    
    def next(self, *args, **kwargs):
        """
        Runs the next step in the pipeline.
        Any arguments given here are passed along directly
        to the next step.
        """
        if self.current_step < len(self.steps):
            self.steps[ self.current_step ]( *args, **kwargs )
            self.current_step += 1
            self.save()
            self.summary()
        else:
            raise StopIteration

    def skip(self):
        """ Skip the current step and move on to the next one. """
        self.log.info('skipping '+self.steps[self.current_step].__name__)
        self.go_to( self.current_step +1 )
        self.summary()

    def go_to(self, step=None):
        """
        Go to a specific step in the reduction pipeline.  
    
        Keyword arguments:
        step -- Integer; if given, goes there, otherwise
                asks user for interaction.
        """
        if type(step) == int:
            self.current_step = step
            self.summary()
        else:
            self.summary()
            print '\nChoose one:'
            for i,s in enumerate(self.steps):
                print i,':::',s.__name__
            self.current_step = int(raw_input())
            self.summary()
        # handle the prefixes properly
        if self.current_step <= self.steps.index( self.bias_correct ):
            # have not yet changed any prefixes
            self.opf = ''
            self.apf = ''
            self.fpf = ''
        elif self.steps.index( self.bias_correct ) < self.current_step <= self.steps.index( self.reject_cosmic_rays ):
            # have performed bias correction
            self.opf = 'b'
            self.apf = 'b'
            self.fpf = 'b'
        elif self.steps.index( self.reject_cosmic_rays ) < self.current_step <= self.steps.index( self.trim ):
            # have performed bias correction and and cosmic ray removal
            self.opf = 'cb'
            self.apf = 'b'
            self.fpf = 'b'
        elif self.steps.index( self.trim ) < self.current_step <= self.steps.index( self.apply_flats ):
            # have performed bias correction, and cosmic ray removal, and trimmed
            self.opf = 'tcb'
            self.apf = 'tb'
            self.fpf = 'tb'
        elif self.steps.index( self.apply_flats ) < self.current_step <= self.steps.index( self.apply_wavelength ):
            # have performed bias correction, cosmic ray removal, trimmed, and flatfields
            self.opf = 'ftcb'
            self.apf = 'ftb'
            self.fpf = 'tb'
        elif self.steps.index( self.apply_wavelength ) < self.current_step:
            # have performed bias correction, cosmic ray removal, trimmed, flatfields,
            #  and performed a dispersion correction
            self.opf = 'dftcb'
            self.apf = 'ftb'
            self.fpf = 'tb'

    def save(self):
        """ Saves a pickled copy of all self variables to the savefile. """
        vs = copy(vars(self))
        # can't save functions or open files
        vs.pop('steps')
        vs.pop('log')
        pickle.dump(vs, open(self.savefile,'w'))

    def load(self, savefile=None):
        """
        Loads all self variables from pickled savefile.

        Keyword arguments:
        savefile -- String; path to savefile. If not given, uses default.
        """
        if savefile == None:
            savefile = self.savefile
        vs = pickle.load( open(savefile,'r') )
        for k in vs.keys():
            s = 'self.%s = vs["%s"]' %(k, k)
            exec(s)
        self.summary()

    def build_log(self):
        """
        Performs bookkeeping required to start the log. """
        self.log = logging.getLogger('TheKastShiv')
        self.log.setLevel(logging.INFO)
        # have log messages go to screen and to file
        fh = logging.FileHandler( self.logfile )
        fh.setFormatter( logging.Formatter('%(asctime)s ::: %(message)s') )
        self.log.addHandler(fh)
        sh = logging.StreamHandler()
        sh.setFormatter( logging.Formatter('*'*40+'\n%(levelname)s - %(message)s\n'+'*'*40) )
        self.log.addHandler(sh)
        self.log.info('Shiv Reducer started.')

    def summary(self):
        """ Print a summary of the current state of the reduction. """
        print '\n'+'-'*40+'\n'
        print 'Reduction status for Kast run',self.runID
        print 'Interactive:',self.interactive
        print '\n'+'-'*40+'\n'
        try:
            print 'Current step:',self.steps[self.current_step].__name__
            print self.steps[self.current_step].__doc__
        except IndexError:
            print 'End of reduction pipeline.'
            return
        try:
            print '\nNext step:',self.steps[self.current_step+1].__name__
            print self.steps[self.current_step+1].__doc__
        except IndexError:
            print 'End of reduction pipeline.'

    def status(self):
        """ Print a summary of the current state of the reduction. """
        self.summary()

    def run(self, skips=[]):
        """
        Run all steps, in order, until user interaction is required.

        Keyword arguments:
        skips -- List of integers; if given, will skip those steps
                 with matching indices.
        """
        while True:
            if self.current_step in skips:
                self.skip()
            else:
                self.next()

    def remove_object(self, objname):
        """
        From here on out, ignore all files associated
         with given objname.

        Arguments:
        objname -- String; name of object to ignore.
        """
        to_remove = [o for o in self.objects if o[-1]==objname]
        # find the red group number from these
        group = 1
        for o in to_remove:
            if o[1] == 2:
                group = o[2]
                break
        # remove all the object files
        for row in to_remove:
            self.objects.remove(row)

        # now remove all associated arcs and flats
        if group != 1:
            to_remove = [a for a in self.arcs if a[2]==group]
            for row in to_remove:
                self.arcs.remove(row)
            to_remove = [f for f in self.flats if f[2]==group]
            for row in to_remove:
                self.flats.remove(row)

        # now rebuild the side-specific lists
        self.build_lists()
        self.log.info('Ignoring all files associated with '+objname)
    
    def build_lists(self, obslog=None):
        """
        Creates the intermediate lists for objects, arcs, and flats.
        Must be run at the beginning, and again every time the self.objects/arcs/flats lists are modified.

        Keyword arguments:
        obslog -- String; path to obslog to reference. If not given,
                  will use default. 
        """
        if obslog:
            self.objects, self.arcs, self.flats = su.wiki2elog( runID=self.runID, infile=obslog )
        # re-define the file lists
        self.robjects = [o for o in self.objects if o[1]=='r']
        self.bobjects = [o for o in self.objects if o[1]=='b']
        self.rflats = [f for f in self.flats if f[1]=='r']
        self.bflats = [f for f in self.flats if f[1]=='b']
        self.rarcs = [a for a in self.arcs if a[1]=='r']
        self.barcs = [a for a in self.arcs if a[1]=='b']

    def print_list(self, thislist):
        """
        Given a list, print it along with its indices.
        
        Arguments:
        thislist -- List you want to enumerate and print.
                    For example:
                    > S = Shiv()
                    > ...
                    > S.print_list( S.robjects )
        """
        for i,f in enumerate(thislist):
            print i,':::',f

    ################################################################
    # Steps in the reduction pipeline are defined below.
    ################################################################

    def build_fs(self):
        """ Create the file system hierarchy and enter it. """
        su.make_file_system( self.runID )
        print 'Moving into %s directory'%self.runID
        self.log.info('Created file system for run %s'%self.runID)
        os.chdir( self.runID )

    def get_data(self, datePT=None, creds=None):
        """
        Download data and populate relevant folders.

        Should be run from root folder, but then will leave you in working folder.

        Keyword arguments:
        datePT -- String; the date (in Pacific Time) to download
                  data from. If not given, attempts to use self.datePT.
                  (E.G.: '2014/12/24').
        creds --- Tuple of strings; if given, will override default values
                  for login credentials for Lick data repository.
                  First item must be the data repository
                  username, second must be data repository password.
        """
        if datePT == None:
            datePT = self.datePT
        print 'Moving into rawdata directory.'
        os.chdir( 'rawdata' )
        if creds == None:
            su.get_kast_data( datePT )
        else:
            su.get_kast_data( datePT, un=creds[0], pw=creds[1] )
        print 'Moving into working directory'
        self.log.info('Downloaded data for %s'%datePT)
        os.chdir( '../working' )

    def move_data(self, dateUT=None, obslog=None, pagename=None):
        """
        Populates the working directory properly from the rawdata directory.
        
        Must be run from working directory.

        Keyword arguments:
        obslog -- String; if given a path to a valid obslog file, references it.
                  Otherwise downloads the data from the wiki.
        dateUT -- String; the date (in UTC) to attempt to identify the correct
                  FlipperWiki page. (E.G.: '2014/12/24').
        pagename -- String; the internal wiki URL that defines the page containing
                    the wiki log - i.e the string that follows ?id= in the wiki URL.
                    Overrides dateUT.
                    E.G.: for the page heracles.astro.berkeley.edu/wiki/doku.php?id=09_24_16_kast_zd,
                    the pagename is '09_24_16_kast_zd'
        """
        if obslog == None:
            obslog = self.inlog
        if dateUT == None:
            dateUT = self.dateUT
        if pagename == None:
            pagename = self.pagename

        if (obslog == None) and (dateUT != None or pagename != None):
            # first check the wiki page
            if not pagename:
                date = date_parser.parse(datestring)
                pagename = "%d_%.2d_kast_%s" %(date.month, date.day, self.runID)
            self.objects, self.arcs, self.flats = su.wiki2elog( datestring=dateUT, runID=self.runID, outfile='%s.log'%self.runID, pagename=pagename  )
            obslog = '%s.log'%self.runID
            su.populate_working_dir( self.runID, logfile=obslog )
        elif obslog != None:
            self.objects, self.arcs, self.flats = su.wiki2elog( datestring=dateUT, runID=self.runID, infile=obslog )
            su.populate_working_dir( self.runID, logfile=obslog )
        else:
            raise StandardError( 'Improper arguments! Need one of obslog or dateUT' )
        self.log.info( 'Moved data into working directory; using obslog=%s'%obslog )

    def define_lists(self, obslog=None):
        """
        Parses the output of wiki2elog into the formats needed here.

        Keyword arguments;
        obslog -- String; if given a obslog path, will use that obslog to build the lists,
                  overriding anything previously given.
        """
        # define the file lists
        self.build_lists( obslog=obslog )

        # define the root filenames for each side
        self.rroot = '%sred'%self.runID + '%.3d.fits'        # before extraction
        self.broot = '%sblue'%self.runID + '%.3d.fits'
        self.erroot = self.rroot.replace('.fits','.ms.fits') # after extraction
        self.ebroot = self.broot.replace('.fits','.ms.fits')
        # define the prefixes for current file names
        self.opf = ''  # object
        self.apf = ''  # arc
        self.fpf = ''  # flat
        self.log.info('Populated file lists from log')

    def bias_correct(self):
        """ Bias correct all images using overscan region. """
        blues = [self.opf+self.broot%o[0] for o in self.bobjects+self.bflats+self.barcs]
        su.overscan_bias_correct( blues )

        reds = [self.opf+self.rroot%o[0] for o in self.robjects+self.rflats+self.rarcs]
        su.overscan_bias_correct( reds )
        
        self.log.info( 'Bias corrected the following files:\n'+','.join(blues+reds) )
        self.opf = 'b'# b for bias-subtracted
        self.apf = 'b' 
        self.fpf = 'b'

    def reject_cosmic_rays(self):
        """ Performs cosmic ray rejection on all objects, using L.A.Cosmic. """
        blues = [self.opf+self.broot%o[0] for o in self.bobjects]
        if self.parallel:
            f = lambda b: su.clean_cosmics( b, 'blue', plot=False )
            pool = multiprocessing.ProcessingPool()
            pool.map( f, blues )
        else:
            for b in blues:
                su.clean_cosmics( b, 'blue', plot=self.interactive )

        reds = [self.opf+self.rroot%o[0] for o in self.robjects]
        if self.parallel:
            f = lambda r: su.clean_cosmics( r, 'red', plot=False )
            pool = multiprocessing.ProcessingPool()
            pool.map( f, reds )
        else:
            for r in reds:
                su.clean_cosmics( r, 'red', plot=self.interactive )
        
        self.log.info( 'Removed cosmic rays from the following files:\n'+','.join(blues+reds) )
        self.opf = 'cb'  # c for cosmic-ray removal

    def rotate_red(self, angle=1.0):
        """
        Rotates the red CCD to correct tilted slit orientation, and
        then tranposes the x,y axes to get it aligned as normal (blue to the left).

        Keyword arguments:
        angle -- Float; degrees by which to rotate the image CCW.
        """
        reds = [self.opf+self.rroot%o[0] for o in self.robjects] +\
               [self.apf+self.rroot%o[0] for o in self.rarcs] +\
               [self.fpf+self.rroot%o[0] for o in self.rflats]
        
        su.rotate( reds, angle )
        self.log.info('Rotated following images by {}:\n'.format(angle)+','.join(reds))
        
        su.transpose( reds )
        self.log.info('Transposed X,Y for following images:\n'+','.join(reds))

    def find_trim_sections(self):
        """
        Determine the optimal trim sections for each side (in the Y dimension).
        These sections are saved as self.b_ytrim and self.r_ytrim,
        if you would like to modify them by hand before running self.trim().
        """
        # find the trim sections for the red and blue images,
        #  using the first red and blue flats
        self.b_ytrim = su.find_trim_sec( self.apf+self.broot%self.bflats[0][0], plot=self.interactive )
        self.r_ytrim = su.find_trim_sec( self.apf+self.rroot%self.rflats[0][0], plot=self.interactive )
        self.log.info( '\nBlue trim section: (%.4f, %.4f) \nRed trim section: (%.4f, %.4f)'%(self.b_ytrim[0],
                                                           self.b_ytrim[1], self.r_ytrim[0], self.r_ytrim[0]) )

    def trim(self):
        """
        Trims all images in the y dimension, using parameters
        self.b_ytrim and self.r_ytrim.
        """
        blues = [self.opf+self.broot%o[0] for o in self.bobjects] +\
               [self.apf+self.broot%o[0] for o in self.barcs] +\
               [self.fpf+self.broot%o[0] for o in self.bflats]
        su.trim( blues, y1=self.b_ytrim[0], y2=self.b_ytrim[1] )

        reds = [self.opf+self.rroot%o[0] for o in self.robjects] +\
               [self.apf+self.rroot%o[0] for o in self.rarcs] +\
               [self.fpf+self.rroot%o[0] for o in self.rflats]
        su.trim( reds, y1=self.r_ytrim[0], y2=self.r_ytrim[1] )

        self.log.info( '\nApplied y trim section (%.4f, %.4f) to following files:\n'%(self.b_ytrim[0], self.b_ytrim[1])+','.join(blues) )
        self.log.info( '\nApplied y trim section (%.4f, %.4f) to following files:\n'%(self.r_ytrim[0], self.r_ytrim[1])+','.join(reds) )
        self.opf = 'tcb'# t for bias-subtracted
        self.apf = 'tb' 
        self.fpf = 'tb'

    def update_headers(self):
        """
        Inserts the airmass and optimal PA into the headers for
        each image, along with some other header fixes.
        """
        blues = [self.opf+self.broot%o[0] for o in self.bobjects] +\
               [self.apf+self.broot%o[0] for o in self.barcs] +\
               [self.fpf+self.broot%o[0] for o in self.bflats]
        reds = [self.opf+self.rroot%o[0] for o in self.robjects] +\
               [self.apf+self.rroot%o[0] for o in self.rarcs] +\
               [self.fpf+self.rroot%o[0] for o in self.rflats]
        su.update_headers( blues+reds, reducer=su.REDUCER )
        self.log.info('Updated headers of all images')

    def make_flats(self, bflat='bflat', rflat='rflat'):
        """
        Makes combined and normalized flats for each side.

        Keyword arguments:
        bflat -- String; name of combined and normalized blue flat file.
        rflat -- String; name of combined and normalized red flat file.
        """
        blues = [self.fpf+self.broot%o[0] for o in self.bflats]
        su.make_flat( blues, bflat, 'blue', interactive=self.interactive )
        self.bflat = bflat
        self.log.info( '\nCreated flat image {}.fits out of the following files:\n'.format(bflat)+','.join(blues) )

        reds = [self.fpf+self.rroot%o[0] for o in self.rflats]
        su.make_flat( reds, rflat, 'red', interactive=self.interactive )
        self.rflat = rflat
        self.log.info( '\nCreated flat image {}.fits out of the following files:\n'.format(rflat)+','.join(reds) )

    def apply_flats(self, bflat=None, rflat=None):
        """
        Applies flatfields to each side.

        Keyword arguments:
        bflat: String; path to blue-side flatfile to use. If not given,
               uses default of self.bflat.
        rflat: String; path to red-side flatfile to use. If not given,
               uses default of self.rflat.
        """
        if bflat != None:
            self.bflat = bflat
        if rflat != None:
            self.rflat = rflat

        blues = [self.opf+self.broot%o[0] for o in self.bobjects] +\
                [self.apf+self.broot%o[0] for o in self.barcs]
        su.apply_flat( blues, self.bflat )
        self.log.info( '\nApplied flat {} to the following files:\n'.format(self.bflat)+','.join(blues) )

        reds = [self.opf+self.rroot%o[0] for o in self.robjects] +\
               [self.apf+self.rroot%o[0] for o in self.rarcs]
        su.apply_flat( reds, self.rflat )
        self.log.info( '\nApplied flat {} to the following files:\n'.format(self.rflat)+','.join(reds) )

        self.opf = 'ftcb' # f for flatfielded
        self.apf = 'ftb'

    def calc_seeing(self):
        """ Estimate the seeing for all objects and insert values into their header. """
        allobjects = [self.opf+self.broot%o[0] for o in self.bobjects] +\
                     [self.opf+self.rroot%o[0] for o in self.robjects]
        su.calculate_seeing( allobjects, plot=self.interactive )
        self.log.info("Estimated seeing for all objects")

    def extract_object_spectra(self, side=['red','blue']):
        """
        Extracts the spectra from all objects.  Cannot be run automatically.

        Keyword arguments:
        side -- List of strings or a string; can be one of:
                'red', 'blue', or ['red','blue'].
                The side from which to extract spectra.
        """
        if type(side) != list:
            side = list(side)
        self.interactive = True
        # extract all red objects on the first pass
        if 'red' in side:
            for o in self.robjects:
                fname = self.opf+self.rroot%o[0]
                # If we've already extracted this exact file, move on.
                if fname in [extracted[0] for extracted in self.extracted_images[0]]:
                    print fname,'has already been extracted. Remove from self.extracted_images '+\
                                'list if you want to run it again.'
                    continue
                self.log.info('Extracting spectrum from {}'.format(fname))
                # If we've already extracted a spectrum of this object, use it as a reference
                irefs = [ i for i in range(len(self.extracted_images[0])) if self.extracted_images[0][i][1]==o[3] ]
                if len(irefs) == 0:
                    reference = None
                else:
                    reference = self.extracted_images[0][irefs[0]]

                # give the user some choice here
                print '\nCurrent image:',fname
                print 'Object:', o[-1]
                # inn = raw_input('\nView image with ds9? [y/n](n):\n')
                # if 'y' in inn.lower():
                    # os.system('ds9 -scale log -geometry 1200x600 %s &' %fname)
                os.system('ds9 -scale zscale -geometry 1200x600 %s &' %fname)
                for iref in irefs:
                    reference = self.extracted_images[0][iref]
                    print
                    print fname,':::',o[-1]
                    print reference[0],':::',reference[1]
                    inn = raw_input( '\nUse %s as a reference for %s?: [y/n](y)\n' %(reference[0], fname) )
                    if 'n' not in inn.lower():
                        break
                    reference = None
                
                if reference == None:
                    su.extract( fname, 'red', interact=True )
                else:
                    su.extract( fname, 'red', reference=reference[0] )
                    self.log.info('Used ' + reference[0] + ' for reference on '+ fname +' (objects: '+reference[1]+' ::: '+o[3]+')')

                self.extracted_images[0].append( [fname,o[3]] )
                self.save()

        # extract all blue objects on the second pass
        if 'blue' in side:
            for o in self.bobjects:
                fname = self.opf+self.broot%o[0]
                # If we've already extracted this exact file, move on.
                if fname in [extracted[0] for extracted in self.extracted_images[1]]:
                    print fname,'has already been extracted. Remove from self.extracted_images '+\
                                'list if you want to run it again.'
                    continue
                self.log.info('Extracting spectrum from {}'.format(fname))
                # If we've already extracted a blue spectrum of this object, use it for reference.
                #  If we've extracted a red spectrum, use its apfile for reference,
                #  accounting for differences in blue and red pixel scales.
                blue_irefs = [ i for i in range(len(self.extracted_images[1])) if self.extracted_images[1][i][1]==o[3] ]
                red_irefs = [ i for i in range(len(self.extracted_images[0])) if self.extracted_images[0][i][1]==o[3] ]
                if len(blue_irefs) == len(red_irefs) == 0:
                    reference = None
                elif len(blue_irefs) != 0:
                    # default to the first blue image 
                    reference = self.extracted_images[1][blue_irefs[0]]
                else:
                    reference = self.extracted_images[0][red_irefs[0]]
                
                # give the user some choice here
                print '\nCurrent image:',fname
                print 'Object:', o[-1]
                # inn = raw_input('\nView image with ds9? [y/n](n):\n')
                # if 'y' in inn.lower():
                    # os.system('ds9 -scale log -geometry 1200x600 -zoom 0.6 %s &' %fname)
                os.system('ds9 -scale zscale -geometry 1200x600 -zoom 0.6 %s &' %fname)
                blueref = False
                # choose from blue references first
                for iref in blue_irefs:
                    reference = self.extracted_images[1][iref]
                    print
                    print fname,':::',o[-1]
                    print reference[0],':::',reference[1]
                    inn = raw_input( 'Use %s as a reference for %s? [y/n](y)\n' %(reference[0], fname) )
                    if 'n' not in inn.lower():
                        blueref = True
                        break
                    reference = None
                if not blueref:
                    # next try the reds
                    for iref in red_irefs:
                        reference = self.extracted_images[0][iref]
                        print
                        print fname,':::',o[-1]
                        print reference[0],' :::',reference[1]
                        inn = raw_input( 'Use %s as a reference for %s? [y/n](y)\n' %(reference[0], fname) )
                        if 'n' not in inn.lower():
                            break
                        reference = None

                if reference == None:
                    su.extract( fname, 'blue', interact=self.interactive )
                else:
                    if blueref:
                        # go ahead and simply use as a reference
                        su.extract( fname, 'blue', reference=reference[0], interact=True )
                        self.log.info('Used ' + reference[0] + ' for reference on '+ fname +' (objects: '+reference[1]+' ::: '+o[3]+')')
                    else:
                        # Need to pass along apfile and conversion factor to map the red extraction
                        #  onto this blue image. Blue CCD has a plate scale 1.8558 times larger than the red.
                        apfile = 'database/ap'+os.path.splitext(reference[0])[0]
                        su.extract( fname, 'blue', apfile=apfile, interact=True )
                        self.log.info('Used apfiles from ' + reference[0] + ' for reference on '+ fname +' (objects: '+reference[1]+' ::: '+o[3]+')')

                self.extracted_images[1].append( [fname,o[3]] )
                self.save()

    def extract_object_special(self, side, iobject, **kwargs):
        """
        Run a special extraction on a file.  Any kwargs given are
        passed along to iraf.apall().
        All possible kwargs are listed on the IRAF page for apall:
        http://stsdas.stsci.edu/cgi-bin/gethelp.cgi?apall.hlp
         
        Arguments:
        side --- String; can be one of 'red' or 'blue'.
        iobject -- Integer; the index of the object to extract, in the
                   relevant internal list (self.robjects or self.bobjects).
                   The function Shiv.print_list( list ) can be helpful to
                   find the correct index:
                   > S = Shiv()
                   > ...
                   > S.print_list( S.robjects )
        
        A few quick examples:
         > S = kastshiv.Shiv(<id>)
         > ...
        >> extract using a trace from another image:
         > S.extract_object_special( <side>, <iobject>, reference=<reference_image>, edit=S.yes, trace=S.no, fittrace=S.no )
        >> extract using a different x location to define the aperture:
         > S.extract_object_special( <side>, <iobject>, line=<line #> )
        """
        if side == 'red':
            o = self.robjects[iobject]
            fname = self.opf+self.rroot%o[0]
        elif side == 'blue':
            o = self.bobjects[iobject]
            fname = self.opf+self.broot%o[0]
        else:
            raise StandardError('Side must be one of "red", "blue"')

        su.extract( fname, side, interact=True, **kwargs )
        self.log.info('Extracting spectrum from {} using custom parameters'.format(fname))
        if (side == 'red') and (fname not in [extracted[0] for extracted in self.extracted_images[0]]):
            self.extracted_images[0].append( [fname,o[3]] )
        if (side == 'blue') and (fname not in [extracted[0] for extracted in self.extracted_images[1]]):
            self.extracted_images[1].append( [fname,o[3]] )

    def redo_extraction(self, objname, side=['red','blue']):
        """
        Remove images of the object from self.extracted_images list, so
        that running self.extract_object_spectra() will re-extract all spectra
        of that object.

        Arguments:
        objname -- String; exact object name to re-extract.
                   If given "all", will forget about all objects.

        Keyword arguments:
        side -- String or list of strings; Which sides to re-extract.
                can be one of 'red', 'blue', or ['red','blue'].
        """
        if objname == 'all':
            self.extracted_images = [[],[]]
        else:
            smap = {'red':0,'blue':1}
            if type(side) != list:
                side = list(side)
            for s in side:
                i = smap[s]
                newlist = []
                for row in self.extracted_images[i]:
                    if row[1] != objname:
                        newlist.append( row )
                self.extracted_images[i] = newlist

    def splot(self, filename ):
        """
        Use iraf's splot to view a 1D fits file spectrum.
        
        Arguments:
        filename -- String; path to file to examine.
        """
        su.iraf.splot( filename )

    def extract_arc_spectra(self, refblue=None, refred=None):
        """
        Extracts the spectra from each arc.

        Keyword arguments:
        refblue -- String; path to blue-side reference image for defining
                   the trace. If not given, uses the trace of the first object.
        refred -- String; path to red-side reference image for defining
                   the trace. If not given, uses the trace of the first object.
        """
        # extract the blue arcs using the first blue object as the reference
        bluearcs = [self.apf+self.broot%o[0] for o in self.barcs]
        if len(bluearcs) > 1:
            raise Exception('Found more than one blue arc image!')
        bluearc = bluearcs[0]
        if refblue == None:
            refblue = self.opf+self.broot%(self.bobjects[0][0])
        su.extract( bluearc, 'blue', arc=True, reference=refblue )
        self.log.info('Extracted blue arc spectrum '+bluearc+' using '+refblue+' as a reference')

        # extract the red arcs using the first red object as the reference
        redarcs = [self.apf+self.rroot%o[0] for o in self.rarcs]
        if refred == None:
            refred = self.opf+self.rroot%(self.robjects[0][0])
        for redarc in redarcs:
            su.extract( redarc, 'red', arc=True, reference=refred )
            self.log.info('Extracted red arc spectrum '+redarc+' using '+refred+' as a reference')

    def id_arcs(self, combined_red_name='Combined_0.5_Arc.ms.fits'):
        """
        Go through and identify and fit for the lines in all arc files.
        Requires human interaction.

        Keyword arguments: 
        combined_red_name -- String; path of red-side combined arc image
                             (combination of first 2 arc images, which
                             should be of the R1 and R2 arclamp sets).
        """
        # ID the blue side arc; define which one we'll use
        #  to calibrate later on
        bluearcs = [self.apf+self.broot%o[0] for o in self.barcs]
        if len(bluearcs) > 1:
            raise Exception('Found more than one blue arc image!')
        inn = raw_input('\nView the blue arc lamp reference image? (y/n)[y]\n')
        if 'n' not in inn.lower():
            su.run_cmd( 'xdg-open %s'%su.BLUEARCIMG, ignore_errors=True )
        
        self.bluearc = bluearcs[0]
        su.id_arc( self.bluearc, side='b' )
        self.log.info("Successfully ID'd arc lamp lines from "+self.bluearc)

        # sum the R1 and R2 red arcs from the beginning of the night and id the result
        R1R2 = [self.apf+self.erroot%o[0] for o in self.rarcs][:2]
        su.combine_arcs( R1R2, combined_red_name )
        self.log.info( "Created {} from {}".format(combined_red_name,R1R2) )
        inn = raw_input('\nView the red arc lamp reference image? (y/n)[y]\n')
        if 'n' not in inn.lower():
            su.run_cmd( 'xdg-open %s'%su.REDARCIMG, ignore_errors=True )
        self.redarc = combined_red_name
        su.id_arc( self.redarc, side='r' )
        self.log.info("Successfully ID'd arc lamp lines from "+self.redarc)


    def apply_wavelength(self, force=True):
        """
        Apply the relevant wavelength solution to each object.

        Keyword arguments:
        force -- Boolean; if True, will forcibly over-write previously 
                 determined wavelength solutions.
        """
        for o in self.bobjects:
            image = self.opf+self.ebroot%o[0]
            if force:
                su.run_cmd( 'rm d%s'%image, ignore_errors=True )
            su.disp_correct( image, self.bluearc )
            self.log.info("Applied wavelength solution from "+self.bluearc+" to "+self.opf+self.ebroot%o[0])

        red = self.apf+self.ebroot%(self.barcs[0][0])
        for o in self.robjects:
            image = self.opf+self.erroot%o[0]
            if force:
                su.run_cmd( 'rm d%s'%image, ignore_errors=True )
            su.disp_correct( image, self.redarc )
            self.log.info("Applied wavelength solution from "+self.redarc+" to "+self.opf+self.ebroot%o[0])

        self.opf = 'dftcb' # d for dispersion-corrected

    def flux_calibrate(self, side=None):
        """
        Determine and apply the relevant flux calibration to all objects.
        Uses T.Matheson's IDL code, and requires human interaction.
        Must be run from the working directory, but then leaves the user 
        in the final directory.

        Keyword arguments:
        side -- String; side to flux calibrate. Can be one of 'red', 'blue'.
                If not given, calibrates both sides, starting with blue.
        """
        # keep track of the files we create here, and move them to ../final
        starting_files = glob('*.fits')
        self.log.info("Flux calibrating all objects")
        # match objects to standards take at the closest airmass
        allobjects = [self.opf+self.ebroot%o[0] for o in self.bobjects] +\
                     [self.opf+self.erroot%o[0] for o in self.robjects]
        blue_std_dict, red_std_dict = su.match_science_and_standards( allobjects )

        # don't bother calibrating any standards that will not be used
        for k in blue_std_dict.keys():
            if len(blue_std_dict[k]) == 0:
                blue_std_dict.pop(k)
        for k in red_std_dict.keys():
            if len(red_std_dict[k]) == 0:
                red_std_dict.pop(k)

        tmp = blue_std_dict.copy()
        tmp.update(red_std_dict)
        for k in tmp.keys():
            self.log.info( "\nAssociated the following files with standard "+k+":\n"+',\n'.join(tmp[k]) )

        # apply flux calibrations
        if side in ['blue',None]:
            su.calibrate_idl( blue_std_dict )
            self.log.info( "Applied flux calibrations to blue objects" )
        if side in ['red',None]:
            su.calibrate_idl( red_std_dict )
            self.log.info( "Applied flux calibrations to red objects" )

        ending_files = glob('*.fits')
        for f in ending_files:
            if (f not in starting_files) and (f[:5] != 'cdcfb'):
                su.run_cmd(' mv %s ../final/.' %f )
        print 'Moving to final directory.'
        os.chdir( '../final' )

    def coadd_join_output(self, globstr=''):
        """
        Coadds multiple observations of the same science object,
        joins the red and blue sides of each observation, and then saves
        the result as an ASCII (.flm) file.
        Requires human interaction.

        Keyword arguments:
        globstr -- String; If given, only processes files that include that
                   glob string (example: glob='sn2014ds').
        """
        if globstr != '':
            globstr = '*'+globstr
        allfiles = glob(globstr+'*[(uv)(ir)].ms.fits')
        toremove = []
        # ignore fitsfiles for which there exists a *.flm file
        allflms = glob('*.flm')
        for f in allflms:
            datestr = re.search('\d{8}', f).group()
            objname = f.split(datestr)[0].strip('-')
            print
            print objname
            for ff in allfiles:
                if objname in ff:
                    print ff,'already run. Ignoring.'
                    print '(To re-run, delete flm file and try again.)'
                    toremove.append(ff)
        for ff in toremove:
            allfiles.remove( ff )

        while True:
            ## choose the file to do
            print '\nFiles remaining to process:'
            for i,f in enumerate(allfiles):
                if 'uv' in f:
                    print i,':::',f
            inn = raw_input('\n Choose the number of a spectrum to coadd/join, or q to quit\n')
            if 'q' in inn.lower():
                break
            else:
                try:
                    which = int(inn)
                except ValueError:
                    print '\nWhat?\n'
                    continue
            f = allfiles[which]
            if 'uv' in f:
                fblue = f
                fred = f.replace('uv','ir')
            elif 'ir' in f:
                fred = f
                fblue = f.replace('ir','uv')
            else:
                raise Exception('Unknown naming scheme.')
            namedate = re.search('.*\d{8}', f).group()
            
            # find all the blues, and coadd them
            bluematches = glob( namedate + '*' + 'uv.ms.fits' )
            if len(bluematches) > 1:
                inn = raw_input( 'Combine the following files: \n'+str(bluematches)+'? [y/n] (y):\n' )
                if 'n' not in inn:
                    # need to update the filename to show that it was averaged
                    # assumes that all were observed on the same day
                    f_timestr = re.search( '\.\d{3}', fblue ).group()
                    avg_time = np.mean( [float(re.search('\.\d{3}', fff).group()) for fff in bluematches] )
                    new_timestr = ('%.3f'%avg_time)[1:] #drop the leading 0
                    fblue = fblue.replace( f_timestr, new_timestr )
                    blue = list(su.coadd( bluematches, fname=fblue ))
                    self.log.info( 'Coadded the following files: '+str(bluematches))
                else:
                    print 'Choose which file you want:'
                    for i,f in enumerate(bluematches): print i,':::',f
                    inn = raw_input('Enter a number, or q to quit\n')
                    if 'q' in inn:
                        continue
                    else:
                        try:
                            fblue = bluematches[int(inn)]
                            blue = list(su.read_calfits( fblue ))
                        except ValueError:
                            print '\nWhat?\n'
                            continue
            elif len(bluematches) == 1:
                fblue = bluematches[0]
                blue = list(su.read_calfits( fblue ))
            else:
                raise Exception('Found no blue file!')
            
            # find all the reds, and coadd them
            redmatches = glob( namedate + '*' + 'ir.ms.fits' )
            if len(redmatches) > 1:
                inn = raw_input( 'Combine the following files: \n'+str(redmatches)+'? [y/n] (y):\n' )
                if 'n' not in inn:
                    # need to update the filename to show that it was averaged
                    # assumes that all were observed on the same day
                    f_timestr = re.search( '\.\d{3}', fred ).group()
                    avg_time = np.mean( [float(re.search('\.\d{3}', fff).group()) for fff in redmatches] )
                    new_timestr = ('%.3f'%avg_time)[1:] #drop the leading 0
                    fred = fred.replace( f_timestr, new_timestr )
                    red = list(su.coadd( redmatches, fname=fred ))
                    self.log.info( 'Coadded the following files: '+str(redmatches))
                else:
                    print 'Choose which file you want:'
                    for i,f in enumerate(redmatches): print i,':::',f
                    inn = raw_input('Enter a number, or q to quit\n')
                    if 'q' in inn:
                        continue
                    else:
                        try:
                            fred = redmatches[int(inn)]
                            red = list(su.read_calfits( fred ))
                        except ValueError:
                            print '\nWhat?\n'
                            continue
            elif len(redmatches) == 1:
                fred = redmatches[0] 
                red = list(su.read_calfits( fred ))
            else:
                raise Exception('Found no red file!')

            # join the blue and red sides
            inn = raw_input('\nJoin %s and %s? [y/n] (y)\n' %(fblue, fred) )
            if 'n' in inn.lower():
                continue
            wl,fl,er = su.join( blue, red, interactive=self.interactive )
            self.log.info('Joined '+fblue+' to '+fred)
            output_name = fred.replace('ir','ui').replace('.ms.fits','.flm')
            
            # should we save the result?
            su.plot_spectra( wl,fl,er, title=namedate )
            inn = raw_input('Save ' + namedate + ' to file: %s? [y/n] (y)\n'%output_name)
            if 'n' in inn.lower():
                continue
            su.np2flm( output_name, wl,fl,er )
            self.log.info( namedate+' saved to file '+output_name )
            
            # only drop from the list if we got all the way through and successfully saved it
            allfiles = [f for f in allfiles if namedate not in f]

    def coadd(self, files=None, globstr=None):
        """
        Coadd a set of files.

        Keyword arguments:
        files -- List; if given, will coadd those files.
        globstr -- String; if given, will coadd all files
                   with filenames that match the string.
        """
        if 'globstr' != None:
            files = glob('*'+globstr+'*')
        
        inn = raw_input('\n Co-add the following files? \n'+str(files)+\
                         '\n [y/n] (y):\n')
        if 'n' not in inn.lower():
            f_timestr = re.search( '\.\d{3}', files[0] ).group()
            avg_time = np.mean( [float(re.search('\.\d{3}', fff).group()) for fff in files] )
            new_timestr = ('%.3f'%avg_time)[1:] #drop the leading 0
            fname = files[0].replace( f_timestr, new_timestr )
            wl,fl,er = su.coadd( files, fname=fname )
            self.log.info( 'Co-addition of %s saved to file %s'%(str(files), fname) )
            return wl,fl,er

    def join(self, files=None, globstr=None, ftype='fits', outf=None):
        """
        Join red+blue sides of a set of files.

        Keyword arguments:
        files -- List of strings; the files to join together. Must be like: [blue_file, red_file]
        globstr -- String; if given, looks for red (ir) and
                   blue (uv) versions of all files that match that globstring,
                   and will join them.
        ftype --- String; ftype can be one of ["fits" or "flm"].
        outf -- String; if given, will save result (in .flm ascii format) to that filename.
        """
        if globstr != None:
            if ftype == 'fits':
                allfiles = glob('*'+globstr+'*.fits')
            elif ftype == 'flm':
                allfiles = glob('*'+globstr+'*.flm')
            else:
                raise Exception('ftype must be one of "fits", "flm"')
            red = [f for f in allfiles if re.search('ir', f) ][0]
            blue = [f for f in allfiles if re.search('uv', f) ][0]
        else:
            blue, red = files
        inn = raw_input('\n Join the following files? \n  UV: %s\n  IR: %s\n [y/n] (y):\n' %(str(blue), str(red)))
        if 'n' not in inn:
            if ftype == 'fits':
                red = list(su.read_calfits( red ))
                blue = list(su.read_calfits( blue ))
            else:
                red = np.loadtxt(red, unpack=True)
                blue = np.loadtxt(blue, unpack=True)
            wl,fl,er = su.join( blue, red, interactive=self.interactive )
        if outf != None:
            su.np2flm( outf, wl,fl,er )
        return wl,fl,er

    def plt_flams(self):
        """ Plot and inspect all *.flm files (the final outputs). """
        finals = glob( '*.flm' )
        for f in finals:
            su.plot_spectra( *np.loadtxt(f, unpack=True), title=f, savefile=f.replace('.flm', '.png') )

    def plt_flm(self, f):
        """
        Plot the flm file.

        Arguments:
        f -- String; path to file (in ascii, .flm format) to plot.
        """
        su.plot_spectra( *np.loadtxt(f, unpack=True), title=f, savefile=f.replace('.flm', '.png') )

    def blotch_spectrum(self, f, outf=None):
        """
        Interactively blotch out (i.e. mask) bad regions in a flm file.
        
        Arguments:
        f -- String; path to file (in ascii, .flm format) to blotch.

        Keyword arguments:
        outf -- String; path to output file of result. If not given,
                overwrites the input file.
        """
        su.blotch_spectrum(f, outf)
