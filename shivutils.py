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
"""

######################################################################
# imports
######################################################################

import numpy as np
import pyfits as pf
import cosmics as cr
from os import path, system
from pyraf import iraf
from types import ListType, StringType

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
COORDLIST='./caldir/licklinelist.dat'

# useful for iraf interactions
yes=iraf.yes
no=iraf.no
INDEF=iraf.INDEF

######################################################################
# fits file management
######################################################################

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

def run_cmd( cmd, ignore_errors=False ):
    """
    Wrapper for running external commands.
    """
    res = system( cmd )
    if not ignore_errors:
        if res != 0:
            raise StandardError( "Error ::: command failed ::: "+cmd )

############################################################################
# bias and flatfielding
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
            root,ext=path.splitext(image)
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
            head_update(outname, ['CCDSEC', 'DATASEC'],
                        ['[1:2048,1:%d]'%(y2-y1+1), '[1:2048,1:%d]'%(y2-y1+1)])
        
        # add the dispersion axis keyword, saying the x axis is the wavelength axis
        head_update(outname, 'DISPAXIS', 1 )
    
############################################################################    

def redbias(images, prefix=None, biassec=REDBIAS, trimsec=REDTRIM):
    '''
    Subtract overscan and trim red frames
    
    If prefix is given, will add that prefix to every image before saving.
     Otherwise, overwrites input file.'''
    
    if type(images) != list:
        images = [images]
    if prefix == None:
        outputs = ["" for i in images]
    else:
        outputs = [prefix+i for i in images]
    for i,image in enumerate(images):
        iraf.ccdproc(image, output=outputs[i], ccdtype='', noproc=no, fixpix=no,
                     overscan=yes,trim=yes, zerocor=no, darkcor=no, flatcor=no,
                     illumcor=no, fringecor=no, readcor=no, scancor=no,
                     biassec=biassec, trimsec=trimsec)
        if prefix == None:
            update_head(image, 'DISPAXIS', 1)
        else:
            update_head(outputs[i], 'DISPAXIS', 1)
    return

#############################################################################

def bluebias(images, prefix=None, biassec1=BLUEBIAS1, trimsec1=BLUETRIM1, 
             biassec2=BLUEBIAS2, trimsec2=BLUETRIM2, cleanup=True):

    '''
    Subtract overscan and trim blue frames.
    Accounts for both amplifiers in the Kast blue side.
    
    If prefix is given, will add that prefix to every image before saving.
     Otherwise, overwrites input file.
    '''
    
    if type(images) != list:
        images = [images]
    if prefix == None:
        outputs = ["" for i in images]
    else:
        outputs = [prefix+i for i in images]
 
    for i,image in enumerate(images):

        root,ext=path.splitext(image)
        iraf.ccdproc(image, output='%s_1' % root, ccdtype='', noproc=no, 
                     fixpix=no, overscan=yes, trim=yes, zerocor=no, 
                     darkcor=no, flatcor=no, illumcor=no, fringecor=no, 
                     readcor=no, scancor=no, biassec=biassec1, 
                     trimsec=trimsec1)
        iraf.ccdproc(image, output='%s_2' % root, ccdtype='', noproc=no, 
                     fixpix=no, overscan=yes, trim=yes, zerocor=no, 
                     darkcor=no, flatcor=no, illumcor=no, fringecor=no, 
                     readcor=no, scancor=no, biassec=biassec2, 
                     trimsec=trimsec2)
        iraf.imjoin('%s_1,%s_2' % (root, root), 'j%s' % image, 1)
        if cleanup:
            run_cmd( 'rm %s_1 %s_2' % (root, root) )
        if prefix == None:
            # replace input file
            outname = image
        else:
            # create output file
            outname = outputs[i]
        run_cmd( 'mv j%s %s' % (image, outname) )
        update_head(outname, 'DISPAXIS', 1)
        update_head(outname, ['CCDSEC', 'DATASEC'], ['[1:2048,1:270]', '[1:2048,1:270]'])

############################################################################

def make_flat(images, outflat, gain=1.0, rdnoise=0.0, xwindow=50,
              ywindow=50, hmin=0, hmax=65535, lowclip=0.7, highclip=1.3,
              cleanup=True):

    '''Construct flat field from individual frames'''
    
    flatimages=','.join(images)
    # combine the flats
    iraf.flatcombine(flatimages, output='CombinedFlat', combine='median', 
                     reject='avsigclip', ccdtype='', process=no, subsets=no,
                     delete=no, clobber=no, scale='median', lsigma=3.0,
                     hsigma=3.0, gain=gain, rdnoise=rdnoise)
    # divide by the median
    iraf.fmedian('CombinedFlat', 'MedianFlat', xwindow, ywindow, hmin=hmin, hmax=hmax)
    iraf.imarith('CombinedFlat', '/',  'MedianFlat', outflat)
    # clip the result, so no values are beyond the clip limits
    iraf.imreplace(outflat, 1.0, lower=INDEF, upper=lowclip)
    iraf.imreplace(outflat, 1.0, lower=highclip, upper=INDEF)

############################################################################

def reference_arc(image, output, reference, coordlist=COORDLIST):

    '''Construct reference wavelength solution from arc lamps'''

    iraf.apall(image, output=output, references=reference, interactive=no,
               find=no, recenter=no, resize=no, edit=no, trace=no, fittrace=no,
               extract=yes, extras=yes, review=no, background='none')
    iraf.identify(output, coordlist=coordlist)

######################################################################
# cosmic ray removal
######################################################################

def clean_cosmics( fitspath, cleanpath, gain, rdnoise, maskpath=None ):
    """
     clean an input fits file using the LACOS algorithm 
    
    - fitspath: input file
    - cleanpath: output file
    - gain, rdnoise: lacos parameters
    - maskpath: [optional] mask output file
    """
    sigclip = 4.5  # additional lacos parameters
    sicfrac = 0.5
    objlim = 1.0
    maxiter = 3
    array, header = cr.fromfits(fitspath)
    c = cr.cosmicsimage(array, gain=gain, readnoise=rdnoise,
                        sigclip=sigclip, sigfrac=sigfrac, objlim=objlim)
    c.run(maxiter=maxiter)
    cr.tofits(cleanpath, c.cleanarray, header)
    if maskpath != None:
        cr.tofits(maskpath, c.mask, header)
    return