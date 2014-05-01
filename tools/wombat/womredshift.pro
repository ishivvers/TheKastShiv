pro womredshift
common wom_active, active
womdestruct, active, wave, flux, err, name, npix, spechead

newdelt = wave[1]-wave[0]
c = 2.997925E5
print, strcompress('Current A/pix is '+string(wave[1]-wave[0]))
print, ' '
print, strcompress('Wavelength range: '+string(wave[0])+':'+ $
                   string(wave[npix-1]))
print, ' '
repeat begin
    print, 'Remove redshift in (z) or (k)m/s? (z/k) '
    r = get_kbrd(1)
    r = strlowcase(r)
    print, r
endrep until (r EQ 'z') or (r EQ 'k')
print, ' '
z = ''
read, 'Enter the redshift (positive is away from us): ', z
z = float(z)
if (r EQ 'k') then begin
    z = sqrt((1.0 + z/c)/(1.0 - z/c)) - 1.0
endif
wave = wave / (1+z)
print, ' '
print, strcompress('New wavelength range: '+string(wave[0])+':'+ $
                   string(wave[npix-1]))

repeat begin
    print, ' '
    print, 'Rebin spectrum? (y/n default n) '
    b = get_kbrd(1)
    if ((byte(b))[0] EQ 10) then b = 'n'
    b = strlowcase(b)
    print, b
endrep until (b EQ 'y') OR (b EQ 'n')
if (b EQ 'y') then begin
    repeat begin
        rflag = 0
        womwaveparse, wave, wavestring, npix
        newwave0 = float(wavestring[0])
        newwaven = float(wavestring[1])    
        newbin = (newwaven-newwave0)/newdelt +1.0
        intnbin = fix(newbin)
        newbintest = newbin-float(intnbin)
        if (newbintest GE 0.000001) then begin
            print, 'NON-INTEGER number of bins'
            rflag = 1
            print, ' '
            testwave = newdelt*intnbin+newwave0
            REPEAT begin
                print, 'Closest match is: '
                print, string(newwave0)+' '+string(testwave)
                print, 'Would you like this wavelength range?' + $
                  ' (y/n, default=y) '
                c = get_kbrd(1)
                c = strlowcase(c)
                if ((byte(c))[0] EQ 10) then c = 'y'
                print, c
            endrep until (c EQ 'y') or (c EQ 'n')            
            IF (c EQ 'y') THEN BEGIN
                rflag = 0
                newwaven = testwave
            endif
        endif
    endrep until (rflag EQ 0)
    nwave = (findgen(intnbin)*newdelt)+newwave0
    womidlterp, wave, flux, nwave, nflux
    womidlterp, wave, err, nwave, nerr
    active.wave = nwave
    active.flux = nflux
    active.err  = nerr
    active.nbin = newbin
    womheaderfix, spechead, nwave, newbin
    active.head = spechead
endif else if (b EQ 'n') then begin
    active.wave = wave
endif
end
