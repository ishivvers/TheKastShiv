"""
Utilities library for the Kast Shiv
 reduction pipeline.

Author: Isaac Shivvers, ishivvers@berkeley.edu

Steals heavily from Brad Cenko's kast_redux and iqutils packages,
as well as the K.Clubb/J.Silverman/R.Foley/R.Chornock/T.Matheson reduction pipeline.
(Thanks everyone!)
More information on that pipeline, and the reasoning behind it,
here: http://heracles.astro.berkeley.edu/wiki/doku.php?id=kast_reduction_guide

Best if run using the Ureka Python setup:
http://ssb.stsci.edu/ureka/

Notes:
 - the scipy.signal.argrelmin function may be helpful to find
    minima in the standard star spectra, afterwhich you can fit
    with spectools.
 - e.g.: mins = scipy.signal.argrelmin( fl, order=25 )
"""

######################################################################
# imports
######################################################################

# installed
import numpy as np
import matplotlib.pyplot as plt
import pyfits as pf
from pidly import IDL
from glob import glob
from scipy.optimize import minimize
from datetime import datetime
from dateutil import parser as date_parser
from BeautifulSoup import BeautifulSoup
from difflib import get_close_matches
from time import sleep
from copy import copy
import urllib
import os
import re

# local
from tools import cosmics as cr
from tools import credentials
from tools.astrotools import smooth,fit_gaussian

######################################################################
# global variables and IRAF import
######################################################################

# kast parameters
# pulled from previous codes or from https://mthamilton.ucolick.org/techdocs/instruments/kast/kast_quickReference.html
REDGAIN=3.0
REDRDNOISE=12.5
BLUEBIAS1='[2052:2080,*]'
BLUEBIAS2='[2082:2110,*]'
BLUEGAIN1=1.2
BLUEGAIN2=1.237
BLUERDNOISE=3.7
KASTAPFACT=1.8558
REDPIXSCALE=0.78 #arcsec/pix in spatial scale
BLUEPIXSCALE=0.43

# give the path to the IDL executable and home folders
## THIS PART FILLED IN BY SETUP.PY ##
IDLPATH='replace_me:IDLPATH'
HOMEDIR='replace_me:HOMEDIR'
if ('replace_me' in IDLPATH) or ('replace_me' in HOMEDIR):
    raise StandardError( 'Run setup.py before continuing!' )

# location of various helpful files
COORDLIST=HOMEDIR+'/tools/licklinelist.dat'
LOGINCL=HOMEDIR+'/tools/custom_cl/login.cl'
REDARCIMG=HOMEDIR+'/tools/KastRed_300-7500_ArHeHgCdNe.png'
BLUEARCIMG=HOMEDIR+'/tools/KastBlue_600-4310_ArHeHgCd.png'

# copy over login.cl file before starting iraf
cwd = os.path.realpath('.')
res = os.system( 'cp %s %s/.'%(LOGINCL, cwd) )
if res != 0:
    raise StandardError('Cannot find IRAF login.cl file!')
from pyraf import iraf

# useful for iraf interactions
yes=iraf.yes
no=iraf.no
INDEF=iraf.INDEF

############################################################################
# file system management
############################################################################

def make_file_system( runID ):
    """
    Creates the file system heirarchy for kast reductions, with
     the root location where the command was run from.
    """
    os.mkdir(runID)
    os.chdir(runID)
    os.mkdir('rawdata')
    os.mkdir('working')
    run_cmd('cp %s working/.' %LOGINCL)
    os.mkdir('final')
    os.chdir('..')

############################################################################

def populate_working_dir( runID, logfile=None, all_obs=None ):
    """
    Take the unpacked data from the raw directory, rename files as necessary,
     and move them into the working directory.
    Should be run from working directory, and either logfile (path to file)
     or all_obs (list of observations, i.e. result of wiki2elog) must be given.
    """
    
    if logfile != None:
        # parse the logfile
        objects,arcs,flats = wiki2elog( infile=logfile )
        all_obs = objects+arcs+flats
    
    # copy over all relevant files to working directory and rename them
    for o in all_obs:
        if o[1] == 1:
            prefix = 'blue'
        elif o[1] == 2:
            prefix = 'red'
        # if there are updated files (i.e. r001.fits.1) use the one observed last
        fs = glob( '../rawdata/%s%d.fits.*' %(prefix[0], o[0]) )
        if not fs:
            run_cmd( 'cp ../rawdata/%s%d.fits %s%s%.3d.fits' %(prefix[0],o[0], runID,prefix,o[0]) )
        else:
            fs.sort( key=lambda x: x[-1] )
            fname = fs[-1]
            run_cmd( 'cp %s %s%s%.3d.fits' %(fname,runID,prefix,o[0]))
    
    # change permissions
    run_cmd( 'chmod a+rw *.fits' )
    
######################################################################
# external communications
######################################################################

def run_cmd( cmd, ignore_errors=False ):
    """
    Wrapper for running external commands.
    """
    res = os.system( cmd )
    if not ignore_errors:
        if res != 0:
            raise StandardError( "Error ::: command failed ::: "+cmd )

############################################################################

def start_idl( idlpath=IDLPATH ):
    """
    start an interactive IDL session.
    """
    try:
        session = IDL( idlpath )
        session.interact()
        session.close()
    except OSError:
        # idl often returns an os error if you just type 'exit'
        return

############################################################################

def get_kast_data( datestring, outfile=None, unpack=True, 
                   un=credentials.repository_un, pw=credentials.repository_pw ):
    """
    Download kast data from a date (in the datestring).
    """
    if outfile == None:
        outfile = 'alldata.tgz'
    date = date_parser.parse(datestring)
    cmd = 'wget --no-check-certificate --http-user="%s" --http-passwd="%s" '+\
            '-O %s "https://mthamilton.ucolick.org/data/%.2d-%.2d/%.2d/shane/?tarball=true&allfiles=true"' 
    print 'downloading data, be patient...'
    run_cmd( cmd %(un, pw, outfile, date.year, date.month, date.day) )
    if unpack:
        cmd = 'tar -xzvf %s' %outfile
        run_cmd(cmd)
        run_cmd( 'mv data*/* .' )
        run_cmd( 'rm %s'%outfile )
        run_cmd( 'rm -r data*' )


############################################################################


def wiki2elog( datestring=None, runID=None, pagename=None, outfile=None, infile=None,
               un=credentials.wiki_un, pw=credentials.wiki_pw ):
    """
    If given infile, will parse that logfile (SilverClubb format, but including object names).
    If not given infile, must be given pagename OR (runID and datestring),
     and this script will download and parse the log from the wiki page.
    - datestring: a parsable string representing the recorded log's date
    - runID: the alphabetical id for the run
    - outfile: include a path to write out a silverclubb-formatted logfile, if desired
    """
    if infile != None:
        objects, arcs, flats = [], [], []
        # parse a local log, skip the header
        lines = open(infile,'r').readlines()[1:] 
        for l in lines:
            if l[0] == '#':
                continue
            try:
                l = l.split()
                if '-' in l[0]:
                    lo,hi = map(int, l[0].split('-'))
                    obsnums = range(lo, hi+1)
                else:
                    obsnums = [int(l[0])]
                sidenum = int(l[1])
                groupnum = int(l[2])
                obstype = l[3]
            except ValueError:
                # for now, skip over any imaging, etc
                continue
            # for now, skip anything that's not uvir
            if sidenum not in [1,2]:
                continue
            if obstype == 'obj':
                objname = l[4]
                for on in obsnums:
                    objects.append( [on, sidenum, groupnum, obstype, objname])
            elif obstype == 'arc':
                for on in obsnums:
                    arcs.append( [on, sidenum, groupnum, obstype] )
            elif obstype == 'flat':
                for on in obsnums:
                    flats.append( [on, sidenum, groupnum, obstype] )
            else:
                raise StandardError('Error reading log!')


    else:
        # download and parse the online wiki, saving to file if requested
        if outfile == None:
            outfile = runID+'.log'
        
        # construct the pagename and credentials request
        if pagename == None:
            date = date_parser.parse(datestring)
            pagename = "%d_%.2d_kast_%s" %(date.month, date.day, runID)
        creds = urllib.urlencode({"u" : un, "p" : pw})
        
        # open the Night Summary page for the run
        soup = BeautifulSoup( urllib.urlopen("http://heracles.astro.berkeley.edu/doku.php?id="+pagename,creds) )
        
        # make sure the table is there
        if soup.body.table == None:
            raise StandardError( "wiki page did not load; are your credentials in order?" )
        else:
            rows = soup.body.table.findAll('tr')

        # emulate the SilverClubb table format
        if outfile != None:
            output = open(outfile,'w')
            output.write('Obs      Side   Group  Type     Name\n')
        
        objects, arcs, flats = [], [], []
        for row in rows[1:]: #skip header row
            cols = row.findAll('td')
            try:
                # handle ranges properly
                if '-' in cols[0].string:
                    lo,hi = map(int, cols[0].string.split('-'))
                    obsnums = range(lo, hi+1)
                else:
                    obsnums = [int(cols[0].string)]
                sidenum = int(cols[2].string)
                groupnum = int(cols[3].string)
                obstype = cols[4].string.strip()
            except ValueError:
                # for now, skip over any imaging, etc
                continue
            # for now, skip anything that's not uvir
            if sidenum not in [1,2]:
                continue
            if obstype == 'obj':
                # find the and clean up the object's name
                # remove anything like a slit width or "IR/UV"
                objname = cols[1].string.lower().strip().encode('ascii','ignore')
                for match in re.findall('[UuIi][VvRr]', objname ):
                    objname = objname.replace(match,'')
                objname = objname.strip().replace(' ','_')
                for on in obsnums:
                    objects.append( [on, sidenum, groupnum, obstype, objname])
            elif obstype == 'arc':
                for on in obsnums:
                    arcs.append( [on, sidenum, groupnum, obstype] )
            elif obstype == 'flat':
                for on in obsnums:
                    flats.append( [on, sidenum, groupnum, obstype] )
            else:
                raise StandardError('Error reading log!')

            # add to output log 
            if outfile != None:
                if obstype == 'obj':
                    output.write( "%s %s %s %s %s\n" %(cols[0].string.strip().ljust(8), cols[2].string.strip().ljust(6),
                                                    cols[3].string.strip().ljust(6), obstype.ljust(8), objname) )
                else:
                    output.write( "%s %s %s %s\n" %(cols[0].string.strip().ljust(8), cols[2].string.strip().ljust(6),
                                                    cols[3].string.strip().ljust(6), obstype) )
        if outfile != None:
            output.close()
    
    return objects, arcs, flats

############################################################################
# fits file management
############################################################################

def head_get( image, keywords ):
    '''
    Get given keywords from the given fits image.
    '''
    if type(keywords) != list:
        keywords = [keywords]
    hdu = pf.open(image)
    values = []
    for key in keywords:
        values.append( hdu[0].header[key] )
    hdu.close()
    return values

############################################################################

def head_del( images, keywords ):
    '''
    Remove given keywords from fits images.
    '''
    if type(images) != list:
        images = [images]
    if type(keywords) != list:
        keywords = [keywords]
    for image in images:
        hdu = pf.open(image)
        for key in keywords:
            hdu[0].remove(key)
        hdu.writeto( image, clobber=True )
        hdu.close()

############################################################################

def head_update( images, keywords, values, comment=None ):
    '''
    Update (or set) given keywords to given values for every image
     in given images.
    If comment is included, will add that comment to every updated keyword.
    ''' 
    if type(images) != list:
        images = [images]
    if type(keywords) != list:
        keywords = [keywords]
    if type(values) != list:
        values = [values]
    for image in images:
        hdu = pf.open(image)
        for i,key in enumerate(keywords):
            hdu[0].header.set(key, values[i], comment)
        hdu.writeto( image, clobber=True )
        hdu.close()

############################################################################
# bias, flatfielding, header updates
############################################################################

def bias_correct(images, y1, y2, prefix=None):
    """
    Bias correct and trim a set of images with y trim limits
     of y1, y2.
    """
    if prefix==None:
        prefix = 'b'
    
    for image in images:
        # open file and get parameters
        fits = pf.open( image )[0]
        
        cover = fits.header['COVER']    #number of overscan columns
        naxis1 = fits.header['NAXIS1'] #number of columns total
        side = fits.header['VERSION']
        
        bbuf = 2 # buffer size to trim from bias section to account for stray light
        dbuf = 2 # buffer size to trim from data section (in x dimension)
        if side == 'kastr':
            # pull out and average the overscan/bias section,
            #  letting there be a small buffer for stray light
            bias = np.mean( fits.data[y1:y2, -(cover-bbuf):], 1 )
            # get the trimmed section
            trimmed_data = fits.data[y1:y2, dbuf:-(cover+dbuf)]
            # apply the bias correction per row
            corrected_data = np.zeros_like(trimmed_data)
            for row in range(trimmed_data.shape[0]):
                corrected_data[row,:] = (trimmed_data[row,:] - bias[row]) * REDGAIN
        
        elif side == 'kastb':
            # pull out and average the two different overscan/bias sections
            #  (one for each amplifier). use a small buffer to account for any stray light
            bias1 = np.mean( fits.data[y1:y2,-(cover*2-bbuf):-cover], 1 )
            bias2 = np.mean( fits.data[y1:y2,-cover:], 1 )
            # the midpoint dividing the two amplifiers; SLIGHTLY DIFFERENT THAN KASTBIAS.PRO!!
            mid = (naxis1 - 2*cover)/2
            # get the trimmed sections for each amplifier
            trimmed_data1 = fits.data[y1:y2, dbuf:mid]
            trimmed_data2 = fits.data[y1:y2, mid:-(cover*2+dbuf)]
            # apply the bias correction
            corrected_data1 = np.zeros_like(trimmed_data1)
            for row in range(trimmed_data1.shape[0]):
                corrected_data1[row,:] = (trimmed_data1[row,:] - bias1[row]) * BLUEGAIN1
            corrected_data2 = np.zeros_like(trimmed_data2)
            for row in range(trimmed_data2.shape[0]):
                corrected_data2[row,:] = (trimmed_data2[row,:] - bias2[row]) * BLUEGAIN2
            # join the two sides back together
            corrected_data = np.hstack( (corrected_data1, corrected_data2) )
        
        # remove the DATASEC keyheader keywork if it exists
        try:
            fits.header.pop('DATASEC')
        except KeyError:
            pass
        
        # write to file
        pf.writeto( prefix+image, corrected_data, fits.header )

############################################################################

def make_flat(images, outflat, side, interactive=True):

    '''
    Construct median flat from individual frames, and then
     normalize by fitting a response function.
    side must be one of "red" or "blue"
    '''
    if side == 'red':
        gain = REDGAIN
        rdnoise = REDRDNOISE
        fitorder = 4
    elif side == 'blue':
        gain = BLUEGAIN1
        rdnoise = BLUERDNOISE
        fitorder = 6
    else:
        raise StandardError( "side must be one of 'red','blue'" )
    
    if interactive:
        interact = yes
    else:
        interact = no
    
    flatimages=','.join(images)
    # combine the flats
    try:
        run_cmd( 'rm CombinedFlat.fits' )
        sleep(1)  # have to wait a bit for this to go through!
    except:
        pass
    iraf.flatcombine(flatimages, output='CombinedFlat', combine='median',
                     reject='ccdclip', ccdtype='', process=no, subsets=no,
                     delete=no, scale='median', lsigma=3.0,
                     hsigma=3.0, gain=gain, rdnoise=rdnoise)
    # fit for the response function and save as the output
    iraf.response('CombinedFlat', 'CombinedFlat', outflat, order=fitorder, interactive=interact)

############################################################################

def apply_flat(images, flat, prefix='f' ):
    """
    Apply flatfield correction to images.
    - prefix defaults to 'f' if not given
    """
    for image in images:
        iraf.ccdproc(image, output='%s%s' %(prefix,image),
                     flatcor=yes, flat=flat,
                     ccdtype='', noproc=no, fixpix=no, 
                     overscan=no, trim=no, zerocor=no, darkcor=no,
                     illumcor=no, fringecor=no, readcor=no, scancor=no)
    
############################################################################

def update_headers(images):
    """
    Run fixhead (custom IRAF task) and calculate the airmass values.
    """
    for image in images:
        iraf.kastfixhead(image)
        iraf.setairmass(image)

############################################################################

def calculate_seeing( allfiles, plot=False ):
    """
    Given a list of files, will find the standards from them and calculate the seeing
     and observation time of each.
    The seeing observed nearest the time of each object observation will then be calculated
     and inserted into the header.
    """
    std_times, std_seeing = [], []
    # calculate the seeing for each standard
    for f in allfiles:
        std = id_standard( head_get(f, 'object' )[0] )
        if not std:
            # not a standard
            continue
        side = {1:'blue',2:'red'}[std[1]]
        h = pf.open( f )
        # calculate the FWHM at three points and take the median
        s = h[0].data.shape[1]/4
        fwhms = []
        for i in range(1,4):
            fwhms.append( fit_gaussian(np.arange(h[0].data.shape[0]), h[0].data[:,i*s], plot=plot)[0]['FWHM'] )
            if plot:
                plt.title('%s seeing calculation %d'%(side,i))
        if side == 'blue':
            seeing = np.median( fwhms ) * BLUEPIXSCALE
        else:
            seeing = np.median( fwhms ) * REDPIXSCALE
        obstime = date_parser.parse( h[0].header['DATE-OBS'] )
        std_times.append( obstime )
        std_seeing.append( seeing )
        print 'Calculated: seeing ~',seeing,'for image',f
        head_update( f, 'SEEING', round(seeing,2) )

    # now go through all non-standards and find the time, and match to a seeing measurement
    for f in allfiles:
        if id_standard( head_get(f, 'object' )[0] ):
            # a standard
            continue
        h = pf.open( f )
        obstime = date_parser.parse( h[0].header['DATE-OBS'] )
        dtimes = [abs( (obstime - t).total_seconds() ) for t in std_times]
        seeing = std_seeing[ np.argmin(dtimes) ]
        print 'Associated: seeing ~',seeing,'for image',f
        head_update( f, 'SEEING', round(seeing,2) )

############################################################################

def combine_arcs( arcs, output ):
    """
    simply combine a set of arc images into a single image
    """
    # make sure the file doesn't already exist
    try:
        run_cmd( 'rm ' + output )
        sleep(1)  # have to wait a bit for this to go through!
    except:
        pass
    iraf.imarith( arcs[0], '+', arcs[1], output )

############################################################################

def id_arc(arc, coordlist=COORDLIST):

    '''
    Construct reference wavelength solution from arc lamps
    '''
    iraf.identify(arc, coordlist=coordlist, function="legendre", order=4)

############################################################################

def reid_arc(arc, reference, interact=True, coordlist=COORDLIST):

    '''
    Construct wavelength solution from arc lamp,
     using previous extraction as a guide.
    '''
    if interact:
        interactive = yes
    else:
        interactive = no
    iraf.reidentify(reference, arc, coordlist=coordlist, interactive=interactive, override=yes)

############################################################################

def disp_correct( image, arc, prefix='d' ):
    """
    Apply the wavelength solution from arc to image.
    """
    # define the reference spectrum header in our science object
    head_update( image, 'REFSPEC1', arc )
    iraf.dispcor( image, prefix+image )

############################################################################
# spectrum extraction
############################################################################

def parse_apfile( apfile ):
    """
    Open an iraf.apall apfile and search for and pull out the background and
     aperture properties.
    Returns a tuple of (lo, hi) for aperture, low background, and high background, in that order
     e.g.: aperture, lo_bg, hi_bg = parse_apfile( apfile )
    """
    lines = open(apfile,'r').readlines()
    lo = float([l for l in lines if 'low' in l][0].split(' ')[-1].strip())
    hi = float([l for l in lines if 'high' in l][0].split(' ')[-1].strip())
    sampline = [l for l in lines if 'sample' in l][0]
    lbglo, lbghi, rbglo, rbghi = map(float, re.findall('-?\d+\.?\d*',sampline))
    return (lo,hi), (lbglo, lbghi), (rbglo, rbghi)

######################################################################

def extract( image, side, arc=False, interact=True, reference=None, trace_only=False,
             apfile=None, apfact=None, **kwargs):
    """
    Use apall to extract the spectrum.
    
    If arc=True, will not fit for or subtract a background, and you must include a reference.
    If this is part of a set of consecutive observations of the same object, and is not
     the first, pass along the extracted first observation as 'reference';
     this will force interact=False and will use all of the parameters from the reference.
    If 'reference' is given and trace_only is True, will only use the reference to define the
     trace pattern, and not the aperture.  This is useful for extracting nebular spectra,
     when you can pass an image of the standard star along as a reference to define the trace.
     If 'reference' is not given, trace_only is ignored.
    If apfile is given, will use the aperture and background properties from that apfile,
     first multiplying by apfact if given (accounts for pixel size differences).
     Note: using either arc or reference keys will override the apfile.
    Any additional keyword arguments will be passed along to iraf.apall directly, overriding any built-in defaults. 
     Common keywords include:
     - line: the column number to use to define the aperture (helpful for nebular spectra)
     - nsum: the number of adjacent columns to sum (or median, if nsum<0) to define the aperture
     - output: if not given, follows IRAF standard and sticks ".ms." in middle of filename (for "multispec").
     See here for an exhaustive list: http://iraf.net/irafhelp.php?val=apextract.apall&help=Help+Page
    """
    
    if interact:
        interactive = yes
    else:
        interactive = no
    
    if side == 'red':
        gain = REDGAIN
        rdnoise = REDRDNOISE
    elif side == 'blue':
        gain = BLUEGAIN1
        rdnoise = BLUERDNOISE
    else:
        raise StandardError( "side must be one of 'red','blue'" )

    # taken mostly from Jeff Silverman's apall uparm file
    ap_params = {'output':'',                  # basic parameters
                 'apertures':'1',
                 'format':'multispec',
                 'references':'',
                 'profiles':'',
                 'interactive':interactive,    # processing / interactive parameters
                 'find':yes,
                 'recenter':no,
                 'resize':no,
                 'edit':yes,
                 'trace':yes,
                 'fittrace':yes,
                 'extract':yes,
                 'extras':yes,
                 'review':yes,
                 'line':INDEF,
                 'nsum':100,
                 'lower':-2.5,                 # default aperture parameters
                 'upper':2.5,
                 'apidtable':'',
                 'b_function':'legendre',      # default background parameters
                 'b_order':2,
                 'b_sample':'-25:-10,10:25',
                 'b_naver':-99,
                 'b_niterate':3,
                 'b_low_reject':3.0,
                 'b_high_reject':2.0,
                 'b_grow':1.0,
                 'width':5.0,                 # aperture centering parameters
                 'radius':10.0,
                 'threshold':0.0,
                 'nfind':1,                   # automatic finding and ordering parameters
                 'minsep':5.0,
                 'maxsep':1000.0,
                 'order':'increasing',
                 'aprecenter':'',             # recentering paramters
                 'npeaks':INDEF,
                 'shift':no,
                 'llimit':INDEF,              # resizing parameters
                 'ulimit':INDEF,
                 'ylevel':0.01,
                 'peak':yes,
                 'bkg':yes,
                 'r_grow':0.0,
                 'avglimits':no,
                 't_nsum':100,                 # tracing parameters
                 't_step':20,
                 't_nlost':3,
                 't_function':'legendre',
                 't_order':4,
                 't_sample':'*',
                 't_naverage':1,
                 't_niterate':3,
                 't_low_reject':3.0,
                 't_high_reject':3.0,
                 't_grow':0.0,
                 'background':'fit',          # extraction parameters
                 'skybox':1.0,
                 'weights':'variance',
                 'pfit':'fit1d',
                 'clean':yes,
                 'saturation':INDEF,
                 'readnoise':rdnoise,
                 'gain':gain,
                 'lsigma':4.0,
                 'usigma':4.0,
                 'nsubaps':1
                 }
    if not interactive:
        ap_params['recenter'] = yes
    
    obj_name = pf.open(image)[0].header['object']
    print 'Processing image %s \n Object: %s\n' %(image, obj_name)

    if (reference == None) & (arc == False) & (apfile == None):
        print 'Extracting object; no reference.'
        if side=='blue':
            # resize the default aperature for the blue side
            ap_params['lower'] = -4.6
            ap_params['upper'] = 4.6
            ap_params['b_sample'] = '-46:-18,18:46'

    elif (reference != None) & (arc == False):
        if trace_only:
            print 'Extracting object using reference for trace only.'
            ap_params['references'] = reference
            ap_params['edit']       = yes
            ap_params['trace']      = no
            ap_params['fittrace']   = no
        else:
            print 'Extracting object using reference.'
            ap_params['references'] = reference
            ap_params['recenter']   = no
            ap_params['edit']       = no
            ap_params['fittrace']   = no

    elif arc:
        print 'Extracting arc.'
        ap_params['interactive'] = no  #override input 
        ap_params['references']  = reference
        ap_params['recenter']    = no
        ap_params['edit']        = no
        ap_params['trace']       = no
        ap_params['fittrace']    = no
        ap_params['background']  = 'none'


    elif (apfile != None):
        ap, lbg, rbg = parse_apfile( apfile )
        if apfact == None:
            apfact = KASTAPFACT
        print 'Extracting object using reference apfile and apfact=%.2f.'%apfact
        ap_params['references'] = ''
        ap_params['find']       = yes
        ap_params['recenter']   = no
        ap_params['lower']      = ap[0]*apfact
        ap_params['upper']      = ap[1]*apfact
        ap_params['b_sample']   = "%.2f:%.2f,%.2f:%.2f" %(lbg[0]*apfact, lbg[1]*apfact, rbg[0]*apfact, rbg[1]*apfact)

    else:
        raise StandardError( "unacceptable keyword combination" )

    # override any defaults with input kwargs
    ap_params.update( kwargs )
    # now actually perform the extraction
    iraf.apall(image, **ap_params )

############################################################################
# cosmic ray removal
############################################################################

def clean_cosmics( fitspath, side, cleanpath=None, maskpath=None ):
    """
     clean an input fits file using the LACOS algorithm 
    
    - fitspath: input file
    - side: one of 'blue','red'
    - cleanpath: output file (if none, prepends "c" to input filename)
    - maskpath: [optional] mask output file
    """
    if cleanpath == None:
        # this only works if we are in the same folder
        assert('/' not in fitspath)
        cleanpath = 'c' + fitspath
    # lacos parameters
    objlim = 5.0
    maxiter = 3
    
    if side == 'red':
        gain = REDGAIN
        rdnoise = REDRDNOISE
        sigclip = 10.0
        sigfrac = 2.0
    elif side == 'blue':
        gain = BLUEGAIN1
        rdnoise = BLUERDNOISE
        sigclip = 4.5
        sigfrac = 0.5
    
    array, header = cr.fromfits(fitspath)
    c = cr.cosmicsimage(array, gain=gain, readnoise=rdnoise,
                        sigclip=sigclip, sigfrac=sigfrac, objlim=objlim)
    c.run(maxiter=maxiter)
    cr.tofits(cleanpath, c.cleanarray, header)
    if maskpath != None:
        cr.tofits(maskpath, c.mask, header)
    return


######################################################################
# standards management
######################################################################

def id_standard( obj_name ):
    """
    Matches obj_name (a string) to known red and blue standards.
    Returns None if not a standard, returns (name, side) if it is
     (where side = 1 for blue and 2 for red)
    The IDL script abcalc.pro must know about all of these objects!
    """
    # name, side (1=blue, 2=red)
    standards = {'feige34': 1, 'feige110' : 1, 'hz44' : 1, 
                 'bd284211' : 1, 'g191b2b' : 1, 'bd174708' : 2,
                 'bd262606' : 2, 'hd84937' : 2, 'hd19445' : 2}
                 
    # cleanup the input object name
    obj_name = obj_name.lower().replace(' ','')
    
    # get the best match
    try:
        std_name = get_close_matches( obj_name, standards, 1 )[0]
    except IndexError:
        print 'no match for',obj_name
        return None
    print 'identified',obj_name,'as',std_name
    return std_name, standards[std_name]

######################################################################

def match_science_and_standards( allobjects ):
    """
    Takes in a list of the filenames for all observed objects, identifies the 
     standard star observations, and associates each object
     with the standard taken at the closest airmass.
    Returns a dictionary for each side (blue, red) with the standard observations 
     as the keys and a list of associated science observations as
     the values.
    """
    blue_outdict = {}
    red_outdict = {}
    
    # first get all of the blue standards
    airmasses = []
    std_names = []
    for fname in allobjects:
        if 'blue' not in fname:
            continue
        objname = head_get( fname, 'OBJECT' )[0]
        std_id = id_standard( objname )
        if std_id == None:
            continue
        
        std_names.append( fname )
        airmasses.append( head_get( fname, 'AIRMASS' )[0] )
        if (std_id[1] == 1):
            blue_outdict[ fname ] = [] 
        else:
            raise StandardError( "attempting to use a standard on the wrong side!" )
    
    airmasses = np.array(airmasses)
    # now associate each blue science obs with a standard
    for fname in allobjects:
        if 'blue' not in fname:
            continue
        objname = head_get( fname, 'OBJECT' )[0]
        std_id = id_standard( objname )
        if std_id != None:
            continue
        am = head_get( fname, 'AIRMASS' )[0]
        std_match = std_names[ np.argmin(np.abs(am-airmasses)) ]
        blue_outdict[ std_match ].append( fname )
 
    # now get all of the red standards
    airmasses = []
    std_names = []
    for fname in allobjects:
        if 'red' not in fname:
            continue
        objname = head_get( fname, 'OBJECT' )[0]
        std_id = id_standard( objname )
        if std_id == None:
            continue
        
        std_names.append( fname )
        airmasses.append( head_get( fname, 'AIRMASS' )[0] )
        if (std_id[1] == 2):
            red_outdict[ fname ] = []
        else:
            raise StandardError( "attempting to use a standard on the wrong side!" )
    
    airmasses = np.array(airmasses)
    # now associate each red science obs with a standard
    for fname in allobjects:
        if 'red' not in fname:
            continue
        objname = head_get( fname, 'OBJECT' )[0]
        std_id = id_standard( objname )
        if std_id != None:
            continue
        am = head_get( fname, 'AIRMASS' )[0]
        std_match = std_names[ np.argmin(np.abs(am-airmasses)) ]
        red_outdict[ std_match ].append( fname )
               
    return blue_outdict, red_outdict

############################################################################
# calibrating and finishing
############################################################################

def calibrate_idl( input_dict, idlpath=IDLPATH, cleanup=True ):
    """
    Runs the idl task cal.pro on the files given in the input_dict.
     input_dict should have standard observations for keys and lists of
     associated science observations as values.
    Should be run from final folder, though the input images should 
     all live in the working folder.
    """
    for std in input_dict.keys():
        # create an input file
        ftmp = open('cal.input','w')
        ftmp.write( '%s\n'%std )
        for val in input_dict[std]:
            ftmp.write( '%s\n'%val )
        ftmp.close()
        
        # give the user some feedback
        print '\n\nStarting IDL & cal.pro'
        print 'Standard file:',std
        print 'Input file: cal.input'
        print 'Type "cal"\n'
        
        start_idl()

######################################################################

def read_calfits( f ):
    """
    Reads in a fits file produced by cal.pro, returns wl,fl,er
     numpy arrays.
    """
    hdu = pf.open( f )
    wlmin = hdu[0].header['crval1']
    res = hdu[0].header['cdelt1']
    length = hdu[0].data.shape[-1]
    wl = np.arange( wlmin, wlmin+res*length, res )
    fl = hdu[0].data[0]
    er = hdu[0].data[1]
    return wl,fl,er

######################################################################

def coadd( files, save=True, fname=None ):
    """
    Reads in a list of fits file namess (file formats as expected from flux-calibrated
     spectra, after using the IDL routine cal.pro).
    Converts all input specta into units of [flux * time], adds them, and then divides
     by the total time to return a spectrum in units of [flux].  If the wavelength 
     arrays are different will interpolate all spectra onto the region covered
     by all input spectra, rebinning all data to the same resolution first if needed
     (using the resolution of the lowest-resolution spectrum).
    If save is True, will save a fits file of the coadded input fits files, with a 
     properly-updated header.
    Returns numpy arrays of wavelength, flux, and error.
    """
    hdus = [pf.open(f) for f in files]
    res = max( [h[0].header['cdelt1'] for h in hdus] )
    wlmin = max( [h[0].header['crval1'] for h in hdus] )
    wlmax = min( [h[0].header['crval1'] + h[0].data.shape[-1]*h[0].header['cdelt1'] for h in hdus] )
    totime = sum([float(h[0].header['exptime']) for h in hdus])
    # get obsdate info
    date_fmt = '%Y-%m-%dT%H:%M:%S.%f'
    obs_begin = min([ datetime.strptime( h[0].header['date-beg'], date_fmt ) for h in hdus ])
    obs_end = max([ datetime.strptime( h[0].header['date-end'], date_fmt ) for h in hdus ])
    obs_mid = obs_begin + (obs_end-obs_begin)/2
    # define the output wavelength range; go just over wlmax to make sure it's included
    wl = np.arange( wlmin, wlmax+res/10.0, res )
    fl = np.zeros_like(wl)
    er = np.zeros_like(wl) #will add the appropriate errors in quadrature
    for h in hdus:
        thiswl = np.arange( h[0].header['crval1'], 
                    h[0].header['crval1'] + h[0].data.shape[-1]*h[0].header['cdelt1'],
                    h[0].header['cdelt1'])
        thisfl = h[0].data[0]
        thiser = h[0].data[1]
        if h[0].header['crval1'] != res:
            # need to rebin data to this resolution.
            # will be a downsampling, so we first have to smooth the data
            #  to this resolution using a square window.
            # Note: I do not smooth the noise estimates; I just downsample them.
            thisfl = smooth( thiswl, thisfl, width=res, window='flat' )
        # ensure this spectrum is on the same wl array
        thisfl = np.interp(wl, thiswl, thisfl)
        thiser = np.interp(wl, thiswl, thiser)
        # sum the arrays in units of [flux*time]
        fl += thisfl*float(h[0].header['exptime'])
        er += thiser**2.0  # simply add the errors in quadrature; should be close enough!
    fl = fl/totime # convert back to units of [flux]
    er = er**.5 / len(hdus)
    if save:
        # save the co-added fits file
        if fname == None:
            fname = 'coadded.'+files[0]
        hdu = hdus[0]
        # update header
        head = hdu[0].header
        head['exptime'] = totime
        head['date-beg'] = datetime.strftime( obs_begin, date_fmt )
        head['date-obs'] = datetime.strftime( obs_begin, date_fmt )
        head['utmiddle'] = datetime.strftime( obs_mid, date_fmt )
        head['date-end'] = datetime.strftime( obs_end, date_fmt )
        head['crval1'] = wlmin
        head['cdelt1'] = res
        head.append( ('cadd-frm', ','.join(files), 'coadded from these files'), end=True )
        # update data
        hdu.data = np.vstack( (fl, er) )
        # save the file
        hdu.writeto( fname )
    return wl, fl, er

######################################################################

def join( spec1, spec2, scaleside=1, interactive=True ):
    """
    Used to join the red and blue sides of Kast, or a similar spectrograph.
    Each of spec1,2 should be a list of [wl, fl, er] (er is optional),
     and spec1 must be the bluer spectrum.
    Scaleside lets you choose between rescaling side 1 or side 2.
    """
    # calculate the overlap masks
    m1 = spec1[0] >= spec2[0][0]
    m2 = spec1[0][-1] >= spec2[0]
    if sum(m1)==sum(m2)==0:
        raise Exception('No overlap!')
    if interactive:
        # let the user choose a different range
        plt.figure()
        plt.plot( spec1[0][m1], spec1[1][m1], 'b' )
        plt.plot( spec2[0][m2], spec2[1][m2], 'r' )
        print 'Click on the limits of the best overlap area'
        [x1,y1],[x2,y2] = plt.ginput(n=2)
        xmin, xmax = min([x1,x2]), max([x1,x2])
        m1 = (spec1[0] >= xmin) & (spec1[0] <= xmax)
        m2 = (spec2[0] >= xmin) & (spec2[0] <= xmax)
        _,_, ymin,ymax = plt.axis()
        plt.vlines( [xmin, xmax], ymin, ymax, colors='k', linestyles='dashed' )

    # calculate the differences in the means of the overlap areas and rescale
    factor = np.mean(spec2[1][m2])/np.mean(spec1[1][m1]) # factor by which spec2 is greater than spec1
    if scaleside == 2:
        spec2[1] = spec2[1]/factor
        if len(spec2) > 2:
            # rescale errors too
            spec2[2] = spec2[2]/factor
    elif scaleside == 1:
        spec1[1] = spec1[1]*factor
        if len(spec1) > 2:
            spec1[2] = spec1[2]*factor
    else:
        raise Exception("scaleside must be 1 or 2")

    # join the two at the middle of the overlap region
    xmid = np.mean(spec1[0][m1])
    m1 = spec1[0] <= xmid
    m2 = spec2[0] > xmid
    wl = np.hstack( (spec1[0][m1], spec2[0][m2]) )
    fl = np.hstack( (spec1[1][m1], spec2[1][m2]) )
    if (len(spec1) > 2) & (len(spec2) > 2):
        er = np.hstack( (spec1[2][m1], spec2[2][m2]) )
        return wl,fl,er
    else:
        return wl,fl

######################################################################

def np2flm( fname, wl,fl, er=None, headerstring='' ):
    """
    Saves numpy arrays of wavelength and flux into the 
     Flipper-standard ascii *.flm file.
    """
    fout = open(fname, 'w')
    fout.write('# File created by shivutils (I.Shivvers)\n# ' +\
               headerstring + '\n# wl(A)   flm    er(optional)\n')
    for i,w in enumerate(wl):
        if er != None:
            fout.write( '%.2f   %.8f   %.8f\n' %(w, fl[i], er[i]) )
        else:
            fout.write( '%.2f   %.8f\n' %(w, fl[i]) )
    fout.close()

######################################################################
# automation tools
######################################################################

def tophat(x, low, high, left, right):
    """
    Returns a tophat with left, right for x-value edges, and
     low,high for y-value limits
    """
    y = np.zeros_like(x)
    y[ (x<=left) | (x>=right) ] = low
    y[ (x>left) & (x<right) ] = high
    return y

######################################################################

def sumsqerr(p, x, y):
    low, high, left, right = p
    return np.sum( (y - tophat(x, low, high, left, right))**2 )
    
######################################################################

def find_trim_sec( flatfile, edgebuf=5, plot=True ):
    """
    Find the optimal y-axis trim values from flatfile.
     edge: the size of the edge buffer in pixels
    """
    data = pf.open(flatfile)[0].data
    # find the best column to examine by choosing the peak of
    #  all averaged rows
    icol = np.argmax( np.mean(data, 0) )
    y = data[:,icol]
    x = np.arange(len(data[:,icol]))

    lo = np.min(y)
    hi = np.median(y)    
    # find estimates of the box edges
    for i,yyy in enumerate(y):
        if yyy > (lo + (hi-lo)/2):
            ledge = i
            break
    for i,yyy in enumerate(y[::-1]):
        if yyy > (lo + (hi-lo)/2):
            redge = x[-1] - i
            break
    
    p0 = [lo, hi, ledge, redge]
    res = minimize(sumsqerr, p0, args=(x,y), method='Nelder-Mead')
    if not res.success:
        raise StandardError("Cannot find good fit for trim section")
    
    y1 = res.x[2]+edgebuf
    y2 = res.x[3]-edgebuf
    
    if plot:
        # show the column we chose
        plt.figure()
        plt.plot( np.mean(data,0), 'k' )
        ymin,ymax = plt.gca().get_ylim()
        plt.vlines( [icol], ymin, ymax, color='r', lw=2 )
        plt.ylabel('Row-averaged DN')
        plt.xlabel('Column')
        plt.title('Column used for trim selection')
        
        # show the best-fit trim section
        plt.figure()
        plt.plot(x,y,'k')
        ymin,ymax = plt.gca().get_ylim()
        plt.vlines( [y1,y2], ymin, ymax, color='r', lw=2 )
        plt.ylabel('DN')
        plt.xlabel('Row')
        plt.title('Best-fit trim section')
        plt.show()
    
    return y1,y2

######################################################################
    
def plot_spectra(lam, flam, err=None, title=None, savefile=None):
    '''
    Produce pretty spectra plots.
    
    lam: wavelength
    flam: flux
    err: error spectrum
     (all three must be 1d and array-like)
    title: if given, will place as the title of the plot
    savefile: if given, will save the plot to that file.
    '''
        
    spec_kwargs = dict( alpha=1., linewidth=1, c=(30./256, 60./256, 75./256) )
    err_kwargs = dict( interpolate=True, color=(0./256, 165./256, 256./256), alpha=.1 )
    fig = plt.figure( figsize=(14,7) )
    ax = plt.subplot(1,1,1)
    
    ax.plot( lam, flam, **spec_kwargs )
    if err != None:
        ax.fill_between( lam, flam+err, flam-err, **err_kwargs )
    if title != None:
        plt.title( title )
    
    plt.xlabel('Wavelength')
    plt.ylabel('Flux')

    if savefile != None:
        plt.savefig( savefile )
    
    plt.show()
