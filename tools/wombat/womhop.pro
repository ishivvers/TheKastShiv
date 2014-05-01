pro womhop
common wom_hopper, hoparr,  hopsize
common wom_active, active


repeat begin
    print, ' '
    hopchoice = ''
    read, 'Store in which hopper? ', hopchoice
    hopnum = fix(hopchoice)
endrep until (hopnum GT 0) and (hopnum LT hopsize)
hoparr[hopnum] = active
end
