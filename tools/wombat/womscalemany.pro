pro womscalemany
common wom_hopper, hoparr, hopsize
common wom_active, active
common wom_ulog, ulog
COMMON wom_col, col
nocom = 0
scalehops = intarr(hopsize)
print, 'This will scale several hoppers to match one'
repeat begin
    print, ' '
    hopchoice1 = ''
    read, 'Enter the fiducial hopper (all will be scaled to this)? ', hopchoice1
    hopnum1 = fix(hopchoice1)
endrep until ((hopnum1 GT 0) and (hopnum1 LT hopsize))
print, 'Enter the hoppers to be scaled (99 to end)'
i = 0
REPEAT BEGIN

repeat begin
    print, ' '
    hopchoice2 = ''
    read, 'Enter another hopper? ', hopchoice2
    hopnum2 = fix(hopchoice2)
endrep until ((hopnum2 GT 0) and (hopnum2 LT hopsize) OR (hopnum2 EQ 99))
IF (hopnum2 NE 99) THEN begin
if (hoparr[hopnum1].nbin NE hoparr[hopnum2].nbin) or $
  (hoparr[hopnum1].wave[0] NE hoparr[hopnum2].wave[0]) or $
  (hoparr[hopnum1].wave[1] NE hoparr[hopnum2].wave[1]) then nocom = 1
if (nocom EQ 1) then begin
    print, 'Hoppers do not have the same wavelength scale'
    return
ENDIF
ENDIF
scalehops[i] = hopnum2
i = i+1
ENDREP UNTIL (hopnum2 EQ 99)

npix = hoparr[hopnum1].nbin
print, ' '
print, strcompress('Spectra run from '+string(hoparr[hopnum1].wave[0])+$
                   ' to '+ string(hoparr[hopnum1].wave[npix-1])+'.')
wave = hoparr[hopnum1].wave[0:npix-1]
flux = hoparr[hopnum1].flux[0:npix-1]
err  = hoparr[hopnum1].err[0:npix-1]

plot, wave, flux, xst = 3, yst = 3, psym = 10, $
  xtitle =  'Wavelength', color = col.white, $
  ytitle = 'Flux', title = name
wshow
print, ' '
print, 'Fiducial spectrum in white'
print, ' '
oldflux = flux
olderr  = err
npixsample = npix
womwaverange, wave, flux, indexblue, indexred, npixsample, 0
moment1 = moment(oldflux[indexblue:indexred])

print, ' '
print, 'Fiducial spectrum: ', moment1[0]
print, ' '
print, ' '

print, ' '
printf, ulog, systime()

FOR k = 0, i-2 DO BEGIN
  wave2 = hoparr[scalehops[k]].wave[0:npix-1]
  flux2 = hoparr[scalehops[k]].flux[0:npix-1]
  err2  = hoparr[scalehops[k]].err[0:npix-1]
  moment2 = moment(flux2[indexblue:indexred])
  print, 'Hopper ', scalehops[k], ' ',  moment2[0]
    flux2 = flux2*moment1[0]/moment2[0]
    err2  = err2*moment1[0]/moment2[0]
    print, 'Scale: ', moment1[0]/moment2[0]
    scalefac = moment1[0]/moment2[0]
  printf, ulog, strcompress('File: '+hoparr[scalehops[k]].obname+' scaled by'+$
                        string(scalefac))
  printf, ulog, strcompress('to match '+hoparr[hopnum1].obname)

  hoparr[scalehops[k]].flux = flux2
  hoparr[scalehops[k]].err = err2
ENDFOR



end
