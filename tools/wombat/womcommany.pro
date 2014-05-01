PRO womcommany
common wom_hopper, hoparr,  hopsize
common wom_active, active
COMMON wom_ulog, ulog
COMMON wom_col, col
nocom = 0
scalehops = intarr(hopsize)

print, 'This will combine many hoppers (with equal weight)'
repeat begin
    print, ' '
    hopchoice1 = ''
    read, 'Enter the first hopper: ', hopchoice1
    hopnum1 = fix(hopchoice1)
endrep until ((hopnum1 GT 0) and (hopnum1 LT hopsize))
i = 0

REPEAT BEGIN
  repeat begin
    print, ' '
    hopchoice2 = ''
    read, 'Enter another hopper ("99" to quit): ', hopchoice2
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

repeat begin
  print, ' '
  hopchoice4 = ''
  read, 'Store in which hopper? ', hopchoice4
  hopnum4 = fix(hopchoice4)
endrep until (hopnum4 GT 0) and (hopnum4 LT hopsize)

npix = n_elements(hoparr[hopnum1].wave)
fluxes = fltarr(i,npix)
errs   = fltarr(i,npix)
fluxes[0,*] = hoparr[hopnum1].flux
errs[0,*]   = hoparr[hopnum1].err

for k = 0, i-2 do begin
  fluxes[k+1,*] = hoparr[scalehops[k]].flux
  errs[k+1,*]   = hoparr[scalehops[k]].err
endfor

comflux = total(fluxes,1)/float(i)
comerr = sqrt((total(errs,1)/float(i))^2.)
printf, ulog, systime()
printf, ulog, strcompress('File: '+hoparr[hopnum1].obname+' and')
for k = 0, i-2 do printf, ulog, $
  strcompress('File: '+hoparr[scalehops[k]].obname+' combined equally')

hoparr[hopnum4].wave = hoparr[hopnum1].wave
hoparr[hopnum4].nbin = hoparr[hopnum1].nbin
hoparr[hopnum4].flux = comflux
hoparr[hopnum4].err  = comerr
hoparr[hopnum4].obname = hoparr[hopnum1].obname
hoparr[hopnum4].head = hoparr[hopnum1].head
print, ' '
npix = hoparr[hopnum1].nbin
print, 'Plotting combined spectrum'
print, ' '
plot, hoparr[hopnum1].wave[0:npix-1], comflux[0:npix-1], xst = 3, $
  yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = name, color = col.white

wshow

end
