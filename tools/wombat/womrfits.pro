pro womrfits
common wom_active, active
inputfile = ''
repeat begin
    existflag = 1
    print, ' '
    print,  'What is the name of the file to read? (.fits will be added,' $
      + 'if necessary): '
    read,  ': ', inputfile
    if (inputfile EQ '') then return
    inputfile = strtrim(inputfile, 2)
    splits = strsplit(inputfile,'-[0-9]+.+[0-9]+-',/extract,/regex)
    date = stregex(inputfile,'-[0-9]+.+[0-9]+-',/extract)
    errfile = strcompress(splits[0]+date+'variance-'+splits[1],/remove_all)
    if (rstrpos(inputfile, '.fits') EQ -1) then begin
      inputfile = strcompress(inputfile+'.fits', /remove_all)
      errfile = strcompress(errfile+'.fits', /remove_all)
    endif
    isfile = findfile(inputfile, COUNT = count1)
    isfile = findfile(errfile, COUNT = count2)
    if (count1 EQ 0) then begin
        print, strcompress('File '+inputfile+' does not exist.')
        existflag = 0
    endif
endrep until (existflag EQ 1)
flux = readfits(inputfile, spechead)
crval1 = float(sxpar(spechead, 'CRVAL1'))
wdelt = float(sxpar(spechead, 'CDELT1'))
if (wdelt EQ 0) then wdelt = float(sxpar(spechead, 'CD1_1'))
objectname = sxpar(spechead, 'OBJECT')
sizeo = size(objectname, /type)
if (sizeo NE 7) then begin
    objectname = inputfile
endif
print, strcompress('The object is '+objectname)
npix = n_elements(flux)
wave = findgen(npix) * wdelt + crval1
if (count2 NE 0) then err = readfits(errfile) else err = fltarr(npix) + 1.

spectrim = strtrim(spechead, 1)
realspace = where(strlen(spectrim) EQ 80)
spectrim = spectrim(realspace)
active.wave = wave
active.flux = flux
active.err = err
active.obname = objectname
active.head = spectrim
active.nbin = npix
end
