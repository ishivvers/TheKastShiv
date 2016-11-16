pro cal, second

; this routine is a driver for the various idl calibration routines.  It will
; call mkfluxstar, calibrate, mkbstar, and final,  in that order.  You just 
; give it the name of the dispersion corrected fluxstar, the dispersion 
; corrected bstar,  and the list containing the file names of the 
; dispersion corrected objects to go with these stars.  In other words, 
; the iraf output with a 'd' in front.  It will ask for a grating code, 
; and this will be used to identify the flux and b- stars via 
; fluxstarCODE.fits and bstarCODE.fits.  have fun

; TM 1999 march
; 2003 Added second-order option
;
second = 0
IF (n_params() GT 0) THEN second = 1
gratcode = ''
gratcode2 = ''
fluxfile = ''
fluxfile2 = ''
bfile = ''
bfile2 = ''
infile = ''
same = ''
print, ' '
print, 'This program is a driver for the calibration routines.'
print, 'It expects files that have been dispersion calibrated,'
print, 'usually through IRAF (you know, with a -d- in front).'
print, '(In other words, include the d in your file names.)'
print, ' '
print, ' '
print, 'First, should this be an interactive or non-interactive'
print, 'session?  Interactive sessions ask more questions so you'
print, 'have more control, but take longer.'
print, ' '
IF (second EQ 1) THEN BEGIN
    print, 'You have selected second-order correction mode'
    print, ' '
ENDIF

repeat begin
    print, 'Interactive? (y/n)'
    intera = get_kbrd(1)
    intera = strlowcase(intera)
    print, intera
endrep until (intera EQ 'n') or (intera EQ 'y')
print, ' '
print, 'We now need a grating code, such as uv or ir.'
print, 'This will be used to keep track of the fluxstar and'
print, 'bstar as in fluxstaruv.fits or bstarir.fits'
print, ' '
read, 'Enter the grating code: ', gratcode
print, ' '

REPEAT BEGIN
    existflag = 1
    print, 'Now the fits file for the fluxstar.'
    print, ' '
    read, 'Fluxstar file: ', fluxfile
    if (rstrpos(fluxfile, '.ms.fits') EQ -1) then begin
        fluxfile = strcompress(fluxfile + '.ms.fits',  /remove_all)
    endif
    isfile = findfile(fluxfile, COUNT = count)
    if (count EQ 0) then begin
        print, strcompress('File '+fluxfile+' does not exist.')
        existflag = 0
    endif
endrep until (existflag EQ 1)
print, ' '
repeat begin
    print, 'Do you want to use the same star as the b-star? (y/n)'
    same = get_kbrd(1)
    same = strlowcase(same)
    print, same
endrep until (same EQ 'n') or (same EQ 'y')
if (same EQ 'n') then BEGIN
    REPEAT BEGIN
        existflag = 1
        read, 'Enter b-star file: ', bfile
        if (rstrpos(bfile, '.ms.fits') EQ -1) then begin
            bfile = strcompress(bfile + '.ms.fits',  /remove_all)
        ENDIF
        isfile = findfile(bfile, COUNT = count)
        if (count EQ 0) then begin
            print, strcompress('File '+bfile+' does not exist.')
            existflag = 0
        endif
    endrep until (existflag EQ 1)
endif
if (same EQ 'y') then begin
    bfile = fluxfile
endif
bfile =  strcompress('c'+bfile, /remove_all)
IF (second EQ 1) THEN BEGIN
    print, ' '
    read, 'Enter the grating code for second standard: ', gratcode2
    print, ' '
endif
IF (second EQ 1) THEN BEGIN
    REPEAT BEGIN
        existflag = 1
        print, 'Now the fits file for the second fluxstar.'
        print, ' '
        read, 'Fluxstar file: ', fluxfile2
        if (rstrpos(fluxfile2, '.ms.fits') EQ -1) then begin
            fluxfile2 = strcompress(fluxfile2 + '.ms.fits',  /remove_all)
        endif
        isfile = findfile(fluxfile2, COUNT = count)
        if (count EQ 0) then begin
            print, strcompress('File '+fluxfile2+' does not exist.')
            existflag = 0
        endif
    endrep until (existflag EQ 1)
    print, ' '
    repeat begin
        print, 'Do you want to use the same star as the b-star? (y/n)'
        same = get_kbrd(1)
        same = strlowcase(same)
        print, same
    endrep until (same EQ 'n') or (same EQ 'y')
    if (same EQ 'n') then BEGIN
        REPEAT BEGIN
            existflag = 1
            read, 'Enter second b-star file: ', bfile2
            if (rstrpos(bfile2, '.ms.fits') EQ -1) then begin
                bfile2 = strcompress(bfile2 + '.ms.fits',  /remove_all)
            ENDIF
            isfile = findfile(bfile2, COUNT = count)
            if (count EQ 0) then begin
                print, strcompress('File '+bfile2+' does not exist.')
                existflag = 0
            endif
        endrep until (existflag EQ 1)
    endif
    if (same EQ 'y') then begin
        bfile2 = fluxfile2
    endif
    bfile2 =  strcompress('c'+gratcode2+bfile2, /remove_all)
ENDIF

print, ' '
print, 'Now for the file containing the list of objects.'
print, ' '
repeat begin
    existflag = 1
    read, 'Object list file: ', infile
    if (infile EQ '') then retall
    isfile = findfile(infile, COUNT = count)
    if (count EQ 0) then begin
        print, strcompress('File '+infile+' does not exist.')
        existflag = 0
    endif
endrep until (existflag EQ 1)

print, ' '
print, 'OK, here we go.'
print, ' '
print, 'Flux star routine'
realmkfluxstar, fluxfile, gratcode, intera
print, ' '
IF (second EQ 1) THEN BEGIN

    print, 'Second flux star routine'
    realmkfluxstar, fluxfile2, gratcode2, intera
    print, ' '
ENDIF

print, 'Calibration'
calibrate, infile, gratcode, intera;, second, gratcode2
print, ' '
print, 'B-star routine'
realmkbstar, bfile, gratcode, intera
print, ' '
IF (second EQ 1) THEN BEGIN

    print, 'Second B-star routine'
    realmkbstar, bfile2, gratcode2, intera

    print, ' '
ENDIF

print, 'Final calibration (atmos. removal, sky line wave. adjust, etc.)'
final, infile, gratcode, intera;, second, gratcode2
print, ' '
print, 'There, was that so hard?'
print, ' '
end
