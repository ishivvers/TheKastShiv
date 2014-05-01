pro womapl
; this routine adds plots to the existing plot window
; the COMMON block remembers a color index so added plots
; cycle through the five colors
; TM
common wom_active, active
common wom_aplflag, aplflag
COMMON wom_col, col
aplcolor = aplflag mod 5
if (aplcolor EQ 1) then acol = col.red
if (aplcolor EQ 2) then acol = col.blue
if (aplcolor EQ 3) then acol = col.green
if (aplcolor EQ 4) then acol = col.violet
if (aplcolor EQ 0) then acol = col.yellow

womdestruct, active, wave, flux, err, name, npix, header
oplot, wave, flux, psym = 10, color = acol
wshow
aplflag = aplflag+1
end
