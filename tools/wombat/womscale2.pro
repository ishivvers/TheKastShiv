pro womscale2
common wom_hopper, hoparr, hopsize
common wom_active, active
common wom_ulog, ulog
COMMON wom_col, col
nocom = 0
print, 'This will scale one hopper to match another'
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

if (hoparr[hopnum1].nbin NE hoparr[hopnum2].nbin) or $
  (hoparr[hopnum1].wave[0] NE hoparr[hopnum2].wave[0]) or $
  (hoparr[hopnum1].wave[1] NE hoparr[hopnum2].wave[1]) then nocom = 1
if (nocom EQ 1) then begin
    print, 'Hoppers do not have the same wavelength scale'
    return
endif
npix = hoparr[hopnum1].nbin
print, ' '
print, strcompress('Spectra run from '+string(hoparr[hopnum1].wave[0])+$
                   ' to '+ string(hoparr[hopnum1].wave[npix-1])+'.')
wave = hoparr[hopnum1].wave[0:npix-1]
flux = hoparr[hopnum1].flux[0:npix-1]
err  = hoparr[hopnum1].err[0:npix-1]
wave2 = hoparr[hopnum2].wave[0:npix-1]
flux2 = hoparr[hopnum2].flux[0:npix-1]
err2  = hoparr[hopnum2].err[0:npix-1]

plot, wave, flux, xst = 3, yst = 3, psym = 10, $
  xtitle =  'Wavelength', color = col.white, $
  ytitle = 'Flux', title = name
oplot, wave2, flux2, psym = 10, color = col.red
wshow
print, ' '
print, 'Hopper A in white, hopper B in red'
print, ' '
oldflux = flux
olderr = err
womwaverange, wave, flux, indexblue, indexred, npix, 0
moment1 = moment(oldflux[indexblue:indexred])
moment2 = moment(flux2[indexblue:indexred])
print, ' '
print, 'Hopper A: ', moment1[0]
print, ' '
print, 'Hopper B: ', moment2[0]
print, ' '
print, ' '
repeat begin
    print, 'Scale to (A) or (B)? (A/B) '
    c = get_kbrd(1)
    c = strupcase(c)
    print, c
endrep until (c EQ 'A') or (c EQ 'B')
print, ' '
if (c EQ 'A') then begin
    flux2 = flux2*moment1[0]/moment2[0]
    err2 = err2*moment1[0]/moment2[0]
    print, 'Scale: ', moment1[0]/moment2[0]
    scalefac = moment1[0]/moment2[0]
    fluxfinal = flux2
    errfinal = flux2
    origname = hoparr[hopnum1].obname
    changedname = hoparr[hopnum2].obname
endif
if (c EQ 'B') then begin
    oldflux = oldflux*moment2[0]/moment1[0]
    olderr = olderr*moment2[0]/moment1[0]
    print, 'Scale: ', moment2[0]/moment1[0]
    scalefac = moment2[0]/moment1[0]
    fluxfinal = oldflux
    errfinal = olderr
    origname = hoparr[hopnum2].obname
    changedname = hoparr[hopnum1].obname
endif

repeat begin
    print, ' '
    hopchoice3 = ''
    read, 'Store in which hopper? ', hopchoice3
    hopnum3 = fix(hopchoice3)
endrep until (hopnum3 GT 0) and (hopnum3 LT hopsize)

if (c EQ 'B') then begin
hoparr[hopnum3].wave = hoparr[hopnum1].wave
hoparr[hopnum3].nbin = hoparr[hopnum1].nbin
hoparr[hopnum3].flux = fluxfinal
hoparr[hopnum3].err  = errfinal
hoparr[hopnum3].obname = hoparr[hopnum1].obname
hoparr[hopnum3].head = hoparr[hopnum1].head
endif
if (c EQ 'A') then begin
hoparr[hopnum3].wave = hoparr[hopnum2].wave
hoparr[hopnum3].nbin = hoparr[hopnum2].nbin
hoparr[hopnum3].flux = fluxfinal
hoparr[hopnum3].err  = errfinal
hoparr[hopnum3].obname = hoparr[hopnum2].obname
hoparr[hopnum3].head = hoparr[hopnum2].head
endif

printf, ulog, systime()
printf, ulog, strcompress('File: '+changedname+' scaled by'+$
                        string(scalefac))
printf, ulog, strcompress('to match '+origname)
end
