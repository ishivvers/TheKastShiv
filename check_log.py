"""
A python script to check an online wiki e-log for proper format.
"""

import urllib
import re
import pyfits as pf
from glob import glob
# The names of these packages are different between my mac and my linux
try:
    from bs4 import BeautifulSoup
except:
    print 'Cannot locate package bs4, trying BeautifulSoup'
    from BeautifulSoup import BeautifulSoup
from difflib import SequenceMatcher
from credentials import wiki_un, wiki_pw

def wiki2log( pagename, outfile=None ):
    """
    Given a pagename (the string after id= in the wiki page URL),
     returns lists of objects, arcs, flats.  Each entry is formatted:
     [obs #, side #, group #, object name]
    If outfile is given, will save the log to that as an ascii file.
    Note: only includes UVIR observations (sides 1,2)
    """
    creds = urllib.urlencode({"u" : wiki_un, "p" : wiki_pw})

    # open the Night Summary page for the run
    soup = BeautifulSoup( urllib.urlopen("http://hercules.berkeley.edu/wiki/doku.php?id="+pagename,creds) )

    # make sure the table is there
    if soup.body.table == None:
        raise StandardError( "wiki page did not load; are your credentials in order?" )
    else:
        rows = soup.body.table.findAll('tr')

    if outfile != None:
        # Here is the output table format
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
            objname = cols[1].string.encode('ascii','ignore').lower().strip()
            for match in re.findall('[UuIi][VvRr]', objname ):
                objname = objname.replace(match,'')
            objname = objname.strip()
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

        if outfile != None:
            # add to output log 
            if obstype == 'obj':
                output.write( "%s %s %s %s %s\n" %(cols[0].string.strip().ljust(8), cols[2].string.strip().ljust(6),
                                                cols[3].string.strip().ljust(6), obstype.ljust(8), objname) )
            else:
                output.write( "%s %s %s %s\n" %(cols[0].string.strip().ljust(8), cols[2].string.strip().ljust(6),
                                                    cols[3].string.strip().ljust(6), obstype) )
    if outfile != None:
        output.close()
    return objects, arcs, flats


def load_elog( infile ):
    # parse a local log, skip the header
    objects, arcs, flats = [], [], []
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

    return objects, arcs, flats

def check_log( localfile=None, pagename=None, path_to_files=None ):
    """
    Returns a boolean tuple: (pass, warning)
    Either localfile or pagename must be given.
     localfile : path to the logfile, or path to save the logfile to
     pagename : if given, will download wiki elog from there (string after 'id=' in wiki URL)
     path_to_files : if given, will check all of the fits files in that folder against this log.
                     files must be named in Lick format (i.e. 'r31.fits')
    """
    if pagename != None:
        objects, arcs, flats = wiki2log( pagename )
    elif localfile != None:
        objects, arcs, flats = load_elog( localfile )
    else:
        raise Exception( 'Must include either pagename of localfile' )
    warning = False
    
    # assert that no observations are repeated
    allblues = [l[0] for l in objects+arcs+flats if l[1] == 1]
    overlaps = set( [l for l in allblues if allblues.count(l) > 1] )
    if overlaps:
        raise Exception( 'The following blue exposure numbers are used more than once: '+','.join( map(str,overlaps) ) )
    allreds = [l[0] for l in objects+arcs+flats if l[1] == 2]
    overlaps = set( [l for l in allreds if allreds.count(l) > 1] )
    if overlaps:
        raise Exception( 'The following red exposure numbers are used more than once: '+','.join( map(str,overlaps) ) )

    # assert that each red object has associated arcs and flats
    redobjs = [o for o in objects if o[1] == 2]
    for o in redobjs:
        thesearcs = [a for a in arcs if (a[1] == 2 and a[2] == o[2])]
        if not thesearcs:
            raise Exception( 'The following object has no associated arcs: \n' +\
                             ' red %d ::: group %d' %(o[0],o[2]) )
        elif len(thesearcs) != 1:
            # usually the first red object has the 0.5" arcs too; don't raise a warning for that
            if o[2] != 2:
                print 'Warning: the following object has %d arcs associated with it:\n'%len(thesearcs) +\
                      ' red %d ::: group %d' %(o[0],o[2])
                print
                warning = True
        theseflats = [f for f in flats if (f[1] == 2 and f[2] == o[2])]
        if not theseflats:
            raise Exception( 'The following object has no associated flats: \n' +\
                             ' red %d ::: group %d' %(o[0],o[2]) )
        elif len(theseflats) != 3:
            print 'Warning: the following object has %d flats associated with it:\n'%len(theseflats) +\
                  ' red %d ::: group %d' %(o[0],o[2])
            print
            warning = True

    # assert that blue arcs and flats exist, and that all blue objects are associated with them
    bluearcs = [a for a in arcs if a[1] == 1]
    if not bluearcs:
        raise Exception( 'No blue arcs included.' )
    blueflats = [f for f in flats if f[1] == 1]
    if not blueflats:
        raise Exception( 'No blue flats included' )
    bluemismatch = [o for o in objects if (o[1] == 1 and o[2] != 1)]
    if bluemismatch:
        raise Exception( 'The following objects are listed as side 1, but not group 1:\n' +\
                         '\n'.join( [' blue %d' %o[1] for o in bluemismatch] ) )

    if path_to_files != None:
        # go through each file and assert that it exists and is the type it's supposed to be
        # Note that this checks whether the fits header says the lamps are on, but that can be incorrect
        #  because observers sometimes switch the lamps on/off right after the observation ends (but before
        #  the exposure is done reading out).
        for a in arcs:
            if a[1] == 1:
                pre = 'b'
            else:
                pre = 'r'
            hdu = pf.open( path_to_files + '/%s%d.fits'%(pre, a[0]) )[0]
            if 'arc' not in hdu.header['object'].lower():
                print 'Warning: %s%d.fits may not be an arc! (group ::: %d)' %(pre, a[0], a[2])
                print 'Object name:',hdu.header['object']
                print
                warning = True
            if [hdu.header[k] for k in hdu.header.keys() if 'LAMPSTA' in k].count('on') < 1:
                print 'Warning: maybe no arclamps on during arclamp observation %s%d.fits?'%(pre, a[0])
                warning = True
        
        for f in flats:
            if f[1] == 1:
                pre = 'b'
            else:
                pre = 'r'
            hdu = pf.open( path_to_files + '/%s%d.fits'%(pre, f[0]) )[0]
            if 'flat' not in hdu.header['object'].lower():
                print 'Warning: %s%d.fits may not be a flat! (group ::: %d)'%(pre, f[0], f[2])
                print 'Object name:',hdu.header['object']
                print
                warning = True
            if [hdu.header[k] for k in hdu.header.keys() if 'LAMPSTA' in k].count('on') < 1:
                print 'Warning: maybe no lamps on during flat observation %s%d.fits?'%(pre, f[0])
                warning = True

        for o in objects:
            if o[1] == 1:
                pre = 'b'
            else:
                pre = 'r'
            hdu = pf.open( path_to_files + '/%s%d.fits'%(pre, o[0]) )[0]
            if ('flat' in hdu.header['object'].lower()) or ('arc' in hdu.header['object'].lower()):
                print 'Warning: %s%d.fits may not be an object! (group ::: %d)'%(pre, o[0], o[2])
                print ' Log object name: %s ::: Fits file object name: %s' %(o[4], hdu.header['object'])
                print
            elif SequenceMatcher( a=o[4].lower(), b=hdu.header['object'].lower() ).ratio() < 0.5:
                print 'Warning: %s%d.fits may not be the correct object!'%(pre, o[0])
                print ' Log object name: %s ::: Fits file object name: %s' %(o[4], hdu.header['object'])
                print
            if [hdu.header[k] for k in hdu.header.keys() if 'LAMPSTA' in k].count('on') > 0:
                print 'Warning: lamp may have been on during object observation %s%d.fits!'%(pre, o[0])

    return True, warning

if __name__ == '__main__':
    from sys import argv,exit
    try:
        pagename = argv[1]
        assert( type(pagename) == str )
    except:
        print 'Usage: check_log.py <wiki page ID>'
        exit()
    
    success, warning = check_log( pagename )
    
