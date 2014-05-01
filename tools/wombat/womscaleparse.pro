pro womscaleparse, ymin, ymax

scalerange = ''
scalestring = ''
print, ' '
repeat begin
goflag = 1
read, 'Enter your new ymin and ymax values: ', scalerange
        if (scalerange EQ '') then begin
            scalestring = ['0', '0']
        endif else begin
            scalerange = strtrim(strcompress(scalerange), 2)
            space = strpos(scalerange, ' ')
            comma = strpos(scalerange, ',')
            dash = strpos(scalerange, '-')
            if (space GT 0) then begin
                scalestring = strcompress(strsplit(scalerange,' ',/extract),/rem)
            endif else if (comma GT 0) then begin
                scalerange = strcompress(scalerange, /remove_all)
                scalestring = strcompress(strsplit(scalerange,',',/extract),/rem)
            endif else if (dash GT 0) then begin
                scalerange = strcompress(scalerange, /remove_all)
                scalestring = strcompress(strsplit(scalerange,'-',/extract),/rem)
            endif else begin
                print, strcompress('You entered '+scalerange)
                print, 'I can not parse your range, try ### ###,'
                print, 'or ###, ###, or ###-###.'
                goflag = 0
            endelse
        endelse
        if ((size(scalestring))[1] LT 2) then begin
            print, 'You only entered one number'

            goflag = 0
        endif
endrep until (goflag EQ 1)
ymin = float(scalestring[0])
ymax = float(scalestring[1])
end
