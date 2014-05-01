pro filtereffwave, w, f, filter, value

npix = n_elements(w)
wplusone = shift(w, -1)
wminusone = shift(w, 1)
wplusone[npix-1] = wplusone[npix-2] + (wplusone[npix-2]-wplusone[npix-3])
wminusone[0] = wminusone[1] - (wminusone[2]-wminusone[1])
c = total(w*f*filter*(wplusone-wminusone)/2.0)
n = total(f*filter*(wplusone-wminusone)/2.0)
value = c/n
return
end
