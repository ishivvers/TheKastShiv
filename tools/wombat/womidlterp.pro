pro womidlterp, wave, flux, newwave, newflux

; Front-end for IDL interpol routine, designed to be a replacement for
; quadterp, newrebin, bonashrebin, and wompixrebin 

newflux = interpol(flux, wave, newwave, /quadratic)
w = where(newwave LT min(wave), count)
if (count GT 0) then newflux[w] = flux[0]

w = where(newwave GT max(wave), count)
if (count GT 0) then newflux[w] = flux[n_elements(flux)-1]



end

