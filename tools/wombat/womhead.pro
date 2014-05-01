pro womhead
common wom_active, active
womdestruct, active, wave, flux, err, name, npix, spechead

spectrim = strtrim(spechead, 1)
realspace = where(strlen(spectrim) EQ 80)
if (realspace[0] LT 0) then begin
    print, ' '
    print, 'No header for this object'
    return
endif
spectrim = spectrim(realspace)
specline = strmid(spectrim, 0, 78)
scale = (size(specline))[1]
print, ' '
for i = 1, scale-1 do begin
    print, specline[i:i]
    if (i mod 18 EQ 0) then begin
        print, ' '
        print, 'Hit any key, q to quit'
        c = get_kbrd(1)
        print, ' '
        c = strlowcase(c)
        if (c EQ 'q') then i = fix(scale -1)
    endif
endfor

end
