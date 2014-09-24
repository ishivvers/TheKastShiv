"""
A python script to check an online wiki e-log for proper format.
"""

wiki_un = 'ishivvers'
wiki_pw = 'bojangles'

def wiki2logfile( pagename, outfile=None ):
    if outfile == None:
        outfile = pagename + '.log'
    
    creds = urllib.urlencode({"u" : wiki_un, "p" : wiki_pw})

    # open the Night Summary page for the run
    soup = BeautifulSoup( urllib.urlopen("http://hercules.berkeley.edu/wiki/doku.php?id="+pagename,creds) )

    # make sure the table is there
    if soup.body.table == None:
        raise StandardError( "wiki page did not load; are your credentials in order?" )
    else:
        rows = soup.body.table.findAll('tr')

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

        # add to output log 
        if obstype == 'obj':
            output.write( "%s %s %s %s %s\n" %(cols[0].string.strip().ljust(8), cols[2].string.strip().ljust(6),
                                            cols[3].string.strip().ljust(6), obstype.ljust(8), objname) )
        else:
            output.write( "%s %s %s %s\n" %(cols[0].string.strip().ljust(8), cols[2].string.strip().ljust(6),
                                                cols[3].string.strip().ljust(6), obstype) )
    output.close()


def load_elog( infile ):
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

    return objects, arcs, flats

def check_log( localfile, pagefile=None ):
    
    if pagefile != None:
        wiki2logfile( pagefile, outfile=localfile )
    objects, arcs, flats = load_elog( localfile )
    
    # assert that no observations are repeated
    
        