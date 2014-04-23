pro kastbias, filename, y1 = y1, y2 = y2, prefix = prefix, $
              imgleft = imgleft, imgright = imgright

  aaa = systime(/seconds)

  if n_elements(prefix) eq 0 then prefix = 'b'

                                ; Below is a major hack by AAM on
                                ; 2009/06/08 to attempt to remove
                                ; dependancy on an old version of readfits
;  file = float(readfits(filename, fhead))
  file = mrdfits(filename, 0, fhead, /unsigned)
  side = sxpar(fhead, 'VERSION')
  file = float(file)

  ; add header keyword to show we did bias subtraction
  sxaddpar, fhead, 'BIASSUB', 'T', 'Bias subtracted with IDL kastbias.pro'


  if side eq 'kastr' then begin
      gain1 = 3.0

      cbin = ABS(sxpar(fhead, 'CDELT1U')) ; column bin
      rbin = ABS(sxpar(fhead, 'CDELT2U')) ; row bin
      over = sxpar(fhead, 'COVER')        ; number of overscan columns
      naxis1 = sxpar(fhead, 'NAXIS1')     ; number of columns TOTAL
      
      if n_elements(imgleft) eq 0 then imgleft= 2. / rbin
      if n_elements(imgright) eq 0 then imgright= floor((naxis1-2.*over-3.) / rbin)
      if n_elements(y1) eq 0 then yy1 = round(10./cbin) else yy1 = y1
      if n_elements(y2) eq 0 then yy2 = 180./cbin else yy2 = y2

      biassec1 = file[1200:1231, *]

      bias1 = total(biassec1, 1)/32.

      tempimg = file[imgleft:imgright, yy1:yy2]

      delvarx, file

      nel1 = imgright - imgleft
      for i = 0, (yy2-yy1) do begin
         tempimg[*, i] = (tempimg[*, i] - $
                          (fltarr(nel1+1)+bias1[i+yy1]))*gain1
      endfor

     ; remove DATASEC header keyword if it exists
     sxdelpar, fhead, 'DATASEC'

; More hacks by AAM
;      writefits, prefix+filename, tempimg, fhead
      mwrfits, tempimg, prefix+filename, fhead

    endif

  if side eq 'kastb' then begin
     gain1 = 1.2
     gain2 = 1.237              ; gains are different for the two amps

     cbin = ABS(sxpar(fhead, 'CDELT1U'))  ; column bin
     rbin = ABS(sxpar(fhead, 'CDELT2U'))  ; row bin
     over = sxpar(fhead, 'COVER')         ; number of overscan columns
     naxis1 = sxpar(fhead, 'NAXIS1')      ; number of columns TOTAL

     if n_elements(imgleft) eq 0 then imgleft= 2. / rbin
     if n_elements(imgright) eq 0 then imgright= floor((naxis1-2.*over-3.) / rbin)
     if n_elements(y1) eq 0 then yy1 = round(25./cbin) else yy1 = y1
     if n_elements(y2) eq 0 then yy2 = 300./cbin else yy2 = y2

     biassec1=file[imgright+5:imgright+5+(over-4),*]
     biassec2=file[imgright+5+(over-1):imgright+5+(over-1)+(over-4),*]
	
     bias1=total(biassec1,1)/(over-3.)
     bias2=total(biassec2,1)/(over-3.)

     mid=floor(imgright / 2) + 1

     tempimg=file[imgleft:imgright,yy1:yy2]

     delvarx,file

     nel1=mid-imgleft
     nel2=imgright-mid
     for i=0,(yy2-yy1) do begin
        tempimg[0:nel1,i]=(tempimg[0:nel1,i] - $
                           (fltarr(nel1+1)+bias1[i+yy1]))*gain1
        tempimg[nel1+1:*,i]=(tempimg[nel1+1:*,i] - $
                             (fltarr(nel2)+bias2[i+yy1]))*gain2
     endfor

     ; remove DATASEC header keyword if it exists
     sxdelpar, fhead, 'DATASEC'

; Same hack by AAM
;     writefits, prefix+filename, tempimg, fhead
     mwrfits, tempimg, prefix+filename, fhead
     
  endif

  print, systime(/seconds)-aaa, ' seconds to bias subtract ', filename

end
