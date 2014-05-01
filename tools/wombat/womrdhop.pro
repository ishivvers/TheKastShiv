pro womrdhop
common wom_hopper, hoparr, hopsize
common wom_active, active


repeat begin
    print, ' '
    hopchoice = ''
    read, 'Read from which hopper? ', hopchoice
    hopnum = fix(hopchoice)
endrep until (hopnum GT 0) and (hopnum LT hopsize)
if (hoparr[hopnum].nbin NE 0) then begin
    active = hoparr[hopnum]
    print, ' '
    print, strcompress('Object is '+active.obname)
    print, ' '
  endif  else begin
        print, ' '
        print, strcompress('Nothing in hopper '+string(hopchoice))
        print, strcompress('Active spectrum still '+active.obname)
        print, ' '
    endelse

end
