pro womlinesub
common wom_active, active
common wom_ulog, ulog
COMMON wom_col, col
device, cursor_standard = 33
!Y.STYLE = 16
us = findgen(48)*(!PI*2/48.0)
usersym, cos(us), sin(us), /fill
womdestruct, active, wave, flux, err, name, npix, header
oldwave = wave
oldflux = flux
oldnpix = npix
print, ' '
print, strcompress('Object is '+name)
print, ' '
print, strcompress('Spectrum runs from '+string(wave[0])+' to '+ $
                   string(wave[npix-1])+'.')
print, ' '

print, 'Select a subset of the spectrum'
selmode = 0
womwaverange, wave, flux, indexblue, indexred, npix, selmode


plot, wave, flux, xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = name, color = col.white
wshow
nwave = wave
nflux = flux
newbin = npix
print, ' '
print, 'Now pick the exact line.'

womwaverange, wave, flux, indexblue, indexred, npix, selmode

fitbin = indexred-indexblue+1
fitwave = nwave[indexblue:indexred]
fitflux = nflux[indexblue:indexred]
repeat begin
    print, 'Enter the nominal center of the line: '
    linecent = ''
    read, linecent
    linecent = float(linecent)
    womget_element, fitwave, linecent, linecentpix
endrep until (linecentpix GT 0) and (linecentpix LT fitbin-1)
print, 'Enter the new line center: '
newlinecent = ''
read, newlinecent
newlinecent = float(newlinecent)


c = 2.997925E5
z = (linecent-newlinecent)/newlinecent
fitwave = fitwave / (1+z)
print, ' '
womget_element, oldwave, fitwave[0], bluesidepix
womget_element, oldwave, fitwave[fitbin-1], redsidepix
delta = oldwave[1]-oldwave[0]
intnbin = redsidepix-bluesidepix+1

nfitwave = (findgen(intnbin)*delta)+oldwave[bluesidepix]
womidlterp, fitwave, fitflux, nfitwave, nfitflux
scalefac = 1.0
repeat begin
    rflag = 1
    newflux = oldflux
    for i = 0, intnbin-1 do begin
        newflux[bluesidepix+i] = newflux[bluesidepix+i] - $
          nfitflux[i]*scalefac
    endfor
    !p.multi =  [0, 1, 2]
    plot, oldwave, oldflux, xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
      ytitle = 'Flux', title = name,   position =  [0.1, 0.55, 0.99, 0.95], $
      /normal, color = col.white
    oplot, nfitwave, nfitflux*scalefac,  psym = 10, color = col.red
    plot, oldwave, newflux, xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
      ytitle = 'Flux', title = name,   position =  [0.1, 0.1, 0.99, 0.49], $
      /normal, color = col.white
    print, strcompress('Done with template line scaled by '+string(scalefac))
    print, ' '
    repeat begin
        print, '(n)ew scale factor, or (g)o on? (n/g) '
        c = get_kbrd(1)
        c = strlowcase(c)
        print, c
    endrep until (c EQ 'n') or (c EQ 'g')
    if (c EQ 'n') then begin
        scalefac = ''
        read, 'Enter new scale factor: ', scalefac
        scalefac = float(scalefac)
        rflag = 0
    endif
endrep until (rflag EQ 1)
active.wave = oldwave
active.flux = newflux
active.nbin = oldnpix
!p.multi = 0
end
