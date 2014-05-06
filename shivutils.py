"""
Utilities library for the Kast Shiv
 reduction pipeline.

Author: Isaac Shivvers, ishivvers@berkeley.edu

Steals heavily from Brad Cenko's kast_redux and iqutils packages,
as well as the SilverClubb reduction pipeline.
(Thanks Brad, Jeff, and Kelsey!)


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
from dateutil import parser as date_parser
from BeautifulSoup import BeautifulSoup
from difflib import get_close_matches
from time import sleep
import urllib
import os
import re


# local
import cosmics as cr
import credentials

######################################################################
# global variables and IRAF import
######################################################################

# kast parameters
REDGAIN=3.0
REDRDNOISE=12.5
BLUEBIAS1='[2052:2080,*]'
BLUEBIAS2='[2082:2110,*]'
BLUEGAIN1=1.2
BLUEGAIN2=1.237
BLUERDNOISE=3.7

from platform import node
# give the path to the IDL executable and home folders
# and the home folder
if node() == 'classy':
    IDLPATH='/home/isaac/Working/code/IDL/idl/bin/idl'
    HOMEDIR='/home/isaac/Working/code/kast_reductions/'
elif node() == 'beast.berkeley.edu':
    IDLPATH='/apps3/rsi/idl_8.1/bin/idl'
    HOMEDIR='/o/ishivvers/kastreductions/TheKastShiv/'
else:
    raise StandardError("Where am I?!")
# location of various helpful files
COORDLIST=HOMEDIR+'tools/licklinelist.dat'
LOGINCL=HOMEDIR+'tools/login.cl'
REDARCIMG=HOMEDIR+'tools/kast_arc_red.jpeg'
BLUEARCIMG=HOMEDIR+'tools/kast_arc_blue.jpeg'

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
            run_cmd( 'cp ../rawdata/b%d.fits %sblue%.3d.fits' %(o[0],runID,o[0]) )
        elif o[1] == 2:
            run_cmd( 'cp ../rawdata/r%d.fits %sred%.3d.fits' %(o[0],runID,o[0]) )
    
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
    session = IDL( idlpath )
    session.interact()
    session.close()

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
            '-O %s "https://mthamilton.ucolick.org/data/%.2d-%.2d/%d/shane/?tarball=true&allfiles=true"' 
    print 'downloading data, be patient...'
    run_cmd( cmd %(un, pw, outfile, date.year, date.month, date.day) )
    if unpack:
        cmd = 'tar -xzvf %s' %outfile
        run_cmd(cmd)
        run_cmd( 'mv data*/*.fits .' )
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
        soup = BeautifulSoup( urllib.urlopen("http://hercules.berkeley.edu/wiki/doku.php?id="+pagename,creds) )
        
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
                objname = cols[1].string.lower().strip().strip('uv').strip('ir').strip()
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

def get_object_names( obj_files ):
    """
    Opens all files in obj_files and searches for the object name in the fits header.
    Returns a dictionary with the ID string for keys and object name as the value.
     e.g.: {"red29":"SN2014J", "blue042":"feige34", ... }
    """
    outdict = {}
    for of in obj_files:
        idstr = re.search('blue\d+|red\d+', of).group()
        objname = pf.open( of )[0].header["object"]
        outdict[ idstr ] = objname
    return outdict
    
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

def bias_correct_idl(images, y1, y2, prefix=None, idlpath=IDLPATH):
    """
    Use pIDLy to interact with the trusty 'kastbias.pro' script
     to bias correct and trim a set of images with y trim limits of y1, y2.
    NOTE: your IDL installation must know the location of 'kastbias.pro'
    """
    if prefix==None:
        prefix = 'b'
    idl = IDL( idlpath )
    for image in images:
        idl.pro("kastbias",image,y1=y1,y2=y2,prefix=prefix)
    idl.close()

############################################################################

def bias_correct_iraf(images, y1, y2, prefix=None):
    '''
    Bias correct a set of images with y trim limits of y1, y2.
    NOTE: the original kast_bias.pro script incorporates the "gain" of
          each amplifier independently, but it looks like ccdproc does
          not do this.  If important, will need to hardcode own version
          of kast_bias.pro.

    SOMETHING IS WRONG; SHOULD NEVER HAVE VALUES <= 0.0 !!!
    '''
    if type(images) != list:
        images = [images]
    if prefix == None:
        outputs = ["" for i in images]
    else:
        outputs = [prefix+i for i in images]
    for i,image in enumerate(images):
        # get whether this is red or blue side from the fits header
        side = head_get( image, 'VERSION' )

        if prefix == None:
            outname = image
        else:
            outname = outputs[i]
        
        if side == 'kastr':
            # use the red side parameters
            iraf.ccdproc(image, output=outputs[i], ccdtype='', noproc=no, fixpix=no,
                         overscan=yes,trim=yes, zerocor=no, darkcor=no, flatcor=no,
                         illumcor=no, fringecor=no, readcor=no, scancor=no,
                         biassec=REDBIAS, trimsec=REDTRIM%(y1,y2))
        
        elif side == 'kastb':
            # need to process the two different blue amplifiers seperately
            root,ext=os.path.splitext(image)
            iraf.ccdproc(image, output='%s_1'%root, ccdtype='', noproc=no, fixpix=no,
                         overscan=yes, trim=yes, zerocor=no, darkcor=no, flatcor=no,
                         illumcor=no, fringecor=no, readcor=no, scancor=no,
                         biassec=BLUEBIAS1, trimsec=BLUETRIM1%(y1,y2))
            iraf.ccdproc(image, output='%s_2'%root, ccdtype='', noproc=no, fixpix=no,
                         overscan=yes, trim=yes, zerocor=no, darkcor=no, flatcor=no,
                         illumcor=no, fringecor=no, readcor=no, scancor=no,
                         biassec=BLUEBIAS2, trimsec=BLUETRIM2%(y1,y2))
            # add the results back together and clean the directory
            iraf.imjoin('%s_1,%s_2' % (root, root), 'j%s' % image, 1)
            run_cmd( 'rm %s_1 %s_2' % (root, root) )
            
            # need to manually move combined file
            run_cmd( 'mv j%s %s' % (image, outname) )
            
            # not sure if needed, but update the header info to reflect the new array size
            print 'running maybe-useless task; CHECK ME OUT'
            head_update(outname, ['CCDSEC', 'DATASEC'],
                        ['[1:2048,1:%d]'%(y2-y1+1), '[1:2048,1:%d]'%(y2-y1+1)])
        
        # add a comment saying we performed a bias subtraction
        head_update(outname, 'BIASSUB', True, comment='Bias subtracted with IDL kastbias.pro')

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
    run uvfixhead (custom IRAF task) and calculate the airmass values
    """
    images = ','.join(images)
    iraf.kastfixhead(images)
    iraf.setairmass(images)

############################################################################

def combine_arcs( arcs, output ):
    """
    simply combine a set of arc images into a single image
    """
    iraf.imarith( arcs[0], '+', arcs[1], output )
    for i in range(2,len(arcs)):
        iraf.imarith( output, '+', arcs[i], output )

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
    iraf.reidentify(reference, arc, coordlist=coordlist, interactive=interactive)

############################################################################

def disp_correct( image, arc ):
    """
    Apply the wavelength solution from arc to image, using the helper
     task mydisp.cl
    """
    iraf.mydisp( image, arc )

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
    lbglo, lbghi, rbglo, rbghi = map(float, re.findall('-?\d+',sampline))
    return (lo,hi), (lbglo, lbghi), (rbglo, rbghi)

def extract( image, side, arc=False, output=None, interact=True, reference=None,
             apfile=None, apfact=None):
    """
    Use apall to extract the spectrum.
    
    If arc=True, will not fit for or subtract a background, and you must include a reference.
    If this is not the first spectrum from a set of consecutive observations
     of the same object, pass along the extracted first observation as 'reference';
     this will force interact=False and will use the parameters from the reference.
    If output is not given, follows IRAF standard and sticks ".ms." in middle of filename.
    If apfile is given, will use the aperture and background properties from that apfile,
     first multiplying by apfact if given (accounts for pixel size differences).
     Note: using either arc or reference keys will override the apfile.
    """
    if output == None:
        output = ''
    
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
    
    if (reference == None) & (arc == False) & (apfile == None):
        iraf.apall(image, output=output, references='', interactive=interactive,
                   find=yes, recenter=yes, resize=yes, edit=yes, trace=yes,
                   fittrace=yes, extract=yes, extras=yes, review=yes,
                   background='fit', weights='variance', pfit='fit1d',
                   readnoise=rdnoise, gain=gain, nfind=1, apertures='1',
                   ulimit=20, ylevel=0.01, b_sample="-35:-25,25:35", 
                   t_function="legendre", t_order=4 )
    elif (reference != None) & (arc == False):
        iraf.apall(image, output=output, references=reference, interactive=no,
                   find=no, recenter=no, resize=no, edit=no, trace=no,
                   fittrace=no, extract=yes, extras=yes, review=no,
                   background='fit', readnoise=rdnoise, gain=gain )
    elif arc:
        iraf.apall(image, output=output, references=reference, interactive=no,
                   find=no, recenter=no, resize=no, edit=no, trace=no, fittrace=no,
                   extract=yes, extras=yes, review=no, background='none',
                   readnoise=rdnoise, gain=gain)
    elif (apfile != None):
        ap, lbg, rbg = parse_apfile( apfile )
        if apfact == None:
            apfact = 1.0
        iraf.apall(image, output=output, references='', interactive=interactive,
                   find=no, recenter=yes, resize=no, edit=yes, trace=yes,
                   fittrace=yes, extract=yes, extras=yes, review=yes,
                   background='fit', weights='variance', pfit='fit1d',
                   readnoise=rdnoise, gain=gain, nfind=1, apertures='1',
                   ulimit=20, ylevel=0.01, t_function="legendre", t_order=4,
                   lower=ap[0]*apfact, upper=ap[1]*apfact,
                   b_sample="%.2f:%.2f,%.2f:%.2f" %(lbg[0]*apfact, lbg[1]*apfact, rbg[0]*apfact, rbg[1]*apfact) )
    else:
        raise StandardError( "unacceptable keyword combination" )

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

######################################################################

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
            ftmp.write( '../working/%s\n'%val )
        ftmp.close()
        
        # give the user some feedback
        print '\n\nStarting IDL & cal.pro'
        print 'Standard file:',std
        print 'Input file: cal.input'
        print 'Type "cal"'
        
        start_idl()

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

def sumsqerr(p, x, y):
    low, high, left, right = p
    return np.sum( (y - tophat(x, low, high, left, right))**2 )
    
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
    
    lam: wavelength (A expected)
    flam: flux (ergs/cm^2/sec/A expected)
    Both should be array-like, either 1D or 2D.
     If given 1D arrays, will plot a single spectrum.
     If given 2D arrays, first dimension should correspond to spectrum index.
    title: if given, will place as the title of the plot
    if savefile is given, will save the plot to that file.
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
    
    plt.xlabel(r'Wavelength ($\AA$)')
    plt.ylabel('Flux')

    if savefile != None:
        plt.savefig( savefile )
    
    plt.show()