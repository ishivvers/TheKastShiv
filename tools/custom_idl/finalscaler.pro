PRO finalscaler, flux, ymin, ymax
; this scales the plots in final to ignore the highest and lowest
; pixels, often the source of most of the plotting error
;omin = min(flux, max = omax)
;omax = max(flux)
;ymin = min(flux(where((flux NE omin) AND (flux NE omax))), max = ymax)
;ymax = max(flux(where(flux NE omax)))
s = size(flux)
sf = flux(sort(flux))
ymin = sf[10]
ymax = sf[s[1]-10]
return
END
