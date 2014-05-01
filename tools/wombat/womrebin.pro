pro womrebin
; this routine rebins data to a new A/pix,  it checks FOR an
; integer number OF bins AND uses quadratic interpolation
; TM
common wom_active, active
COMMON wom_col, col
womdestruct, active, wave, flux, name, npix, header

print, strcompress('Current A/pix is '+string(wave[1]-wave[0]))
print, ' '
print, strcompress('Wavelength range: '+string(wave[0])+':'+ $
                   string(wave[npix-1]))
print, ' '
fix = 0
si = size(wave)
newbin = si[1]/2
if (((float(si[1]))/2-newbin) GT 0.000001) then fix = 1
intnbin = newbin-fix
newdelt = (wave[1]-wave[0])*2
newwave0 = wave[0]
nwave = (findgen(newbin)*newdelt)+newwave0

nflux = rebin(flux[0:npix-(1+fix)], newbin)
;quadterp, wave, flux, nwave, nflux
active.wave = nwave
active.flux = nflux
active.nbin = newbin

womheaderfix, header, nwave, newbin
active.head = header
print, ' '
print, 'Overplotting rebinned spectrum in red.'
print, ' '
plot, wave, flux, xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = name, color = col.white
oplot, nwave[0:newbin-1], nflux[0:newbin-1], psym = 10, color = col.red
wshow
end
