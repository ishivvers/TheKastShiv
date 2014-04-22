"""
Utilities library for the Kast Shiv
 reduction pipeline.

Author: Isaac Shivvers, ishivvers@berkeley.edu

Steals heavily from Brad Cenko's kast_redux and iqutils packages.
(thanks Brad!)
"""

import numpy as np
import pyfits as pf
import cosmics as cr
from os import path, system
from pyraf import iraf
from types import ListType, StringType

######################################################################
# global variables, kast-specific
######################################################################
REDBIAS='[1201:1231,*]'
REDTRIM='[1:1200,11:170]'
REDGAIN=3.0
REDRDNOISE=12.5
BLUEBIAS1='[2052:2080,*]'
BLUEBIAS2='[2082:2110,*]'
BLUETRIM1='[1:1024,31:300]'
BLUETRIM2='[1025:2048,31:300]'
BLUEGAIN=1.2
BLUERDNOISE=3.7
COORDLIST='./caldir/licklinelist.dat'

######################################################################
# file and os management
######################################################################

def update_head(inlist,inkeys,invals,comments="",extn=0):
    """
     update header keywords using pyfits
    """
    
    # Images to process
    if type(inlist) is ListType:
        infiles=inlist
    elif type(inlist) is StringType:
        infiles=iraffiles(inlist)
    else:
        raise StandardError( "Please pass a string or list of input files" )

    # Input checking
    if type(inkeys)==ListType and type(invals)!=ListType:
        raise StandardError( "Keywords and values must both be lists" )

    # Header keywords to update
    if type(inkeys) is StringType:
        keys=[inkeys]
        vals=[invals]
        cmts=[comments]
    elif type(inkeys) is ListType:
        keys=inkeys
        vals=invals
        if type(comments) is ListType:
            cmts=comments
        else:
            cmts=None
    else:
        raise StandardError( "Please pass a string or list of header keywords to update" )

    # Loop over files
    nkeys=len(keys)
    for file in infiles:

        check_exist(file,"r")
        inf=pyfits.open(file,"update")

        if extn>=len(inf):
            inf.close()
            raise StandardError( "Requested extension [%d] does not exist" % extn )

        for i in xrange(nkeys):
            if cmts:
                inf[extn].header.update(keys[i],vals[i],comment=cmts[i])
            else:
                inf[extn].header.update(keys[i],vals[i])

        inf.close()


def get_head(file,keys,extn=0,verbose=globver):

    """ reads one or more header keywords from a FITS file
        using PyFITS """

    vals=[]
    check_exist(file,"r")

    try:
        fimg=pyfits.open(file)
        if extn>=len(fimg):
            if verbose:
                print "Requested extension [%d] does not exist" % extn
            vals=[""]*len(keys)
            return vals

        head=fimg[extn].header

        if type(keys)==StringType:
            key=keys
            if head.has_key(key):
                vals=head[key]
            else:
                if verbose:
                    print "Error reading keyword %s from %s" % (key,file)
                vals=""
        elif type(keys)==ListType:
            for key in keys:
                if head.has_key(key):
                    vals.append(head[key])
                else:
                    if verbose:
                        print "Error reading keyword %s from %s" % (key,file)
                    vals.append("")
        else:
            if verbose:
                print "Bad variable type for keys"
        fimg.close()

    except:
        print "Error reading header of %s" % file
        vals=[""]*len(keys)

    return vals
    

def run_cmd( cmd, ignore_errors=False ):
    """
    Wrapper for running external commands.
    """
    res = system( cmd )
    if not ignore_errors:
        if res != 0:
            raise StandardError( "Error ::: command failed :::" )


############################################################################
# bias and flatfielding
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