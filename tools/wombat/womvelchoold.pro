pro womvelcho
common wom_active, active
device, cursor_standard = 33
!Y.STYLE = 16
us = findgen(48)*(!PI*2/48.0)
usersym, cos(us), sin(us), /fill
womdestruct, active, wave, flux, name, npix, spechead

print, strcompress('Current A/pix is '+string(wave[1]-wave[0]))
print, ' '
print, strcompress('Wavelength range: '+string(wave[0])+':'+ $
                   string(wave[npix-1]))
print, ' '
nwave = wave
nflux = flux
intnbin = npix
womwaverange, nwave, nflux, indexblue, indexred, intnbin, 0
intnbin = indexred-indexblue+1
nwave = wave[indexblue:indexred]
nflux = flux[indexblue:indexred]
zlam = nwave[0]
nlam = nwave[intnbin-1]
binvec = findgen(intnbin)
wavelog = alog(zlam)+((alog(nlam)-alog(zlam))/intnbin)*binvec
wavelog = exp(wavelog)
womidlterp, nwave, nflux, wavelog, fluxlog
kmsperbin = fltarr(intnbin)
for i = 1, intnbin-1 do begin
    kmsperbin[i] = 2.0*2.997925e5*(wavelog[i]-wavelog[i-1])/$
      (wavelog[i]+wavelog[i-1])
endfor
kmsmoment = moment(kmsperbin[1:intnbin-1])
kmsavg = kmsmoment[0]
print, ' '
print, strcompress('Average km/s per bin: '+string(kmsavg))
print, strcompress('km/s at bin 1:        '+string(kmsperbin[1]))
print, strcompress('km/s at bin n:        '+string(kmsperbin[intnbin-1]))
print, ' '
wavekms = kmsavg*binvec+kmsavg/2.0
repeat begin
    print, ' '
    zp = ''
    read, 'Enter the zero point for velocity (in angstroms): ', zp
    zp = float(zp)
endrep until (zp GE wavelog[0]) and (zp LE wavelog[intnbin-1])
diff = abs(wavelog-zp)
result = min(diff, indexzp)
print, ' '
print, strcompress('Zero at bin '+string(indexzp))
print, strcompress('with lambda '+string(wavelog[indexzp]))
print, ' '
offset = wavekms[indexzp]
print, strcompress('Offset: '+string(offset))
wavekms = wavekms-offset
active.wave = wavekms
active.flux = fluxlog
active.nbin = intnbin
womheaderfix, spechead, wavekms, intnbin

active.head = spechead
device, /cursor_crosshair
end
