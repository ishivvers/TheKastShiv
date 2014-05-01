pro womms
common wom_hopper, hoparr, hopsize
common wom_active, active

nocom = 0
print, 'This routine will perfrom arithmatic operations with two hoppers'
print, ' '
repeat begin
    print, 'Do you want to (a)dd, (s)ubtract, (m)ultiply, '
    print, 'or (d)ivide the two spectra? (a/s/m/d) '
    c = get_kbrd(1)
    c = strlowcase(c)
    print, c
endrep until (c EQ 'a') or (c EQ 's') or (c EQ 'm') or (c EQ 'd')
print, ' '
if (c EQ 's') then begin
    print, 'Second spectrum will be subtracted from the first.'
endif
if (c EQ 'd') then begin
    print, 'First spectrum will be divided by the second.'
endif
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
wave1 = hoparr[hopnum1].wave
wave2 = hoparr[hopnum2].wave
flux1 = hoparr[hopnum1].flux
flux2 = hoparr[hopnum2].flux
err1  = hoparr[hopnum1].err
err2  = hoparr[hopnum2].err
name  = hoparr[hopnum1].obname
npix1 = hoparr[hopnum1].nbin
npix2 = hoparr[hopnum2].nbin
spechead = hoparr[hopnum1].head



nocom = 0
if (npix1 NE npix2)  or (wave1[0] NE wave2[0]) or $ 
  (wave1[1] NE wave2[1]) then nocom = 1
if (nocom EQ 1) then begin
    print, 'Hoppers do not have the same wavelength scale'
    return
endif

case c of
    'a': begin
           nflux = flux1 + flux2
           nerr = sqrt(err1^2 + err2^2)
        end

    's': begin
           nflux = flux1 - flux2
           nerr = sqrt(err1^2 + err2^2)
        end

    'm': begin
           nflux = flux1 * flux2
           nerr = nflux
           for i = 0, npix-1 do $
             nerr[i] = sqrt((err1*flux2)^2. + (err2*flux1)^2.)
        end

    'd': begin
          nflux = flux1 / flux2
          nerr = nflux
          for i = 0, npix-1 do $
            nerr[i] = sqrt((err1/flux2)^2. + (flux1*err2/flux2^2.)^2.)
       end

endcase
active.wave = wave1
active.nbin = npix1
active.flux = nflux
active.err  = nerr
active.obname = name
active.head = spechead
repeat begin
    print, 'Store result in hopper? (y/n) '
    a = get_kbrd(1)
    a = strlowcase(a)
    print, a
endrep until (a EQ 'y') or (a EQ 'n')
if (a EQ 'y') then begin
    repeat begin
        print, ' '
        hopchoice3 = ''
        read, 'Store result in which hopper? ', hopchoice3
        hopnum3 = fix(hopchoice3)
    endrep until (hopnum3 GT 0) and (hopnum3 LT hopsize)

    hoparr[hopnum3] = active
endif

end
