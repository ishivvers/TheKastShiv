PRO womfilters

common wom_active, active
common wom_ulog, ulog

womdestruct, active, wave, flux, name, npix, header

print, 'NOTE:  The routine expects an f_lambda spectrum'
print, '       I will try to guess if the spectrum'
print, '       has been scaled by 1E15'
print, ' '
print, '       Check this before believing fluxes'
print, ' '

IF ((moment(flux))[0] GT 0.00001) THEN flux = flux *1e-15


filtwave = fltarr(24, 5)
filttran = fltarr(24, 5)
filtwave[0:20, 1] = [3600.00, 3700.00, 3800.00, 3900.00, $
4000.00, 4100.00, 4200.00, 4300.00, $
4400.00, 4500.00, 4600.00, 4700.00, $
4800.00, 4900.00, 5000.00, 5100.00, $
5200.00, 5300.00, 5400.00, 5500.00, $
5600.00] 
filttran[0:20, 1] = [0.00000, 0.03000, 0.13400, 0.56700, $
0.92000, 0.97800, 1.00000, 0.97800, $
0.93500, 0.85300, 0.74000, 0.64000, $
0.53600, 0.42400, 0.32500, 0.23500, $
0.15000, 0.09500, 0.04300, 0.00900, $
0.00000]
filtwave[*, 2] = [4700.00, 4800.00, 4900.00, 5000.00, $
5100.00, 5200.00, 5300.00, 5400.00, $
5500.00, 5600.00, 5700.00, 5800.00, $
5900.00, 6000.00, 6100.00, 6200.00, $
6300.00, 6400.00, 6500.00, 6600.00, $
6700.00, 6800.00, 6900.00, 7000.00] 
filttran[*, 2] = [0.00000, 0.03000, 0.16300, 0.45800, $
0.78000, 0.96700, 1.00000, 0.97300, $
0.89800, 0.79200, 0.68400, 0.57400, $
0.46100, 0.35900, 0.27000, 0.19700, $
0.13500, 0.08100, 0.04500, 0.02500, $
0.01700, 0.01300, 0.00900, 0.00000]
filtwave[*, 3] = [5500.00, 5600.00, 5700.00, 5800.00, $
5900.00, 6000.00, 6100.00, 6200.00, $
6300.00, 6400.00, 6500.00, 6600.00, $
6700.00, 6800.00, 6900.00, 7000.00, $
7100.00, 7200.00, 7300.00, 7400.00, $
7500.00, 8000.00, 8500.00, 9000.00]
filttran[*, 3] = [0.00000, 0.23000, 0.74000, 0.91000, $
0.98000, 1.00000, 0.98000, 0.96000, $
0.93000, 0.90000, 0.86000, 0.81000, $
0.78000, 0.72000, 0.67000, 0.61000, $
0.56000, 0.51000, 0.46000, 0.40000, $
0.35000, 0.14000, 0.03000, 0.00000]
filtwave[0:22, 4] = [7000.00, 7100.00, 7200.00, 7300.00, $
7400.00, 7500.00, 7600.00, 7700.00, $
7800.00, 7900.00, 8000.00, 8100.00, $
8200.00, 8300.00, 8400.00, 8500.00, $
8600.00, 8700.00, 8800.00, 8900.00, $
9000.00, 9100.00, 9200.00]
filttran[0:22, 4] = [0.00000, 0.02400, 0.23200, 0.55500, $
0.78500, 0.91000, 0.96500, 0.98500, $
0.99000, 0.99500, 1.00000, 1.00000, $
0.99000, 0.98000, 0.95000, 0.91000, $
0.86000, 0.75000, 0.56000, 0.33000, $
0.15000, 0.03000, 0.00000]

filtwave[*, 0] = [3050.00, 3100.00, 3150.00, 3200.00, $
3250.00, 3300.00, 3350.00, 3400.00, $
3450.00, 3500.00, 3550.00, 3600.00, $
3650.00, 3700.00, 3750.00, 3800.00, $
3850.00, 3900.00, 3950.00, 4000.00, $
4050.00, 4100.00, 4150.00, 4200.00]
filttran[*, 0] = [0.00000, 0.02000, 0.07700, 0.13500, $
0.20400, 0.28200, 0.38500, 0.49300, $
0.60000, 0.70500, 0.82000, 0.90000, $
0.95900, 0.99300, 1.00000, 0.97500, $
0.85000, 0.64500, 0.40000, 0.22300, $
0.12500, 0.05700, 0.00500, 0.00000]
filtsize = [24, 21, 24, 24, 23]
;		Holds the filter zero-points as determined from
;		Vega model by Dreiling & Bell (ApJ, 241,736, 1980)
;
;		B	6.268e-9   erg cm-2 s-1 A-1
;		V	3.604e-9
;		R	2.161e-9
;		I	1.126e-9
;
;		The following zero-points are from Lamla
;		(Landolt-Boernstein Vol. 2b, eds. K. Schaifer & 
;		H.H. Voigt, Berlin: Springer, p. 73, 1982 QC61.L332)
;
;		U	4.22e-9   erg cm-2 s-1 A-1
;
;		J	3.1e-10
;		H	1.2e-10
;		K	3.9e-11
;
;               U        B          V        R         I
zeropoint = [4.22e-9, 6.268e-9, 3.604e-9, 2.161e-9, 1.126e-9]
mag = fltarr(5)
filtflux = fltarr(5)
coverage = fltarr(5)
efflambda = fltarr(5)
FOR i = 0, 4 DO BEGIN
    filtw = filtwave[0:filtsize[i]-1, i]
    filtf = filttran[0:filtsize[i]-1, i]
    filtermag, wave, flux, filtw, filtf, zeropoint[i], m, f, c, e
    mag[i] = m
    filtflux[i] = f
    coverage[i] = c
    efflambda[i] = e
ENDFOR
filtername = ['U', 'B', 'V', 'R', 'I']
print, ' '
print, strcompress('For '+name)
printf, ulog, strcompress('For '+name)
print, ' '
format = '(2X,A1,8X,f6.3,8X,e10.4,10X,f5.1,9X,f6.1)'
    print, 'Filter    magnitude   Flux (erg/s/cm^2/A)   Coverage(%)  Eff. Lambda'
printf, ulog, 'Filter    magnitude   Flux (erg/s/cm^2/A)   Coverage(%)  Eff. Lambda'
nomag = '(2X,A1,8X,A35)'
nocover = 'FILTER AND SPECTRUM DO NOT OVERLAP'
FOR i = 0, 4 DO BEGIN
    IF (mag[i] GT 990) THEN BEGIN
        print, filtername[i], nocover, format = nomag
        printf, ulog, filtername[i], nocover, format = nomag
    ENDIF ELSE BEGIN
    print, filtername[i], mag[i], filtflux[i], coverage[i]*100, efflambda[i], format = format
    printf, ulog, filtername[i], mag[i], filtflux[i], coverage[i]*100, efflambda[i], format = format
    endelse
ENDFOR 

print,  ' '
print, 'Colors: '
printf, ulog, 'Colors: '
colortab = [[0,1],[1,2],[2,3],[2,4]]
format = '(A1,A1,A1,4X,g12.4)'
nomag = '(A1,A1,A1,4X,A45)'
nocover = 'ONE OR BOTH FILTERS DO NOT OVERLAP SPECTRUM'
dash = '-'
FOR i = 0, 3 DO BEGIN
    IF (mag[colortab[0, i]] GT 990 OR mag[colortab[1, i]] GT 990) THEN BEGIN
        print, filtername[colortab[0, i]], dash, filtername[colortab[1, i]], $
      nocover, format = nomag
        printf, ulog, filtername[colortab[0, i]], dash, filtername[colortab[1, i]], $
      nocover, format = nomag
    ENDIF ELSE BEGIN
        print, filtername[colortab[0, i]], dash, filtername[colortab[1, i]], $
          (mag[colortab[0, i]]-mag[colortab[1, i]]), format = format
        printf, ulog, filtername[colortab[0, i]], dash, filtername[colortab[1, i]], $
          (mag[colortab[0, i]]-mag[colortab[1, i]]), format = format
    ENDELSE
ENDFOR

end
