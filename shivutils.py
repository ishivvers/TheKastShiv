"""
Utilities library for the Kast Shiv
 reduction pipeline.

Author: Isaac Shivvers, ishivvers@berkeley.edu

Steals heavily from Brad Cenko's kast_redux and iqutils packages.
(thanks Brad!)


Notes:
 - the scipy.signal.argrelmin function may be helpful to find
    minima in the standard star spectra, afterwhich you can fit
    with spectools.
 - e.g.: mins = scipy.signal.argrelmin( fl, order=25 )

 - for now, use pIDLy with the IDL.interact() command to run cal.pro, etc
 example: idl.pro("kastbias",'r6.fits',y1=46,y2=246)
"""

######################################################################
# imports
######################################################################

# installed
import numpy as np
import matplotlib.pyplot as plt
import pyfits as pf
from pidly import IDL
from pyraf import iraf
from glob import glob
from scipy.optimize import minimize
from dateutil import parser as date_parser
from BeautifulSoup import BeautifulSoup
from difflib import get_close_matches
import urllib
import os
import re


# local
import cosmics as cr
import credentials

######################################################################
# global variables
######################################################################

# kast parameters
REDBIAS='[1201:1231,*]'
REDTRIM='[1:1200,%d:%d]'
REDGAIN=3.0
REDRDNOISE=12.5
BLUEBIAS1='[2052:2080,*]'
BLUEBIAS2='[2082:2110,*]'
BLUETRIM1='[1:1024,%d:%d]'
BLUETRIM2='[1025:2048,%d:%d]'
BLUEGAIN1=1.2
BLUEGAIN1=1.237
BLUERDNOISE=3.7

# location of line id list
COORDLIST='/indirect/big_scr5/ishivvers/kastreductions/TheKastShiv/licklinelist.dat'

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
    os.mkdir('uc')
    os.chdir('uc')
    os.mkdir('rawdata')
    os.mkdir('working')
    os.mkdir('final')
    os.chdir('..')

############################################################################

def parse_logfile( logfile ):
    """
    Parse a logfile in e-log format.
    Returns image numbers for objects, arcs, and flats as 
     three lists, containing [obs, side, group] for each image
    """
    objects, flats, arcs = [],[],[]
    lines = open(logfile, 'r').readlines()
    for line in lines[1:]:  #first line should be a header
        line = line.split()
        which = line[-1]
        side, group = map(int, line[1:3])
        
        # handle individual object numbers or ranges
        if '-' in line[0]:
            i,j = map(int, line[0].split('-'))
            obs = range( i, j+1 )
        else:
            obs = [int(line[0])]
        
        if which == 'obj':
            whichlist = objects
        elif which == 'flat':
            whichlist = flats
        elif which == 'arc':
            whichlist = arcs
        else:
            raise StandardError("error parsing %s"%logfile)
        for ob in obs:
            whichlist.append( [ob, side, group] )
    
    return objects, flats, arcs

############################################################################

def populate_working_dir( runID, logfile=None ):
    """
    Take the unpacked data from the raw directory, rename files as necessary,
     and move them into the working directory.
    Should be run from root directory, logfile should be wiki
     e-log format.
     If logfile not given, assumes logfile=runID.log
    """
    if logfile == None:
        logfile = runID+'.log'
    
    # parse the logfile
    objects,flats,arcs = parse_logfile(logfile)
    
    # copy over all relevant files to working directory and rename them
    for o in objects+flats+arcs:
        if o[1] == 1:
            run_cmd( 'cp rawdata/b%d.fits working/%sblue%.3d.fits' %(o[0],runID,o[0]) )
        elif o[1] == 2:
            run_cmd( 'cp rawdata/r%d.fits working/%sred%.3d.fits' %(o[0],runID,o[0]) )
    
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

def start_idl( idlpath='/apps3/rsi/idl_8.1/bin/idl' ):
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


def wiki2elog( datestring=None, runID=None, pagename=None, outfile=None,
               un=credentials.wiki_un, pw=credentials.wiki_pw ):
    """
    Download and parse the log from the wiki page.
    - datestring: a parsable string representing the recorded log's date
    - runID: the alphabetical id for the run
    - pagename: if given, will override the constructed page name and download
      the wiki page given
    NOTE: must have (datestring and runID) OR pagename
    - outfile: include a path to write out a silverclubb-formatted logfile, if desired
    """
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
        rows = table.findAll('tr')
    
    if outfile != None:
        output = open(outfile,'w')
        output.write('Obs     Side  Group  Type\n')
    
    objects, arcs, flats = [], [], []
    for row in rows[1:]: #skip header row
        cols = row.findAll('td')
        try:
            obsnum = int(cols[0].string)
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
            objname = cols[1].string.lower().strip('uv').strip('ir').strip()
            objects.append( [obsnum, sidenum, groupnum, objname])
        elif obstype == 'arc':
            arcs.append( [obsnum, sidenum, groupnum] )
        elif obstype == 'flat':
            flats.append( [obsnum, sidenum, groupnum] )
        
        if outfile != None:
            output.write( "%d %6.d %6.d %s" %(1, sidenum, groupnum, obstype.rjust(7))
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

def bias_correct_idl(images, y1, y2, prefix=None, idlpath='/apps3/rsi/idl_8.1/bin/idl'):
    """
    Use pIDLy to interact with the trusty 'kastbias.pro' script
     to bias correct a set of images with y trim limits of y1, y2.
    NOTE: your IDL installation must know the location of 'kastbias.pro'
    """
    if prefix==None:
        prefix = 'b'
    idl = IDL( idlpath )
    for image in images:
        idl.pro("kastbias",image,y1=y1,y2=y2,prefix=prefix)
    idl.close()

############################################################################

def bias_correct(images, y1, y2, prefix=None):
    '''
    Bias correct a set of images with y trim limits of y1, y2.
    NOTE: the original kast_bias.pro script incorporates the "gain" of
          each amplifier independently, but it looks like ccdproc does
          not do this.  If important, will need to hardcode own version
          of kast_bias.pro.
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

def make_flat(images, outflat, side, interactive=True, cleanup=True):

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
    iraf.flatcombine(flatimages, output='CombinedFlat', combine='median', 
                     reject='ccdclip', ccdtype='', process=no, subsets=no,
                     delete=no, scale='median', lsigma=3.0,
                     hsigma=3.0, gain=gain, rdnoise=rdnoise)
    # fit for the response function and save as the output
    iraf.response('CombinedFlat', 'CombinedFlat', outflat, order=fitorder, interactive=interact)
    
    if cleanup:
        run_cmd( 'rm CombinedFlat.fits' )

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
    iraf.uvfixhead(images)
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
    Apply the wavelength solution from arc to image
    """
    iraf.disp( image, arc )

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
    s = open(apfile,'r').read()
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
    
    if (reference == None) & (arc == False):
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
                   b_sample="%.2f:%.2f,%.2f::.2f" %(lbg[0]*apfact, lbg[1]*apfact, rbg[0]*apfact, rbg[1]*apfact) )
    else:
        raise StandardError( "unacceptable keyword combination" )

############################################################################
# cosmic ray removal
############################################################################

def clean_cosmics( fitspath, cleanpath, side, maskpath=None ):
    """
     clean an input fits file using the LACOS algorithm 
    
    - fitspath: input file
    - cleanpath: output file
    - side: one of 'blue','red'
    - maskpath: [optional] mask output file
    """
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
    
