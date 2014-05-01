pro womrpl
common wom_active, active
common wom_arraysize, arraysize
inputfile = ''
repeat begin
    existflag = 1
    print, ' '
    read,  'What is the name of the file to read? ', inputfile
    if (inputfile EQ '') then return
    inputfile = strtrim(inputfile,2)
    isfile = findfile(inputfile, COUNT = count)
    if (count EQ 0) then begin
        print, strcompress('File '+inputfile+' does not exist.')
        existflag = 0
    endif
endrep until (existflag EQ 1)
wave = fltarr(arraysize)
flux = wave
err  = wave

;  below is read_ascii block

; data = read_ascii(inputfile)
; wave = data.field1[0,*]
; flux = data.field1[1,*]
; npix = (size(wave))[2]
; wave = wave[0:npix-1]
; flux = flux[0:npix-1]

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
    parts = strsplit(temp,' ',/extract)
    wave[i] = float(parts[0])
    flux[i] = float(parts[1])
    if (n_elements(parts) gt 2) then err[i] = float(parts[2]) $
      else err[i] = 1.
    i = i+1
    endif
endwhile
npix = i
;
;  idlastro technique
; rdfloat, inputfile, wave, flux
; npix = (size(wave))[1]


print, ' '
print, strcompress('Found '+string(npix)+' bins.')

active.wave = wave
active.flux = flux
active.err = err
active.obname = inputfile
active.head = ''
active.nbin = npix
close, urpl
free_lun, urpl
end
