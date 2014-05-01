pro womwaveparse, wave, wavestring, npix

waverange = ''
print, ' '
repeat begin
goflag = 1
read, 'Enter desired wavelength range, <CR> selects all: ', waverange
        if (waverange EQ '') then begin
            wavestring = [string(wave[0]), string(wave[npix-1])]
        endif else begin
            waverange = strtrim(strcompress(waverange), 2)
            space = strpos(waverange, ' ')
            comma = strpos(waverange, ',')
            dash = strpos(waverange, '-')
            if (space GT 0) then begin
                wavestring = strcompress(strsplit(waverange,' ',/extract),/rem)
            endif else if (comma GT 0) then begin
                waverange = strcompress(waverange, /remove_all)
                wavestring = strcompress(strsplit(waverange,',',/extract),/rem)
            endif else if (dash GT 0) then begin
                waverange = strcompress(waverange, /remove_all)
                wavestring = strcompress(strsplit(waverange,'-',/extract),/rem)
            endif else begin
                print, strcompress('You entered '+waverange)
                print, 'I can not parse your range, try ### ###,'
                print, 'or ###, ###, or ###-###.'
                goflag = 0
            endelse
        endelse
        if ((size(wavestring))[1] LT 2) then begin
            print, 'You only entered one number'

            goflag = 0
        endif
endrep until (goflag EQ 1)
end
