pro womwavescale

; routine to adjust wavelength scale when not in angstroms


common wom_active, active
common wom_ulog, ulog
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, header

plot, wave, flux, xst = 3, yst = 3, psym = 10, color = col.white, $
  xtitle = 'Wavelength', ytitle = 'Flux', title = name
shift = ''
print, ' '
print, 'This routine does a multiplicative adjustment to the wavelength scale.'
read, 'Enter wavelength factor: ', shift
shift = float(shift)
wave = wave *shift

oplot, wave, flux, psym = 10, color = col.red

printf, ulog, systime()
printf, ulog, strcompress('File: '+name+' wavelength scale adjusted by ' + $ 
                          'factor of ' +string(shift))

active.wave =  wave

end
