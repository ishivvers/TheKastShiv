pro womsca
common wom_active, active
womdestruct, active, wave, flux, err, name, npix, header

print, ' '
factor = ''
read, 'Enter multiplicative scale factor: ', factor
numfac = float(factor)
flux = flux*numfac
err = err*numfac
print, ' '
active.flux = flux
active.err = err



end
