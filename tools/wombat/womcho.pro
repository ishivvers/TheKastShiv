pro womcho
common wom_active, active
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, spechead

print, strcompress('Current A/pix is '+string(wave[1]-wave[0]))
print, ' '
oldwave = wave
oldflux = flux
oldnpix = npix
womwaverange, wave, flux, indexblue, indexred, npix, 0
    
active.wave = wave
active.flux = flux
active.err  = err
active.nbin = npix
womheaderfix, spechead, wave, npix
active.head = spechead
print, ' '
print, 'Overplotting spectrum subset in red.'
print, ' '
plot, oldwave, oldflux, xst = 3, yst = 3, psym = 10, xtitle = 'Wavelength', $
  ytitle = 'Flux', title = name, color = col.white
oplot, wave, flux, psym = 10, color = col.red
wshow
end
