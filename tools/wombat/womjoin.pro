pro womjoin
common wom_hopper, hoparr,  hopsize
common wom_active, active
common wom_ulog, ulog
nocom = 0
print, 'This will join two hoppers (with no overlap)'
repeat begin
    print, ' '
    hopchoice1 = ''
    read, 'Enter the first hopper? ', hopchoice1
    hopnum1 = fix(hopchoice1)
endrep until ((hopnum1 GT 0) and (hopnum1 LT hopsize))
repeat begin
    print, ' '
    hopchoice2 = ''
    read, 'Enter the second hopper? ', hopchoice2
    hopnum2 = fix(hopchoice2)
endrep until ((hopnum2 GT 0) and (hopnum2 LT hopsize))

if (hoparr[hopnum1].wave[0] GT hoparr[hopnum2].wave[0]) then begin
    temp = hopnum1
    hopnum1 = hopnum2
    hopnum2 = temp
endif
womdestruct, hoparr[hopnum1], waveblue, fluxblue, errblue, nameblue, npixblue, headblue
womdestruct, hoparr[hopnum2], wavered, fluxred, errred, namered, npixred, headred
wdeltblue = waveblue[1]-waveblue[0]
wdeltred = wavered[1]-wavered[0]
if (abs(wdeltblue-wdeltred) GT .00001) then begin
    print, 'Spectra do not have same Angstrom/pixel'
    print, strcompress('Blue side: '+string(wdeltblue))
    print, strcompress('Red side: '+string(wdeltred))
    return
endif
abuttest = wavered[0]-(waveblue[npixblue-1] + wdeltblue)
if (abs(abuttest) GT .00001) then begin
    print, 'Spectra do not abut'
    print, ' '
    return
endif
print, strcompress('Joining from '+string(waveblue[npixblue-1])+ $
                   ' to '+string(wavered[0]))

npix = npixblue+npixred
wave = fltarr(npix)
flux = wave
err  = wave
wave[0:npixblue-1] = waveblue
wave[npixblue:npix-1] = wavered
flux[0:npixblue-1] = fluxblue
flux[npixblue:npix-1] = fluxred
err[0:npixblue-1] = errblue
err[npixblue:npix-1] = errred
repeat begin
    print, ' '
    hopchoice3 = ''
    read, 'Store in which hopper? ', hopchoice3
    hopnum3 = fix(hopchoice3)
endrep until (hopnum3 GT 0) and (hopnum3 LT hopsize)
womheaderfix, headred, wave, npix


hoparr[hopnum3].wave = wave[0:npix-1]
hoparr[hopnum3].nbin = npix
hoparr[hopnum3].flux = flux[0:npix-1]
hoparr[hopnum3].err  = err[0:npix-1]
hoparr[hopnum3].obname = namered
hoparr[hopnum3].head = headred
active = hoparr[hopnum3]
printf, ulog, systime()
printf, ulog, strcompress('File: '+hoparr[hopnum1].obname+' and')
printf, ulog, strcompress('file: '+hoparr[hopnum2].obname+' joined')
printf, ulog, strcompress('from '+string(waveblue[npixblue-1])+ $
                          ' to '+string(wavered[0]))
end
