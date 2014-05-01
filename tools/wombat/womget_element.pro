pro womget_element, wave, wavelength, element

;--------------------------------------------------------------
; Program to find the array element of a spectrum
; closest to a given wavelength.
;
; Wavelength scale must be linear!!
;
; AJB, 9/10/97,modified 5/5/98
;  TM modifies heavily, linearity no longer an issue
;------------------------------------------------------------




npix = n_elements(wave)

m = min(abs(wave-wavelength), element)

if (element lt 0) then element =  0
if (element gt npix-1) then element =  npix-1

return
end

