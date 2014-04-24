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
import pyfits as pf
from pidly import IDL
from pyraf import iraf
from glob import glob
from scipy.optimize import minimize
from dateutil import parser as date_parser
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
COORDLIST='./caldir/licklinelist.dat'

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
    Returns objects, flats, and arcs as 
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
        if o[1] == 'r':
            run_cmd( 'cp rawdata/r%d.fits working/%sred%.3d.fits' %(o[0],runID,o[0]) )
        elif o[1] == 'b':
            run_cmd( 'cp rawdata/r%d.fits working/%sred%.3d.fits' %(o[0],runID,o[0]) )
    
    '''
    TO DO: return objects that keep track of which arcs/flats/etc go with which object.
    '''
    

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

def start_idl( idlpath = '/usr/bin/idl' ):
    """
    start an interactive IDL session.
    """
    session = IDL( idlpath )
    session.interact()
    session.close()

def get_kast_data( datestring, outfile=None, unpack=True,
                   un=credentials.repository_un, pw=credentials.repository_pw ):
    """
    Download kast data from a date (in the datestring).
    """
    if outfile == None:
        outfile = datestring+'.alldata.tgz'
    date = date_parser.parse(datestring)
    print 'downloading data from %s-%s-%s (Y-M-D)' %(date.year, date.month, date.day)
    cmd = 'wget --no-check-certificate --http-user="%s" --http-passwd="%s" '+\
            '-O %s "https://mthamilton.ucolick.org/data/%s-%s/%s/shane/?tarball=true&allfiles=true"' \
            %(un, pw, outfile, date.year, date.month, date.day))
    run_cmd(cmd)
    if unpack:
        cmd = 'tar -xzvf %s' %outfile
        run_cmd(cmd)

def wiki2elog( datestring, runID, pagename=None, outfile=None,
               un=credentials.wiki_un, pw=credentials.wiki_pw ):
    """
    Download and parse the log from the wiki page.  Stolen heavily
     from K.Clubb's "wiki2elog.py" (thanks Kelsey!)
    - datestring: a parsable string representing the recorded log's date
    - runID: the alphabetical id for the run
    - pagename: if given, will override the constructed page name and downloading
      the wiki page given
    - outfile: the output file; runID.log if not given
    """
    if outfile == None:
        outfile = runID+'.log'
    
    # construct the pagename and credentials request
    if pagename == None:
        date = date_parser.parse(datestring)
        pagename = "%.2d_%.2d_kast_%s" %(date.month, date.day, runID)
    creds = urllib.urlencode({"u" : un, "p" : pw})
    # define lists to hold observation data
    obs= []
    side = []
    group = []
    types = []
    # open the Night Summary page for the run
    page = urllib.urlopen("http://hercules.berkeley.edu/wiki/doku.php?id="+pagename,creds)
    lines = page.readlines()
    page.close()

    # go through the HTML to find the beginning of the actual wiki page
    line_num=0
    while lines[line_num].strip()!='<!-- wikipage start -->':
        line_num += 1 
    line_num += 1
    while lines[line_num].strip()=='':
        line_num += 1
    # if permission was denied, alert user and end program
    if lines[line_num].find("Permission Denied")!=-1:
        raise StandardError( 'Username/password combination invalid for the FlipperWiki!' )

    # loop through the entire table (assuming that all of the observations are listed there)
    while lines[line_num].strip()!='</table>':
        # assume each table row tag is an image (or run of images)
        if lines[line_num].find('</td>')!=-1:
            # break line into each table entry
            pieces = lines[line_num].split('</td>')
            if pieces[2].strip().split('>')[1].strip()!='x':
                # get Obs #
                obs += [pieces[0].strip().split('>')[1].strip()]
                # get Side
                side += [pieces[2].strip().split('>')[1].strip()]
                # get Group
                group += [pieces[3].strip().split('>')[1].strip()]
                # get Type
                types += [pieces[4].strip().split('>')[1].strip()]
        # go to next line
        line_num += 1

    # write all observations to file and close it
    output = open(outfile,'w')
    output.write('Obs     Side  Group  Type\n')
    for n in range(len(obs)):
        output.write(obs[n]+' '*(8-len(obs[n]))+side[n]+' '*(6-len(side[n]))+group[n]+' '*(7-len(group[n]))+types[n]+'\n')
    output.close()

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

def bias_correct_idl(images, y1, y2, prefix=None, idlpath = '/usr/bin/idl'):
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

def update_headers(images):
    """
    run uvfixhead (custom IRAF task) and calculate the airmass values
    """
    for image in images:
        iraf.uvfixhead(image)
        iraf.setairmass(image)

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
    
    p0 = [np.min(y), np.median(y), 10, len(x)-10]
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
    
    
    