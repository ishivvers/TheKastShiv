pro womzcalc
common wom_hopper, hoparr, hopsize
common wom_active, active

print, 'This routine will cross-correlate two hoppers'
print, 'to determine redshift.'
print, ' '
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

name1 = hoparr[hopnum1].obname
name2 = hoparr[hopnum2].obname
npix1 = hoparr[hopnum1].nbin
npix2 = hoparr[hopnum2].nbin
spechead1 = hoparr[hopnum1].head
spechead2 = hoparr[hopnum2].head
wave1 = hoparr[hopnum1].wave[0:npix1-1]
wave2 = hoparr[hopnum2].wave[0:npix2-1]
flux1 = hoparr[hopnum1].flux[0:npix1-1]
flux2 = hoparr[hopnum2].flux[0:npix2-1]
wdelt1 = wave1[1]-wave1[0]
wdelt2 = wave2[1]-wave2[0]
if (abs(wdelt1-wdelt2) GT .00001) then begin
    print, 'Spectra do not have same Angstrom/pixel'
    print, strcompress('Hopper A: '+string(wdelt1))
    print, strcompress('Hopper B: '+string(wdelt2))
    print, ' '
    wdeltmax = max([wdelt1, wdelt2])
    print, 'Rebinning to '+string(wdeltmax)
    IF (wdelt1 LT wdelt2) THEN BEGIN
        newbin = (wave1[npix1-1]-wave1[0])/wdelt2 +1.0
	npix1 = fix(newbin)
        nwave = (findgen(npix1)*wdelt2)+wave1[0]
        womidlterp, wave1, flux1, nwave, nflux
        wave1 = nwave
	flux1 = nflux
        c = get_kbrd(1)
    ENDIF 
    IF (wdelt1 GT wdelt2) THEN BEGIN
        newbin = (wave2[npix2-1]-wave2[0])/wdelt1+1.0
	npix2 = fix(newbin)
        nwave = (findgen(npix2)*wdelt1)+wave2[0]
        womidlterp, wave2, flux2, nwave, nflux
        wave2 = nwave
	flux2 = nflux
    ENDIF
endif
wave0 = min([wave1[0], wave2[0]])
waven = max([wave1[npix1-1], wave2[npix2-1]])
wdelt = wave1[1]-wave1[0]
ntot = (waven-wave0)/wdelt +1.0
npixtot = fix(ntot)
wavetot = findgen(npixtot)*wdelt+wave0
fluxtot1 = fltarr(npixtot)
fluxtot2 = fltarr(npixtot)
womget_element, wavetot, wave1[0], w1start
womget_element, wavetot, wave1[npix1-1], w1end
womget_element, wavetot, wave2[0], w2start
womget_element, wavetot, wave2[npix2-1], w2end
fluxtot1[w1start:w1end] = flux1[0:npix1-1]
fluxtot2[w2start:w2end] = flux2[0:npix2-1]
binvec = findgen(npixtot)
wavelog = alog(wavetot[0])+((alog(wavetot[npixtot-1])-$
                             alog(wavetot[0]))/npixtot)*binvec
wavelog = exp(wavelog)
womidlterp, wavetot, fluxtot1, wavelog, fluxlog1
womidlterp, wavetot, fluxtot2, wavelog, fluxlog2
xfactor = 10
npoints = npixtot
xzcor, fluxlog1, fluxlog2, xfactor, npoints, result
kmsperbin = fltarr(npixtot)
for i = 1, npixtot-1 do begin
    kmsperbin[i] = 2.0*2.997925e5*(wavelog[i]-wavelog[i-1])/$
      (wavelog[i]+wavelog[i-1])
endfor
kmsmoment = moment(kmsperbin[1:npixtot-1])
kmsavg = kmsmoment[0]
print, result
print, kmsavg
print, result*kmsavg
c = get_kbrd(1)

end
