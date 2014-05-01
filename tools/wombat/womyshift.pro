pro womyshift

; routine to shift flux scale linearly
; AJB, 3/29/99

common wom_active, active
common wom_ulog, ulog
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, header

plot, wave, flux, xst = 3, yst = 3, psym = 10, color = col.white, $
  xtitle = 'Wavelength', ytitle = 'Flux', title = name
shift = ''
print, ' '
print, 'This routine does a linear shift to the flux scale.'
read, 'Enter constant to add to the fluxes: ', shift
shift = float(shift)
flux = flux + shift

oplot, wave, flux, psym = 10, color = col.red

printf, ulog, systime()
printf, ulog, strcompress('File: '+name+' flux scale shifted by ' + $ 
                          string(shift) )

active.flux =  flux

end
