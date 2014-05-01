pro womsmo
common wom_active, active
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, header

print, ' '
print, strcompress('Object is '+name)
print, ' '
repeat begin
    print, '(b)oxcar or (s)avitzky-Golay smoothing? (b/s) '
    c = get_kbrd(1)
    c = strlowcase(c)
    print, c
endrep until (c EQ 'b') or (c EQ 's')
if (c EQ 'b') then begin
    print,  ' '
    print, 'This routine will smooth the spectrum with a running boxcar.'
    print, 'If you enter an even number, the boxcar width will be n+1.'
    print, ' '
    boxwidth = ''
    read, 'Enter the width of the boxcar: ', boxwidth
    boxwidth = fix(boxwidth)
    if (boxwidth LT 2) or (boxwidth GE npix-1) then boxwidth = 2
    print, boxwidth
    sflux = smooth(flux, boxwidth, /edge_truncate, /nan)

endif
if (c EQ 's') then begin
    print, ' '
    print, 'The Savitzky-Golay filter smooths the data while conserving'
    print, 'flux and retaining the dynamic range of variations.  The '
    print, 'routine suggests a width of 1-2 times the FWHM of the '
    print, 'desired features, assuming you know what features you '
    print, 'do desire.  This currently uses a polynomial of degree'
    print, '2 to create the filter, so the width must be at least 3.'
    print, 'Good luck.'
    print, ' '
    boxwidth = ''
    read, 'Enter the width for the filter: ', boxwidth
    boxwdith = fix(boxwidth)
    if (boxwidth LT 3) or (boxwidth GE npix-1) then boxwidth = 3
    sflux = poly_smooth(flux, boxwidth)
endif
print, ' '
print, ' '
print, 'Overplotting smoothed spectrum in red.'
print, ' '
plot, wave, flux, xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = name, color = col.white
oplot, wave, sflux, psym = 10, color = col.red
wshow
active.flux = sflux
end
