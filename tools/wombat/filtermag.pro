PRO filtermag, w, f, filtw, filtf, zp, mag, flux, coverage, efflambda
npix = n_elements(w)
nfilt = n_elements(filtw)

IF ((w[0] GT filtw[nfilt-1]) OR (w[npix-1] LT filtw[0])) THEN BEGIN
    print, 'Filter and spectrum do not overlap'
    print, 'Bailing out and returning mag of 999'
    mag = 999
    flux = 999
    coverage = 0
    efflambda = 0
    return
ENDIF

blueindex = where(w LT filtw[0], nb)
IF (nb LE 0) THEN bindex = 0
IF (nb GT 0) THEN bindex = blueindex[nb-1]+1


redindex = where(w GT filtw[nfilt-1], nr)
IF (nr LE 0) THEN rindex = npix-1
IF (nr GT 0) THEN rindex = redindex[0]-1

wmatch = w[bindex:rindex]
fmatch = f[bindex:rindex]

nmatch = n_elements(wmatch)

y2 = spl_init(filtw, filtf)
filtspl = spl_interp(filtw, filtf, y2, wmatch)

filterconv, wmatch, fmatch, filtspl, flux

wmatchplusone = shift(wmatch, -1)
wmatchminusone = shift(wmatch, 1)

wmatchplusone[nmatch-1] = wmatchplusone[nmatch-2] + (wmatchplusone[nmatch-2]-wmatchplusone[nmatch-3])
wmatchminusone[0] = wmatchminusone[1] - (wmatchminusone[2]-wmatchminusone[1])
rat = total(filtspl*(wmatchplusone-wmatchminusone)/2.0)

filtwplusone = shift(filtw, -1)
filtwminusone = shift(filtw, 1)

filtwplusone[nfilt-1] = filtwplusone[nfilt-2] + (filtwplusone[nfilt-2]-filtwplusone[nfilt-3])
filtwminusone[0] = filtwminusone[1] - (filtwminusone[2]-filtwminusone[1])
com = total(filtf*(filtwplusone-filtwminusone)/2.0)

coverage = rat/com


filtereffwave, wmatch, fmatch, filtspl, efflambda

mag = -2.5*alog10(flux/zp)

return
END
