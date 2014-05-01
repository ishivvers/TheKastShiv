pro wombin
; this routine rebins data to a new A/pix,  it checks FOR an
; integer number OF bins 
; TM

common wom_active, active
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, header

print, strcompress('Current A/pix is '+string(wave[1]-wave[0]))
print, ' '
print, strcompress('Wavelength range: '+string(wave[0])+':'+ $
                   string(wave[npix-1]))
print, ' '
repeat begin
    rflag = 0
    newdelt = ''
    read, 'Rebin to how many Angstroms per pixel? ', newdelt
    newdelt = float(newdelt)
    womwaveparse, wave, wavestring, npix
    newwave0 = float(wavestring[0])
    newwaven = float(wavestring[1])
    if (newwave0 EQ 0) and (newwaven EQ 0) then begin
        print, 'Enter numbers'
        rflag = 1
    endif
    if (newwave0 GT newwaven) then begin
        print, 'Second wavelength must be larger than first'
        rflag = 1
    endif
    if (newdelt LE 0) then rflag = 1
    if (rflag EQ 0) then begin
        newbin = (newwaven-newwave0)/newdelt +1.0
        intnbin = long(newbin)
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
    endif
endrep until (rflag EQ 0)
nwave = (findgen(intnbin)*newdelt)+newwave0

;womashrebin, wave, flux, nwave, nflux
;wompixrebin, wave, flux, nwave, nflux
;newrebin, wave, flux, nwave, nflux3
womidlterp, wave, flux, nwave, nflux
womidlterp, wave, err, nwave, nerr
active.wave = nwave
active.flux = nflux
active.err  = nerr
active.nbin = newbin
womheaderfix, header, nwave, newbin
active.head = header
print, ' '
print, 'Overplotting rebinned spectrum in red.'
print, ' '
plot, wave, flux, xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = name, color = col.white
oplot, nwave[0:newbin-1], nflux[0:newbin-1], psym = 10, color = col.red
wshow
end
