pro womrerrfits
common wom_active, active
inputfile = ''
repeat begin
    existflag = 1
    print, ' '
    print,  'What is the name of the multispec file to read?'
    print, '(.ms.fits will be added, if necessary): '
    read,  ': ', inputfile
    if (inputfile EQ '') then return
    inputfile = strtrim(inputfile, 2)
    if (rstrpos(inputfile, '.ms.fits') EQ -1) then begin
        inputfile = strcompress(inputfile+'.ms.fits', /remove_all)
    endif
    isfile = findfile(inputfile, COUNT = count)
    if (count EQ 0) then begin
        print, strcompress('File '+inputfile+' does not exist.')
        existflag = 0
    endif
endrep until (existflag EQ 1)
multiflux = readfits(inputfile, spechead)
naps = (size(multiflux))[2]
;print
;print,  $
;  strcompress('There are ' + string(naps) + ' apertures in this spectrum.')
;print
;nbands = (size(multiflux))[3]
;print
;print,  $
;  strcompress('There are ' + string(nbands) + ' bands in each aperture.')
;print
; crval1 = float(sxpar(spechead, 'CRVAL1'))
; wdelt = float(sxpar(spechead, 'CDELT1'))
objectname = sxpar(spechead, 'OBJECT')
sizeo = size(objectname, /type)
if (sizeo NE 7) then begin
    objectname = inputfile
endif
print, strcompress('The object is '+objectname)
npix = (size(multiflux))[1]

;ap = 1
;IF (naps NE 1) THEN repeat BEGIN
;    ap = ''
;    print,  'Which aperture do you want?'
;    read,  ap
;    ap =  fix(ap)
;endrep until (ap GE 1) and (ap LE naps) 
ap = 0;ap-1
womgetmswave, spechead, npix, ap, wave
wdelt = wave[1]-wave[0]
sxdelpar,  spechead,  'WAT0_001'
sxdelpar,  spechead,  'WAT1_001'
sxdelpar,  spechead,  'WAT2_001'
sxdelpar,  spechead,  'WAT0_002'
sxdelpar,  spechead,  'WAT1_002'
sxdelpar,  spechead,  'WAT2_002'
sxdelpar,  spechead,  'WAT3_001'
sxdelpar,  spechead,  'WAT2_003'
sxdelpar,  spechead,  'CTYPE1'
sxdelpar,  spechead,  'CTYPE2'
sxdelpar,  spechead,  'CTYPE3'
sxdelpar,  spechead,  'CD1_1'
sxdelpar,  spechead,  'CD2_2'
sxdelpar,  spechead,  'CD3_3'
sxdelpar,  spechead,  'LTM1_1'
sxdelpar,  spechead,  'LTM2_2'
sxdelpar,  spechead,  'LTM3_3'
sxdelpar,  spechead,  'WCSDIM'
sxaddpar,  spechead,  'CRPIX1', 1
sxaddpar,  spechead,  'CRVAL1', wave[0]
sxaddpar,  spechead,  'CDELT1', wdelt
sxaddpar,  spechead,  'CTYPE1', 'LINEAR'  

spectrim = strtrim(spechead, 1)
realspace = where(strlen(spectrim) EQ 80)
spectrim = spectrim(realspace)
;; IF (nbands NE 1) THEN repeat BEGIN
;;     fband = ''
;;     print,  'Which band is the flux?'
;;     read, fband
;;     fband = fix(fband)-1
;;     plot, wave, multiflux[*,ap,fband], xst = 3, yst = 3, psym = 10, $
;;       xtitle = 'Wavelength', ytitle = 'Flux', color = col.white
;;     wshow
;;     repeat begin
;;       print, 'Okay? (y/n, default=y)'
;;       c = get_kbrd(1)
;;       if ((byte(c))[0] EQ 10) then c = 'y'
;;       c = strlowcase(c)
;;       print, c
;;     endrep until (c EQ 'y') OR (c EQ 'n')
;; endrep until (fband GE 0) and (fband LE naps-1) and (c EQ 'y')
;; IF (nbands NE 1) THEN repeat BEGIN
;;     eband = ''
;;     print,  'Which band is the error?'
;;     read, eband
;;     eband = fix(eband)-1
;;     plot, wave, multiflux[*,ap,eband], xst = 3, yst = 3, psym = 10, $
;;       xtitle = 'Wavelength', ytitle = 'Flux', color = col.white
;;     wshow
;;     repeat begin
;;       print, 'Okay? (y/n, default=y)'
;;       c = get_kbrd(1)
;;       if ((byte(c))[0] EQ 10) then c = 'y'
;;       c = strlowcase(c)
;;       print, c
;;     endrep until (c EQ 'y') OR (c EQ 'n')
;; endrep until (eband GE 0) and (eband LE naps-1) and (c EQ 'y')

active.wave = wave
active.flux = multiflux[*, 0]
active.err  = multiflux[*, 1]
active.obname = objectname
active.head = spectrim
active.nbin = npix

end
