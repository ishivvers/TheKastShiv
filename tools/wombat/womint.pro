pro womint
common wom_active, active
common wom_ulog, ulog
COMMON wom_col, col
device, cursor_standard = 33
!Y.STYLE = 16
us = findgen(48)*(!PI*2/48.0)
usersym, cos(us), sin(us), /fill
womdestruct, active, wave, flux, err, name, npix, header

print, ' '
print, strcompress('Object is '+name)
print, ' '
print, strcompress('Spectrum runs from '+string(wave[0])+' to '+ $
                   string(wave[npix-1])+'.')
print, ' '
print, 'This routine expects the spectrum to be in flambda units.'
print, 'It also expects a linear wavelength scale.'
print, ' '
selmode = 0
oldwave = wave
oldflux = flux

womwaverange, wave, flux, indexblue, indexred, npix, selmode


plot, wave, flux, xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = name, color = col.white
wshow
nwave = wave
nflux = flux
newbin = npix
print, ' '
print, 'Now pick the exact range for the intensity calculation.'

womwaverange, wave, flux, indexblue, indexred, npix, selmode

print, ' '
print, strcompress('FWZI (approximate): '+string(wave[npix-1]-wave[0]))
print, ' '
lineflux = 0.0
;for i = indexblue, indexred do begin
;    lineflux = lineflux+nflux[i]*(nwave[i+1]-nwave[i])
;endfor
deltalam = wave[1]-wave[0]
lineflux = total(flux)*deltalam
lineflux2 = total(nflux[indexblue:indexred])*deltalam
linefluxin = total(nflux[indexblue+1:indexred-1])*deltalam
linefluxout = total(nflux[indexblue-1:indexred+1])*deltalam
print, strcompress('Line flux is '+string(lineflux)+' ergs/sec/cm^2')
print, ' '

print, strcompress('Line flux in one is '+string(linefluxin))
print, strcompress('Line flux out one is '+string(linefluxout))
fluxdiff = (abs(linefluxin - lineflux) + abs(linefluxout-lineflux))/2.0
print, strcompress('Average difference is '+string(fluxdiff))
fluxpcent = 100.0*fluxdiff/lineflux
print, strcompress('Percentage of line flux is '+string(fluxpcent))
print, 'Note that the above flux may need to be scaled by 1E-15'
printf, ulog, systime()
printf, ulog, strcompress('File: '+name)
printf, ulog, strcompress('FWZI (approximate): '$
                          +string(wave[npix-1]-wave[0]))
printf, ulog, strcompress('Line flux is '+string(lineflux)+' ergs/sec/cm^2')
printf, ulog, 'Note that the above flux may need to be scaled by 1E-15'
printf, ulog, strcompress('Line flux in one is '+string(linefluxin))
printf, ulog, strcompress('Line flux out one is '+string(linefluxout))
printf, ulog, strcompress('Average difference is '+string(fluxdiff))
printf, ulog, strcompress('Percentage of line flux is '+string(fluxpcent))

end
