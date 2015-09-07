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
import numpy as np

class Shiv(object):
    """
    The Kast Shiv: a Kast spectrocscopic reduction pipeline
     written by I.Shivvers (modified from the K.Clubb/J.Silverman/T.Matheson
     pipeline and the B.Cenko pipeline - thanks everyone).
    """
    
    def __init__(self, runID, interactive=False, savefile=None, logfile=None,
                 datePT=None, dateUT=None, inlog=None, pagename=None):
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

        # set up the logfile
        if logfile == None:
            self.logfile = os.path.abspath('.') + '/' + self.runID+'.reduction.log'
        else:
            self.logfile = logfile
        self.build_log()

        self.steps = [self.build_fs,
                      self.get_data,
                      self.move_data,
                      self.define_lists,
                      self.find_trim_sections,
                      self.trim_and_bias_correct,
                      self.update_headers,
                      self.make_flats,
                      self.apply_flats,
                      self.reject_cosmic_rays,
                      self.calc_seeing,
                      self.extract_object_spectra,
                      self.extract_arc_spectra,
                      self.id_arcs,
                      self.apply_wavelength,
                      self.flux_calibrate,
                      self.coadd_join_output]
        self.current_step = 0

        self.extracted_images = [[],[]]  #[red,blue]; used to keep track of multiple observations of the same object

    def __iter__(self):
        return self
    
    def next(self, *args, **kwargs):
        if self.current_step < len(self.steps):
            self.steps[ self.current_step ]( *args, **kwargs )
            self.current_step += 1
            self.save()
            self.summary()
        else:
            raise StopIteration

    def skip(self):
        """Skip the current step and move on"""
        self.log.info('skipping '+self.steps[self.current_step].__name__)
        self.go_to( self.current_step +1 )
        self.summary()

    def go_to(self, step=None):
        """
        Go to a specific step.  If step number is given, goes there, otherwise
         requires interaction.
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
        if self.current_step <= self.steps.index( self.trim_and_bias_correct ):
            # have not yet changed any prefixes
            self.opf = ''
            self.apf = ''
            self.fpf = ''
        elif self.steps.index( self.trim_and_bias_correct ) < self.current_step <= self.steps.index( self.apply_flats ):
            # have performed bias correction
            self.opf = 'b'
            self.apf = 'b'
            self.fpf = 'b'
        elif self.steps.index( self.apply_flats ) < self.current_step <= self.steps.index( self.reject_cosmic_rays ):
            # have performed bias correction and flatfielding
            self.opf = 'fb'
            self.apf = 'fb'
            self.fpf = 'b'
        elif self.steps.index( self.reject_cosmic_rays ) < self.current_step <= self.steps.index( self.apply_wavelength ):
            # have performed bias correction, flatfielding, and cosmic ray removal
            self.opf = 'cfb'
            self.apf = 'fb'
            self.fpf = 'b'
        elif self.steps.index( self.apply_wavelength ) < self.current_step:
            # have performed bias correction, flatfielding, and cosmic ray removal, and performed a dispersion correction
            self.opf = 'dcfb'
            self.apf = 'fb'
            self.fpf = 'b'

    def save(self):
        """
        Saves pickle of self variables to self.savefile.
        """
        vs = copy(vars(self))
        # can't save functions or open files
        vs.pop('steps')
        vs.pop('log')
        pickle.dump(vs, open(self.savefile,'w'))

    def load(self, savefile=None):
        """
        Loads variables from pickled savefile.
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
        Required to start the log.
        """
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
        """
        Prints a summary of the current state of the reduction.
        """
        print '\n'+'-'*40+'\n'
        print 'Reduction state for Kast run',self.runID
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
        self.summary()

    def run(self, skips=[]):
        while True:
            if self.current_step in skips:
                self.skip()
            else:
                self.next()

    def remove_object(self, objname):
        """
        Will, from here on out, ignore all files associated
         with objname.
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
    
    def build_lists(self, logfile=None):
        """
        Creates the intermediate lists for objects, arcs, and flats.
        Must be run at the beginning, and every time the self.objects/arcs/flats lists are modified.
        If a logfile path is given, will rebuild all lists from that logfile.
        """
        if logfile:
            self.objects, self.arcs, self.flats = su.wiki2elog( runID=self.runID, infile=logfile )
        # re-define the file lists
        self.robjects = [o for o in self.objects if o[1]==2]
        self.bobjects = [o for o in self.objects if o[1]==1]
        self.rflats = [f for f in self.flats if f[1]==2]
        self.bflats = [f for f in self.flats if f[1]==1]
        self.rarcs = [a for a in self.arcs if a[1]==2]
        self.barcs = [a for a in self.arcs if a[1]==1]

    def print_list(self, lll):
        """
        Given a list, print it along with it's indices.

        E.G.:
        > S = Shiv()
        > ...
        > S.print_list( S.robjects )
        """
        for i,f in enumerate(lll):
            print i,':::',f

    ################################################################

    def build_fs(self):
        """
        Create the file system hierarchy and enter it.
        """
        self.log.info('Creating file system for run %s'%self.runID)
        su.make_file_system( self.runID )
        print 'Moving into %s directory'%self.runID
        os.chdir( self.runID )

    def get_data(self, datePT=None, creds=None):
        """
        Download data and populate relevant folders.  Requires local (Pacific) time string
         as an argument (e.g.: '2014/12/24').  You can optionally include login
         credentials for the data server in the form of (un, pw).
        Should be run from root folder, and leaves you in working folder.
        """
        if datePT == None:
            datePT = self.datePT
        print 'Moving into rawdata directory.'
        self.log.info('Downloading data for %s'%datePT)
        os.chdir( 'rawdata' )
        if creds == None:
            su.get_kast_data( datePT )
        else:
            su.get_kast_data( datePT, un=creds[0], pw=creds[1] )
        print 'Moving into working directory'
        os.chdir( '../working' )

    def move_data(self, dateUT=None, logfile=None, pagename=None):
        """
        Takes raw data and populates the working directory properly.
        If logfile is given, uses that to link fits files.  Otherwise downloads the 
         data from the wiki (using the UT date string argument or a given pagename).
        Must be run from working directory.
        """
        if logfile == None:
            logfile = self.inlog
        if dateUT == None:
            dateUT = self.dateUT
        if pagename == None:
            pagename = self.pagename

        if (logfile == None) and (dateUT != None or pagename != None):
            # first check the wiki page
            if not pagename:
                date = date_parser.parse(datestring)
                pagename = "%d_%.2d_kast_%s" %(date.month, date.day, self.runID)
            print 'Running log check...'
            check_log.check_log( pagename=pagename, path_to_files='../rawdata/' )
            self.objects, self.arcs, self.flats = su.wiki2elog( datestring=dateUT, runID=self.runID, outfile='%s.log'%self.runID, pagename=pagename  )
            su.populate_working_dir( self.runID, logfile='%s.log'%self.runID )
        elif logfile != None:
            print 'Running log check...'
            check_log.check_log( localfile=logfile, path_to_files='../rawdata/' )
            self.objects, self.arcs, self.flats = su.wiki2elog( datestring=dateUT, runID=self.runID, infile=logfile )
            su.populate_working_dir( self.runID, logfile=logfile )
        else:
            raise StandardError( 'Improper arguments! Need one of logfile or dateUT' )

    def define_lists(self, logfile=None):
        """
        Parses the output of wiki2elog into the formats needed here;
         must have self.objects, self.flats, self.arcs defined (output of wiki2elog).
        If given a logfile path, will use that logfile to build the lists (useful when
            restarting an aborted run.)
        """
        self.log.info('Populating file lists from log')
        # define the file lists
        self.build_lists( logfile=logfile )

        # define the root filenames for each side
        self.rroot = '%sred'%self.runID + '%.3d.fits'        # before extraction
        self.broot = '%sblue'%self.runID + '%.3d.fits'
        self.erroot = self.rroot.replace('.fits','.ms.fits') # after extraction
        self.ebroot = self.broot.replace('.fits','.ms.fits')
        # define the prefixes for current file names
        self.opf = ''  # object
        self.apf = ''  # arc
        self.fpf = ''  # flat

    def find_trim_sections(self):
        """
        Determine the optimal trim sections for each side.
        """
        self.log.info('Fitting for optimal trim sections')
        # find the trim sections for the red and blue images,
        #  using the first red and blue flats
        self.b_ytrim = su.find_trim_sec( self.apf+self.broot%self.bflats[0][0], plot=self.interactive )
        self.r_ytrim = su.find_trim_sec( self.apf+self.rroot%self.rflats[0][0], plot=self.interactive )
        self.log.info( '\nBlue trim section: (%.4f, %.4f) \nRed trim section: (%.4f, %.4f)'%(self.b_ytrim[0],
                                                           self.b_ytrim[1], self.r_ytrim[0], self.r_ytrim[0]) )

    def trim_and_bias_correct(self):
        """
        Trims and bias corrects images.
        """
        self.log.info('Trimming and bias correcting all images')
        assert(self.opf == self.fpf == self.apf)
        blues = [self.opf+self.broot%o[0] for o in self.bobjects+self.bflats+self.barcs]
        su.bias_correct( blues, self.b_ytrim[0], self.b_ytrim[1] )

        reds = [self.opf+self.rroot%o[0] for o in self.robjects+self.rflats+self.rarcs]
        su.bias_correct( reds, self.r_ytrim[0], self.r_ytrim[1] )

        self.log.info( '\nApplied trim section (%.4f, %.4f) to following files:\n'%(self.b_ytrim[0], self.b_ytrim[1])+',\n'.join(blues) )
        self.log.info( '\nApplied trim section (%.4f, %.4f) to following files:\n'%(self.r_ytrim[0], self.r_ytrim[1])+',\n'.join(reds) )
        self.opf = 'b'# b for bias-subtracted
        self.apf = 'b' 
        self.fpf = 'b'

    def update_headers(self):
        """
        Inserts the airmass and optimal PA into the headers for
         each image, along with other header fixes.
        """
        self.log.info('Updating headers of all images')
        assert(self.opf == self.fpf == self.apf)
        files = [self.opf+self.broot%o[0] for o in self.bobjects+self.bflats+self.barcs] +\
                [self.opf+self.rroot%o[0] for o in self.robjects+self.rflats+self.rarcs]
        su.update_headers( files, reducer=su.REDUCER )

    def make_flats(self):
        """
        Makes combined and normalized flats for each side.
        """
        self.log.info('Creating flats')
        blues = [self.fpf+self.broot%o[0] for o in self.bflats]
        su.make_flat( blues, 'nflat1', 'blue', interactive=self.interactive )
        self.log.info( '\nCreated flat nflat1 out of the following files:\n'+',\n'.join(blues) )

        # go through and make the combined and normalized red flats for each object
        allgroups = set([o[2] for o in self.objects])
        allgroups.remove(1)    # skip the blues
        for i in allgroups:
            reds = [self.fpf+self.rroot%o[0] for o in self.rflats if o[2]==i]
            if len(reds) != 0:
                su.make_flat( reds, 'nflat%d'%i, 'red', interactive=self.interactive )
                self.log.info( '\nCreated flat nflat%d out of the following files:\n'%i+',\n'.join(reds) )

    def apply_flats(self):
        """
        Applies flatfields to each side.
        """
        self.log.info('Applying flatfield correction to all images')
        assert(self.opf == self.apf)
        blues = [self.opf+self.broot%o[0] for o in self.bobjects+self.barcs]
        su.apply_flat( blues, 'nflat1' )
        self.log.info( '\nApplied flat nflat1 to the following files:\n'+',\n'.join(blues) )

        # go through and apply the correct flat for each object
        allgroups = set([o[2] for o in self.objects])
        allgroups.remove(1)    # skip the blues
        for i in allgroups:
            reds = [self.opf+self.rroot%o[0] for o in self.robjects+self.rarcs if o[2]==i]
            if len(reds) != 0:
                su.apply_flat( reds, 'nflat%d'%i )
                self.log.info( '\nApplied flat nflat%d to the following files:\n'%i+',\n'.join(reds) )

        self.opf = 'fb' # f for flatfielded
        self.apf = 'fb'

    def reject_cosmic_rays(self):
        """
        Performs cosmic ray rejection on all objects.
        """
        self.log.info("Perfoming cosmic ray removal")
        blues = [self.opf+self.broot%o[0] for o in self.bobjects]
        for b in blues:
            su.clean_cosmics( b, 'blue', plot=self.interactive )
        self.log.info( '\nRemoved cosmic rays from the following files:\n'+',\n'.join(blues) )
        reds = [self.opf+self.rroot%o[0] for o in self.robjects]
        for r in reds:
            su.clean_cosmics( r, 'red', plot=self.interactive )
        self.log.info( '\nRemoved cosmic rays from the following files:\n'+',\n'.join(reds) )

        self.opf = 'cfb'  # c for cosmic-ray removal

    def calc_seeing(self):
        """
        Calculate the seeing for all objects and insert values into their header.
        """
        self.log.info("Calculating seeing for all objects")
        allobjects = [self.opf+self.broot%o[0] for o in self.bobjects] +\
                     [self.opf+self.rroot%o[0] for o in self.robjects]
        su.calculate_seeing( allobjects, plot=self.interactive )

    def extract_object_spectra(self, side=['red','blue']):
        """
        Extracts the spectra from each object.  Cannot be run automatically.
        """
        self.log.info('Extracting spectra for red objects')
        # extract all red objects on the first pass
        if 'red' in side:
            for o in self.robjects:
                fname = self.opf+self.rroot%o[0]
                # If we've already extracted this exact file, move on.
                if fname in [extracted[0] for extracted in self.extracted_images[0]]:
                    print fname,'has already been extracted. Remove from self.extracted_images '+\
                                'list if you want to run it again.'
                    continue
                # If we've already extracted a spectrum of this object, use it as a reference
                irefs = [ i for i in range(len(self.extracted_images[0])) if self.extracted_images[0][i][1]==o[4] ]
                if len(irefs) == 0:
                    reference = None
                else:
                    reference = self.extracted_images[0][irefs[0]]

                # give the user some choice here
                print '\nCurrent image:',fname
                inn = raw_input('\nView image with ds9? [y/n](n):\n')
                if 'y' in inn.lower():
                    os.system('ds9 -scale log -geometry 1200x600 %s &' %fname)
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
                    self.log.info('Extracted '+fname)
                else:
                    su.extract( fname, 'red', reference=reference[0] )
                    self.log.info('Used ' + reference[0] + ' for reference on '+ fname +' (objects: '+reference[1]+' ::: '+o[4]+')')

                self.extracted_images[0].append( [fname,o[4]] )
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
                # If we've already extracted a blue spectrum of this object, use it for reference.
                #  If we've extracted a red spectrum, use its apfile for reference,
                #  accounting for differences in blue and red pixel scales.
                blue_irefs = [ i for i in range(len(self.extracted_images[1])) if self.extracted_images[1][i][1]==o[4] ]
                red_irefs = [ i for i in range(len(self.extracted_images[0])) if self.extracted_images[0][i][1]==o[4] ]
                if len(blue_irefs) == len(red_irefs) == 0:
                    reference = None
                elif len(blue_irefs) != 0:
                    # default to the first blue image 
                    reference = self.extracted_images[1][blue_irefs[0]]
                else:
                    reference = self.extracted_images[0][red_irefs[0]]
                
                # give the user some choice here
                print '\nCurrent image:',fname
                inn = raw_input('\nView image with ds9? [y/n](n):\n')
                if 'y' in inn.lower():
                    os.system('ds9 -scale log -geometry 1200x600 -zoom 0.6 %s &' %fname)
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
                        self.log.info('Used ' + reference[0] + ' for reference on '+ fname +' (objects: '+reference[1]+' ::: '+o[4]+')')
                    else:
                        # Need to pass along apfile and conversion factor to map the red extraction
                        #  onto this blue image. Blue CCD has a plate scale 1.8558 times larger than the red.
                        apfile = 'database/ap'+reference[0].strip('.fits')
                        su.extract( fname, 'blue', apfile=apfile, interact=True )
                        self.log.info('Used apfiles from ' + reference[0] + ' for reference on '+ fname +' (objects: '+reference[1]+' ::: '+o[4]+')')

                self.extracted_images[1].append( [fname,o[4]] )
                self.save()

    def extract_object_special(self, side, iobject, **kwargs):
        """
        Run a special extraction on a file.
         side can be 'red' or 'blue'
         iobject is the index of the self.?objects list to extract.
        The function Shiv.print_list( list ) can be helpful:
         > S = Shiv()
         > ...
         > S.print_list( S.robjects )
        
        A few quick examples:
        >> extract using a trace from another image:
         > S.extract_object_special( <side>, <iobject>, reference=<reference_image>, edit=S.yes, trace=S.no, fittrace=S.no )
        >> extract using a different x location to define the aperture:
         > S.extract_object_special( <side>, <iobject>, line=<line #> )
        
        All possible kwargs are listed on the IRAF page for apall:
         http://stsdas.stsci.edu/cgi-bin/gethelp.cgi?apall.hlp
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
        if (side == 'red') and (fname not in [extracted[0] for extracted in self.extracted_images[0]]):
            self.extracted_images[0].append( [fname,o[4]] )
        if (side == 'blue') and (fname not in [extracted[0] for extracted in self.extracted_images[1]]):
            self.extracted_images[1].append( [fname,o[4]] )

    def splot(self, filename ):
        """
        Use iraf's splot to view a 1d fits file spectrum
        """
        su.iraf.splot( filename )

    def extract_arc_spectra(self):
        """
        Extracts the spectra from each arc.
        """
        self.log.info('Extracting arc spectra')
        # extract the blue arc from the beginning of the night using the first blue
        #  object as the reference
        bluearc = self.apf+self.broot%(self.barcs[0][0])
        refblue = self.opf+self.broot%(self.bobjects[0][0])
        su.extract( bluearc, 'blue', arc=True, reference=refblue )
        self.log.info('Extracted blue arc spectrum '+bluearc+' using '+refblue+' as a reference')

        # extract the red arcs, using each associated object as a reference
        allgroups = set([o[2] for o in self.objects])
        allgroups.remove(1)    # skip the blues
        for i in allgroups:
            redarcs = [self.apf+self.rroot%o[0] for o in self.rarcs if o[2]==i]
            refred = [self.opf+self.rroot%o[0] for o in self.robjects if o[2]==i][0]
            for redarc in redarcs:
                su.extract( redarc, 'red', arc=True, reference=refred )
                self.log.info('Extracted red arc spectrum '+redarc+' using '+refred+' as a reference')

    def id_arcs(self):
        """
        Go through and identify and fit for the lines in all arc files. Requires
         human interaction.
        """
        self.log.info("Identifying arc lines and fitting for wavelength solutions")
        # ID the blue side arc
        su.run_cmd( 'xdg-open %s'%su.BLUEARCIMG, ignore_errors=True )
        bluearc = self.apf+self.ebroot%(self.barcs[0][0])
        su.id_arc( bluearc, side='b' )
        self.log.info("Successfully ID'd "+bluearc)

        # sum the R1 and R2 red arcs from the beginning of the night and id the result
        su.run_cmd( 'xdg-open %s'%su.REDARCIMG, ignore_errors=True )
        R1R2 = [self.apf+self.erroot%o[0] for o in self.rarcs][:2]
        su.combine_arcs( R1R2, 'Combined_0.5_Arc.ms.fits' )
        self.log.info("Created Combined_0.5_Arc.ms.fits from "+str(R1R2))
        su.id_arc( 'Combined_0.5_Arc.ms.fits', side='r' )
        self.log.info("Successfully ID'd Combined_0.5_Arc.ms.fits" )

        # ID the first red object arc interactively, making sure
        #  we handle the 0.5" arcs properly
        firstobjarc = [self.apf+self.erroot%o[0] for o in self.rarcs][2]
        su.reid_arc( firstobjarc, 'Combined_0.5_Arc.ms.fits')
        self.log.info("ID'd "+firstobjarc+" using Combined_0.5_Arc.ms.fits as a reference")

        # Now go through all other red arcs, using the result of the above step to calibrate them.
        allgroups = set([o[2] for o in self.objects])
        allgroups.remove(1)    # skip the blues
        allgroups.remove( self.robjects[0][2] )    # and skip the first object's arcs
        for i in allgroups:
            objarc = [self.apf+self.erroot%o[0] for o in self.rarcs if o[2]==i][0]
            su.reid_arc( objarc, firstobjarc )
            self.log.info("ID'd "+objarc+" using "+firstobjarc+" as a reference")

    def apply_wavelength(self, force=False):
        """
        Apply the relevant wavelength solution to each object.
        If force==True, will delete previous file before applying solution.
        """
        self.log.info("Appying wavelength solution to all objects")
        bluearc = self.apf+self.ebroot%(self.barcs[0][0])
        for o in self.bobjects:
            image = self.opf+self.ebroot%o[0]
            if force:
                su.run_cmd( 'rm d%s'%image, ignore_errors=True )
            su.disp_correct( image, bluearc )
            self.log.info("Applied wavelength solution from "+bluearc+" to "+self.opf+self.ebroot%o[0])

        for o in self.robjects:
            # first red object includes the beginning arcs; account for that
            redarcs = [self.apf+self.erroot%a[0] for a in self.rarcs if a[2]==o[2]]
            if o[2] == 2:
                redarc = redarcs[2]
            else:
                redarc = redarcs[0]
            image = self.opf+self.erroot%o[0]
            if force:
                su.run_cmd( 'rm d%s'%image, ignore_errors=True )
            su.disp_correct( image, redarc )
            self.log.info("Applied wavelength solution from "+redarc+" to "+self.opf+self.erroot%o[0])
        self.opf = 'dcfb' # d for dispersion-corrected

    def flux_calibrate(self, side=None):
        """
        Determine and apply the relevant flux calibration to all objects. Requires
         human interaction.
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
        Coadds any multiple observations of the same science object,
         joins the red and blue sides of each observation, and then saves
         the result as an ASCII (.flm) file.
        If globstr is given, only processes files that include that glob string (example: glob='sn2014ds').
        Requires human interaction.
        """
        if globstr != '':
            globstr = '*'+globstr
        allfiles = glob(globstr+'*[(uv)(ir)].ms.fits')
        # ignore fitsfiles for which there exists a *.flm file
        allflms = glob('*.flm')
        for f in allflms:
            objname = f.split('-')[0]
            for ff in allfiles:
                if re.search( objname, ff ):
                    print ff,'already run. Ignoring.'
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
        Coadd a set of files.  If given globstr, will coadd all files
         that match it.  If given files (a list), will coadd those files.
         Only accepts fits files as an argument.
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

    def join(self, files=None, globstr=None, ftype='fits', outf=None):
        """
        Join red+blue sides of a set of files.  If given globstr, looks for red (ir) and
         blue (uv) versions with that globstring.  If given files (a list of [blue, red]),
         will simply join those. ftype can be one of ["fits" or "flm"].
        If outf is given, will save file (in .flm ascii format) to that filename.
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
        """
        Plot and inspect all *.flm files (the final outputs).
        """
        finals = glob( '*.flm' )
        for f in finals:
            su.plot_spectra( *np.loadtxt(f, unpack=True), title=f, savefile=f.replace('.flm', '.png') )

    def plt_flm(self, f):
        """
        Plot the flm file <f>.
        """
        su.plot_spectra( *np.loadtxt(f, unpack=True), title=f, savefile=f.replace('.flm', '.png') )

    def blotch_spectrum(self, f, outf=None):
        """
        Blotch out bad regions in flm file <f>, saving the result to outf.
        """
        su.blotch_spectrum(f, outf)
