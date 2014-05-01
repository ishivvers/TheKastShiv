pro wombluen
; TM
common wom_active, active
womdestruct, active, wave, flux, err, name, npix, header

print, ' '
print, 'This routine will bluen a spectrum with a power law'
print, 'of lambda^{-a}.  You will supply the value for a.'
print, ' '

factor = ''
read, 'Enter exponential factor: ', factor
numfac = float(factor)
wavefac = wave^(-1.0*factor)
wavefac = wavefac/wavefac[npix-1]
flux = flux*wavefac
err  = err*wavefac
print, ' '
active.flux = flux
active.err  = err



end
