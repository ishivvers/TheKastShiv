PRO rebinall

inputfile = ''
xtitleline='!7Observed Wavelength ('+STRING(197B)+')!X'
repeat begin
    existflag = 1
    read,  'Enter name of file with list of spectra to print: ', inputfile

    if (inputfile EQ '') then retall
    isfile = findfile(inputfile, COUNT = count)
    if (count EQ 0) then begin
        print, strcompress('File '+inputfile+' does not exist.')
        existflag = 0
    endif
endrep until (existflag EQ 1)
deltalam = 10.d0
get_lun,  uplot
openr, uplot, inputfile
plotfile = ''
WHILE NOT EOF(uplot) DO BEGIN
    readf, uplot, plotfile
    plotfile = strcompress(plotfile, /remove_all)
    rpl, plotfile, w, f
    npix = n_elements(w)
    w0 = w[0]
    wn = w[npix-1]
    nw0 = ceil(w0/deltalam)*deltalam
    nwn = floor(wn/deltalam)*deltalam
    newbin = (nwn-nw0)/deltalam +1.0
    intnbin = long(newbin)
    nwave = (findgen(intnbin)*deltalam) + nw0
    womashrebin, w, f, nwave, nflux
    pos = strpos(plotfile, '.', /reverse_search)
    newfile = strmid(plotfile, 0, pos)+'-bin'+strmid(plotfile, pos)
    wpl, newfile, nwave, nflux
ENDWHILE
close, uplot
free_lun, uplot
END

