pro womwpl
common wom_active, active
womdestruct, active, wave, flux, err, name, npix, header
print, ' '
print, strcompress('The object is '+name)
print, ' '
spectxt = ''
read, 'Enter the name for the output file: ', spectxt
if (spectxt EQ '') then return
spectxt = strtrim(spectxt, 2)
get_lun, uwpl
openw, uwpl, spectxt

for i = 0, npix-1 do begin
    printf, uwpl, wave[i], flux[i], err[i]
endfor

close, uwpl
free_lun, uwpl
end
