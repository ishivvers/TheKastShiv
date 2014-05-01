pro womxshift

; routine to shift wavelength scale linearly
; AJB, 3/29/99

common wom_active, active
common wom_ulog, ulog
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, header

plot, wave, flux, xst = 3, yst = 3, psym = 10, color = col.white, $
  xtitle = 'Wavelength', ytitle = 'Flux', title = name
shift = ''
print, ' '
print, 'This routine does a linear shift to the wavelength scale.'
read, 'Enter wavelength shift in Angstroms: ', shift
shift = float(shift)
wave = wave + shift

oplot, wave, flux, psym = 10, color = col.red

printf, ulog, systime()
printf, ulog, strcompress('File: '+name+' wavelength scale shifted by ' + $ 
                          string(shift) + ' A')

active.wave =  wave

end
