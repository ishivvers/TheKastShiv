"""
The Kast Shiv: a Kast spectrocscopic reduction pipeline
 written by I.Shivvers (modified from the K.Clubb/J.Silverman/T.Matheson
 pipeline and the B.Cenko pipeline - thanks everyone).

to do: 
 - change file management at end, so finished files are moved
    to ../final after fluxcal, and then we move to that folder
    before running wombat

"""

import shivutils as su
import os
import re
import logging
import pickle
from glob import glob
from copy import copy
import numpy as np

class Shiv(object):
    """
    The Kast Shiv: a Kast spectrocscopic reduction pipeline
     written by I.Shivvers (modified from the K.Clubb/J.Silverman/T.Matheson
     pipeline and the B.Cenko pipeline - thanks everyone).
    """
    
    def __init__(self, runID, interactive=True, savefile=None, logfile=None,
                 datePT=None, dateUT=None, inlog=None, pagename=None):
        self.runID = runID
        self.interactive = interactive
        self.datePT = datePT
        self.dateUT = dateUT
        self.inlog = inlog
        self.pagename = pagename
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
                      self.extract_object_spectra,
                      self.extract_arc_spectra,
                      self.id_arcs,
                      self.apply_wavelength,
                      self.flux_calibrate,
                      self.coadd_join_output]
        self.current_step = 0

        self.extracted_objects = []  #used to keep track of multiple observations of the same object
        self.extracted_images = []

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
        self.current_step +=1
        print 'next:',self.steps[self.current_step].__name__

    def go_to_step(self, step=None):
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
    
    def build_lists(self):
        """
        Creates the intermediate lists for objects, arcs, and flats.
        Must be run at the beginning, and every time the self.objects/arcs/flats lists are modified.
        """
        # re-define the file lists
        self.robjects = [o for o in self.objects if o[1]==2]
        self.bobjects = [o for o in self.objects if o[1]==1]
        self.rflats = [f for f in self.flats if f[1]==2]
        self.bflats = [f for f in self.flats if f[1]==1]
        self.rarcs = [a for a in self.arcs if a[1]==2]
        self.barcs = [a for a in self.arcs if a[1]==1]

    ################################################################

    def build_fs(self):
        """
        Create the file system hierarchy and enter it.
        """
        self.log.info('Creating file system for run %s'%self.runID)
        su.make_file_system( self.runID )
        os.chdir( self.runID )

    def get_data(self, datePT=None):
        """
        Download data and populate relevant folders.  Requires local (Pacific) time string
         as an argument (e.g.: '2014/12/24')
        Should be run from root folder, and leaves you in working folder.
        """
        if datePT == None:
            datePT = self.datePT
        self.log.info('Downloading data for %s'%datePT)
        os.chdir( 'rawdata' )
        su.get_kast_data( datePT )
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
            self.objects, self.arcs, self.flats = su.wiki2elog( datestring=dateUT, runID=self.runID, outfile='%s.log'%self.runID, pagename=pagename  )
            su.populate_working_dir( self.runID, logfile='%s.log'%self.runID )
        elif logfile != None:
            self.objects, self.arcs, self.flats = su.wiki2elog( datestring=dateUT, runID=self.runID, infile=logfile )
            su.populate_working_dir( self.runID, logfile=logfile )
        else:
            raise StandardError( 'Improper arguments! Need one of logfile or dateUT' )

    def define_lists(self):
        """
        Parses the output of wiki2elog into the formats needed here;
         must have self.objects, self.flats, self.arcs defined (output of wiki2elog).
        """
        self.log.info('Populating file lists from log')
        # define the file lists
        self.build_lists()

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
        self.log.info('Fitting for optimal trim sections')
        # find the trim sections for the red and blue images,
        #  using the first red and blue flats
        self.b_ytrim = su.find_trim_sec( self.apf+self.broot%self.bflats[0][0], plot=self.interactive )
        self.r_ytrim = su.find_trim_sec( self.apf+self.rroot%self.rflats[0][0], plot=self.interactive )
        self.log.info( '\nBlue trim section: (%.4f, %.4f) \nRed trim section: (%.4f, %.4f)'%(self.b_ytrim[0], self.b_ytrim[1], self.r_ytrim[0], self.r_ytrim[0]) )

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

        self.opf = self.fpf = self.apf = 'b'+self.opf
        self.log.info( '\nApplied trim section (%.4f, %.4f) to following files:\n'%(self.b_ytrim[0], self.b_ytrim[1])+',\n'.join(blues) )
        self.log.info( '\nApplied trim section (%.4f, %.4f) to following files:\n'%(self.r_ytrim[0], self.r_ytrim[1])+',\n'.join(reds) )

    def update_headers(self):
        """
        Inserts the airmass and optimal PA into the headers for
         each image, along with other header fixes.
        """
        self.log.info('Updating headers of all images')
        assert(self.opf == self.fpf == self.apf)
        files = [self.opf+self.broot%o[0] for o in self.bobjects+self.bflats+self.barcs] +\
                [self.opf+self.rroot%o[0] for o in self.robjects+self.rflats+self.rarcs]
        su.update_headers( files )

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

        if self.opf[0] != self.apf[0] != 'f':
            self.opf = self.apf = 'f'+self.opf

    def reject_cosmic_rays(self):
        """
        Performs cosmic ray rejection on all objects.
        """
        self.log.info("Perfoming cosmic ray removal")
        blues = [self.opf+self.broot%o[0] for o in self.bobjects]
        for b in blues:
            su.clean_cosmics( b, 'blue' )
        self.log.info( '\nRemoved cosmic rays from the following files:\n'+',\n'.join(blues) )
        reds = [self.opf+self.rroot%o[0] for o in self.robjects]
        for r in reds:
            su.clean_cosmics( r, 'red' )
        self.log.info( '\nRemoved cosmic rays from the following files:\n'+',\n'.join(reds) )

        if self.opf[0] != 'c':
            self.opf = 'c'+self.opf

    def extract_object_spectra(self, side=['red','blue']):
        """
        Extracts the spectra from each object.
        """
        self.log.info('Extracting spectra for red objects')
        # extract all red objects on the first pass
        if 'red' in side:
            for o in self.robjects:
                fname = self.opf+self.rroot%o[0]
                # If we've already extracted this exact file, move on.
                if fname in self.extracted_images:
                    print fname,'has already been extracted. Remove from self.extracted_images '+\
                                'list if you want to run it again.'
                    continue
                # If we've already extracted a spectrum of this object, use the first extraction
                #  as a reference.
                try:
                    reference = self.extracted_images[ self.extracted_objects.index( o[4] ) ]
                except ValueError:
                    reference = None

                if reference == None:
                    su.extract( fname, 'red', interact=self.interactive )
                    self.log.info('Extracted '+fname)
                else:
                    su.extract( fname, 'red', reference=reference )
                    self.log.info('Used ' + reference + ' for reference on '+ fname +' (object: '+o[4]+')')

                self.extracted_objects.append( o[4] )
                self.extracted_images.append( fname )
                self.save()
        # extract all blue objects on the second pass
        if 'blue' in side:
            for o in self.bobjects:
                fname = self.opf+self.broot%o[0]
                # If we've already extracted this exact file, move on.
                if fname in self.extracted_images:
                    print fname,'has already been extracted. Remove from self.extracted_images '+\
                                'list if you want to run it again.'
                    continue
                # If we've already extracted a spectrum of this object, use the first extraction
                #  as a reference or apfile reference (accounting for differences in blue and red pixel scales).
                try:
                    reference = self.extracted_images[ self.extracted_objects.index( o[4] ) ]
                except ValueError:
                    reference = None

                if reference == None:
                    su.extract( fname, 'blue', interact=self.interactive )
                else:
                    if 'blue' in reference:
                        # go ahead and simply use as a reference
                        su.extract( fname, 'blue', reference=reference, interac=self.interactive )
                        self.log.info('Used ' + reference + ' for reference on '+ fname +' (object: '+o[4]+')')
                    elif 'red' in reference:
                        # Need to pass along apfile and conversion factor to map the red extraction
                        #  onto this blue image. Blue CCD has a plate scale 1.8558 times larger than the red.
                        apfile = 'database/ap'+reference.strip('.fits')
                        su.extract( fname, 'blue', apfile=apfile, apfact=1.8558, interact=self.interactive )
                        self.log.info('Used apfiles from ' + reference + ' for reference on '+ fname +' (object: '+o[4]+')')
                    else:
                        raise StandardError( 'We have a situation with aperature referencing.' )
                self.extracted_objects.append( o[4] )
                self.extracted_images.append( fname )
                self.save()

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
        Go through and identify and fit for the lines in all arc files.
        """
        self.log.info("Identifying arc lines and fitting for wavelength solutions")
        # ID the blue side arc
        su.run_cmd( 'gnome-open %s'%su.BLUEARCIMG, ignore_errors=True )
        bluearc = self.apf+self.ebroot%(self.barcs[0][0])
        su.id_arc( bluearc )
        self.log.info("Successfully ID'd "+bluearc)

        # sum the R1 and R2 red arcs from the beginning of the night and id the result
        su.run_cmd( 'gnome-open %s'%su.REDARCIMG, ignore_errors=True )
        R1R2 = [self.apf+self.erroot%o[0] for o in self.rarcs][:2]
        su.combine_arcs( R1R2, 'Combined_0.5_Arc.ms.fits' )
        self.log.info("Created Combined_0.5_Arc.ms.fits from "+str(R1R2))
        su.id_arc( 'Combined_0.5_Arc.ms.fits' )
        self.log.info("Successfully ID'd Combined_0.5_Arc.ms.fits" )

        # ID the first red object arc interactively, making sure
        #  we handle the 0.5" arcs properly
        firstobjarc = [self.apf+self.erroot%o[0] for o in self.rarcs][2]
        su.reid_arc( firstobjarc, 'Combined_0.5_Arc.ms.fits')
        self.log.info("ID'd "+firstobjarc+" using Combined_0.5_Arc.ms.fits as a reference")

        # now go through all other red arcs automatically
        allgroups = set([o[2] for o in self.objects])
        allgroups.remove(1)    # skip the blues
        allgroups.remove( self.robjects[0][2] )    # and the first object's arcs
        for i in allgroups:
            objarc = [self.apf+self.erroot%o[0] for o in self.rarcs if o[2]==i][0]
            su.reid_arc( objarc, firstobjarc, interact=False )
            self.log.info("ID'd "+objarc+" using "+firstobjarc+" as a reference")

    def apply_wavelength(self):
        """
        Apply the relevant wavelength solution to each object.
        """
        self.log.info("Appying wavelength solution to all objects")
        bluearc = self.apf+self.ebroot%(self.barcs[0][0])
        for o in self.bobjects:
            su.disp_correct( self.opf+self.ebroot%o[0], bluearc )
            self.log.info("Applied wavelength solution from "+bluearc+" to "+self.opf+self.ebroot%o[0])

        for o in self.robjects:
            # first red object includes the beginning arcs; account for that
            redarcs = [self.apf+self.erroot%a[0] for a in self.rarcs if a[2]==o[2]]
            if o[2] == 2:
                redarc = redarcs[2]
            else:
                redarc = redarcs[0]
            su.disp_correct( self.opf+self.erroot%o[0], redarc )
            self.log.info("Applied wavelength solution from "+redarc+" to "+self.opf+self.erroot%o[0])
        if self.opf[0] != 'd':
            self.opf = 'd'+self.opf

    def flux_calibrate(self, side=None):
        """
        Determine and apply the relevant flux calibration to all objects.
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
            if f not in starting_files:
                su.run_cmd(' mv %s ../final/.' %f )
        os.chdir( '../final' )

    def coadd_join_output(self):
        """
        Coadds any multiple observations of the same science object,
         joins the red and blue sides of each observation, and then Saves
         the result as an ASCII (.flm) file.
        """
        allfiles = glob('*[(uv)(ir)].ms.fits')
        # try:
        while True:
            if self.interactive:
                print 'Files remaining to process:'
                for f in allfiles: print ' ',f
                inn = raw_input('\nHit enter to continue, or q to quit\n')
                if 'q' in inn.lower():
                    break
            f = [f for f in allfiles if 'uv' in f][0]
            fred = f.replace('uv','ir')
            namedate = re.search('.*\d{8}', f).group()
            bluematches = glob( namedate + '*' + 'uv.ms.fits' )
            redmatches = glob( namedate + '*' + 'ir.ms.fits' )
            doit = True
            if len(bluematches) == len(redmatches) == 1:
                doit = False
            if self.interactive and doit:
                print 'Combine the following files: \n'+str(bluematches)+'\n'+str(redmatches)+'?\n'
                inn = raw_input( 'y for yes, c for continue to the next file, anything else for no\n' )
                if 'c' in inn.lower():
                    allfiles.remove(f)
                    continue
                elif 'y' not in inn.lower():
                    doit = False
            if doit:
                blue = list(su.coadd( bluematches ))
                red = list(su.coadd( redmatches ))
                for f in bluematches+redmatches:
                    allfiles.remove(f)
                self.log.info( 'Coadded the following files: '+str(bluematches))
                self.log.info( 'Coadded the following files: '+str(redmatches))
            else:
                blue = list(su.read_calfits( f ))
                red = list(su.read_calfits( fred ))
                allfiles.remove(f)
                allfiles.remove(fred)

            wl,fl,er = su.join( blue, red, interactive=self.interactive )
            self.log.info('Joined '+f+' to '+fred)
            fname = f.replace('uv','uvir').replace('.ms.fits','.flm')
            doit = True
            if self.interactive:
                su.plot_spectra( wl,fl,er, title=namedate )
                inn = raw_input('Save ' + namedate + ' to file?\n')
                if 'y' not in inn.lower():
                    doit = False
            if doit:
                su.np2flm( fname, wl,fl,er )
                self.log.info( namedate+' saved to file '+fname)
        # except:
            # pass
        if len(allfiles) > 0:
            print "Following files were not processed:"
            for f in allfiles: print ' ',f


    def plt_flams(self):
        """
        Plot and inspect all *.flm files (the final outputs).
        """
        finals = glob( '*.flm' )
        for f in finals:
            su.plot_spectra( *np.loadtxt(f, unpack=True), title=f, savefile=f.strip('.flm')+'.png' )