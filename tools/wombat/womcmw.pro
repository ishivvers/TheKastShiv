pro womcmw
common wom_hopper, hoparr, hopsize
common wom_active, active
common wom_ulog, ulog
COMMON wom_col, col
nocom = 0
print, 'This will combine two hoppers at supplied weights'
repeat begin
    print, ' '
    hopchoice1 = ''
    wei1 = ''
    read, 'Enter the first hopper? ', hopchoice1
    hopnum1 = fix(hopchoice1)
    read, 'What is the weight for the first hopper? ', wei1
    wei1 = float(wei1)
endrep until ((hopnum1 GT 0) and (hopnum1 LT hopsize))
repeat begin
    print, ' '
    hopchoice2 = ''
    wei2 = ''
    read, 'Enter the second hopper? ', hopchoice2
    hopnum2 = fix(hopchoice2)
    read, 'What is the weight for the second hopper? ', wei2
    wei2 = float(wei2)
endrep until ((hopnum2 GT 0) and (hopnum2 LT hopsize))

if (hoparr[hopnum1].nbin NE hoparr[hopnum2].nbin) or $
(hoparr[hopnum1].wave[0] NE hoparr[hopnum2].wave[0]) or $
(hoparr[hopnum1].wave[1] NE hoparr[hopnum2].wave[1]) then nocom = 1
if (nocom EQ 1) then begin
    print, 'Hoppers do not have the same wavelength scale'
    return
endif
;if (abs((wei1+wei2)-1.0) GT 0.00001) then begin
;    print, 'Weights do not add to 1.0'
;    return
;endif
repeat begin
    print, ' '
    hopchoice3 = ''
    read, 'Store in which hopper? ', hopchoice3
    hopnum3 = fix(hopchoice3)
endrep until (hopnum3 GT 0) and (hopnum3 LT hopsize)

weitot = wei1 + wei2
wei1 = wei1 / weitot
wei2 = wei2 / weitot

comflux = (wei1*hoparr[hopnum1].flux + wei2*hoparr[hopnum2].flux)/(wei1 + wei2)
comerr = sqrt((wei1*hoparr[hopnum1].err)^2. + (wei2*hoparr[hopnum2].err)^2.)
hoparr[hopnum3].wave = hoparr[hopnum1].wave
hoparr[hopnum3].nbin = hoparr[hopnum1].nbin
hoparr[hopnum3].flux = comflux
hoparr[hopnum3].err  = comerr
hoparr[hopnum3].obname = hoparr[hopnum1].obname
hoparr[hopnum3].head = hoparr[hopnum1].head
print, ' '
npix = hoparr[hopnum1].nbin
print, 'Plotting combined spectrum as white, #1 as blue, #2 as red.'
print, ' '
plot, hoparr[hopnum1].wave[0:npix-1], comflux[0:npix-1], xst = 3, $
  yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = name, color = col.white
oplot, hoparr[hopnum1].wave[0:npix-1],  hoparr[hopnum1].flux[0:npix-1], $
  psym = 10, color = col.blue
oplot, hoparr[hopnum1].wave[0:npix-1],  hoparr[hopnum2].flux[0:npix-1], $
  psym = 10, color = col.red
wshow
printf, ulog, systime()
printf, ulog, strcompress('File: '+hoparr[hopnum1].obname+' and')
printf, ulog, strcompress('file: '+hoparr[hopnum2].obname+' combined')
printf, ulog, strcompress('with weights '+string(wei1)+' and '+$
                        string(wei2)+' respectively')
end
