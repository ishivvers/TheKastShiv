PRO filterconv, w, f, filter, value

;conv = f[0]*filter[0]*(w[1]-w[0])
;
;norm = filter[0]*(w[1]-w[0])
npix = n_elements(w)
;FOR i = 1, npix-2 DO BEGIN
;    conv = conv+f[i]*filter[i]*((w[i+1]-w[i-1])/2.0)
;    norm = norm+filter[i]*((w[i+1]-w[i-1])/2.0)
;ENDFOR
;conv = conv + f[npix-1]*filter[npix-1]*(w[npix-1]-w[npix-2])
;norm = norm + filter[npix-1]*(w[npix-1]-w[npix-2])

;val = conv/norm
wplusone = shift(w, -1)
wminusone = shift(w, 1)

wplusone[npix-1] = wplusone[npix-2] + (wplusone[npix-2]-wplusone[npix-3])
wminusone[0] = wminusone[1] - (wminusone[2]-wminusone[1])
c = total(f*filter*(wplusone-wminusone)/2.0)
n = total(filter*(wplusone-wminusone)/2.0)
value = c/n
return
end
