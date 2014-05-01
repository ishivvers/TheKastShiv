PRO rp, inputfile, wave, flux

wave = fltarr(8000)
flux = wave
; my technique  -- still the fastest
get_lun, urpl
openr, urpl, inputfile
i = 0
temp = ''
while not EOF(urpl) do begin
    readf, urpl, temp
    temp = strtrim(strcompress(temp), 2)
;   this if catches a blank line at end of file
    if (temp NE '') then begin
    parts = strsplit(waverange,' ',/extract)
    wave[i] = float(parts[0])
    flux[i] = float(parts[1])
    i = i+1
    endif
endwhile
npix = i
close, urpl
free_lun, urpl
wave = wave[0:npix-1]
flux = flux[0:npix-1]
return
end
