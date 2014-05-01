pro womwin
common wom_active, active
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, header


print, ' '
print, strcompress('Object is '+name)
print, ' '
fluxsave = flux
repeat begin
    plot, wave, fluxsave, xst = 3, yst = 3, psym = 10, color = col.white, $
      xtitle =  'Wavelength', ytitle = 'Flux', title = name
    wshow
    repeat begin
        print, ' '
        print, 'Change y-scale? (y/n, default=n)'
        c = get_kbrd(1)
        if ((byte(c))[0] EQ 10) then c = 'n'
        c = strlowcase(c)
        print, c
    endrep until (c EQ 'y') OR (c EQ 'n')
    if (c EQ 'y') then begin
        womscaleparse, ymin, ymax
        plot, wave, fluxsave, xst = 3, yst = 3, psym = 10, $
          xtitle =  'Wavelength', color = col.white, $
          ytitle = 'Flux', title = name,  $xrange = [waveb, wavee], $
          yrange = [ymin, ymax]
        wshow
    endif
    print, ' '
    print, 'Ready to window spectrum'
    womscaleparse, fmin, fmax
;    read, 'Enter the minimum and maximum values for the window: ', fmin, fmax
    if (fmin GT fmax) then begin
        temp = fmin
        fmin = fmax
        fmax = fmin
    endif
    flux = fluxsave
    wheremin = where((flux LT fmin), nmin)
    wheremax = where((flux GT fmax), nmax)
    if (nmin GT 0) then begin
        flux(wheremin) = fmin
    endif
    if (nmax GT 0) then begin
        flux(wheremax) = fmax
    endif
    print, ' '
    print, 'Overplotting windowed spectrum in red.'
    oplot, wave, flux, psym = 10, color = col.red
    wshow

    print, ' '
    print, 'Is this ok? (y/n, default=y)'
    yesno = get_kbrd(1)
    if ((byte(yesno))[0] EQ 10) then yesno = 'y'
    yesno = strlowcase(yesno)
    print, yesno
endrep until (yesno EQ 'y')
active.flux = flux
end
