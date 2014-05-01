pro wombuf
; lists buffer contents
; TM
common wom_hopper, hoparr, hopsize
common wom_active, active
name = ''
print, ' '
print, strcompress('Active: '+active.obname)
print, ' '
for i = 1, hopsize-1 do begin
    name = hoparr[i].obname
    if (strlen(name) GT 0) then begin
        print, strcompress('Hopper '+string(i)+': '+name)
    endif
endfor

end
