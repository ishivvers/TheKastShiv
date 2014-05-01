pro womashrebindriver
; this routine rebins data to a new A/pix,  it checks FOR an
; integer number OF bins AND uses quadratic interpolation
; TM
common wom_active, active
COMMON wom_col, col
womdestruct, active, wave, flux, name, npix, header

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
        intnbin = fix(newbin)
        newbintest = newbin-float(intnbin)
        if (newbintest GE 0.000001) then begin
            print, 'NON-INTEGER number of bins'
            rflag = 1
        endif
    endif
endrep until (rflag EQ 0)
;print, intnbin, newdelt, newwave0
nwave = (findgen(intnbin)*newdelt)+newwave0
womashrebin, wave, flux, nwave, nflux
active.wave = nwave
active.flux = nflux
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
