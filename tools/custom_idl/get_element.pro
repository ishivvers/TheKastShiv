pro get_element, wave, wavelength, element

;--------------------------------------------------------------
; Program to find the array element of a spectrum
; closest to a given wavelength.
;
; Wavelength scale must be linear!!
;
; AJB, 9/10/97,modified 5/5/98
;------------------------------------------------------------



if n_params() lt 1 then begin
    print, 'get_element,wave,wavelength,element'
    retall
endif

npix = n_elements(wave)

wzero = wave[0]

deltaw = wave[1] - wave[0]

e = (wavelength - wzero) / deltaw

element =  round(e)

if (element lt 0) then element =  0
if (element gt npix-1) then element =  npix-1

return
end

