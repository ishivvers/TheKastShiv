PRO wompixrebin, wave, flux, nwave, nflux
npix = (size(wave))[1]
nrbin = (size(nwave))[1]
nflux = fltarr(nrbin)
;
; icen tell us were the internal elements of nwave are in wave
; i.e., excludes the endpoints so we can do them separately
;
;icen = where((nwave-wave[1])*(wave[npix-2]-nwave) GT 0, no)
icen = where((nwave GT wave[0] AND nwave LT wave[npix-1]), no)
icenlength = n_elements(icen)
IF (no EQ 0) THEN BEGIN
    print, 'Wavelength scales do not overlap--bailing out'
    return
ENDIF
;
; the bpin and bpout are the boundary points of the wavelength bins
; defined like this:
;
; ____|_____|_____|_____|
;        ^
;     ^  |  ^
;     |  |  |
;  BP[i] | BP[i+1]
;        |
;    wave[i] (in angstroms, or whatever)
;
;  Note that the boundary is always halfway in-between points, not 
;  just half the average wavelength dispersion, so non-linearity 
;  should not be a problem


bpin = fltarr(npix+1)
bpin[0:npix-1] = (shift(wave, 1)+wave)/2.0
bpin[0] = wave[0] - (bpin[1]-wave[0])
bpin[npix] = wave[npix-1]+(wave[npix-1]-bpin[npix-1])

bpout = fltarr(nrbin+1)
bpout[0:nrbin-1] = (shift(nwave, 1)+nwave)/2.0
bpout[0] = nwave[0] - (bpout[1]-nwave[0])
bpout[nrbin] = nwave[nrbin-1]+(nwave[nrbin-1]-bpout[nrbin-1])
tabinv, bpin, bpout, bpindex
bpf = floor(bpindex)
bpc = ceil(bpindex)
;
;  Loop through all but endpoints
;
;print, 'icen', icen[0], icen[icenlength-1], npix, nrbin,  icen[icenlength-2]
start = max([icen[0], 1])-1
fin =  min([icen[icenlength-1]+1, nrbin-2])
;print, 'start,fin', start, fin
FOR i = start, fin DO BEGIN
;
;          This if finds out if the new pixels straddle old bins
;          if not, we just find the fraction within the old bins
;
    IF ((bpf[i] EQ bpf[i+1]) AND $
        (bpc[i] EQ bpc[i+1])) THEN BEGIN
        nflux[i] = ((1.0-(bpindex[i] -bpf[i]))*flux[bpf[i]] $
                    - (1.0-(bpindex[i+1] -bpf[i+1]))*flux[bpf[i]]) / $
          ((1.0-(bpindex[i] -bpf[i])) - $
           (1.0-(bpindex[i+1] -bpf[i+1]))) 
    ENDIF ELSE BEGIN 
        leftflux = 0.0
        rightflux = 0.0
        centerflux = 0.0
;
;       If we have to cross a bin in the old scale, we find the flux
;       on the left of the bin edge and the flux on the right, and 
;       then add up the whole bins (if any) in between
;       inelegant solution here, but if bpindex[i]-bpf[i] is zero,
;       this should be zero;
;
        leftflux = (1.0-(bpindex[i] -bpf[i]))*flux[bpf[i]]
        IF (abs(bpindex[i] -bpf[i]) LT 0.0000001) THEN leftflux = 0

        rightflux = (bpindex[i+1] -bpf[i+1])*flux[bpf[i+1]]
;
;       reset to zero (so fractional amount works)
;
        j = 0
;
;       this if statement counts # of whole bins in new bin and loops
;       over them
;
        IF (bpf[i+1]-bpc[i] GE 1) THEN BEGIN
            FOR j = 1, bpf[i+1]-bpc[i] DO BEGIN
                centerflux = centerflux + flux[bpf[i]+j]
            ENDFOR 
            j = j-1
        ENDIF
        leftfraction = (1.0-(bpindex[i] -bpf[i]))
        IF (abs(bpindex[i] -bpf[i]) LT 0.0000001) THEN leftfraction = 0
        nflux[i] = (leftflux+rightflux+centerflux) / $
          (leftfraction +(bpindex[i+1] -bpf[i+1]) + float(j))
    ENDELSE 

ENDFOR
;
; for endpoints, just extend values 
;
IF (icen[0] GT 0) THEN BEGIN
   nflux[0:icen[0]-1] = flux[0]
ENDIF
IF (fin LT nrbin) THEN BEGIN
    nflux[fin+1:nrbin-1] = flux[npix-1]
ENDIF
RETURN

END
