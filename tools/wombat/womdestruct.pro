pro womdestruct, active, wave, flux, err, name, npix, header

npix = active.nbin
wave = active.wave[0:npix-1]
flux = active.flux[0:npix-1]
err  = active.err[0:npix-1]
name = active.obname
header = active.head

end
