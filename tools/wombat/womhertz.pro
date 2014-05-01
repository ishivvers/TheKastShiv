PRO womhertz
common wom_active, active
womdestruct, active, wave, flux, err, name, npix, header

print, 'NOTE:  The routine expects an f_nu spectrum'
print, '       I will try to guess if the spectrum'
print, "       has been scaled by 1E26 (it shouldn't be)"
print, ' '
print, '       Check this before believing any result'
print, ' '


IF ((moment(flux))[0] GT 0.00001) THEN flux = flux *1e-26
if (total(err[0:npix-1]) EQ npix) then err = err*1e-26

wave = wave*1e-10
wave = 2.99792458e8/wave

print, 'Active spectrum now in hertz vs. f_nu'
print,  ' '

active.wave = wave
active.flux = flux
active.err  = err

end
