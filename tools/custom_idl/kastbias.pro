pro kastbias, filename, y1 = y1, y2 = y2, prefix = prefix, $
              imgleft = imgleft, imgright = imgright
;
; kastbias.pro
;
;  Bias-corrects Kast ccd images.
;  Authored: long time ago (Silverman, Miller, Foley, Matheson, ?)
;  Modified: 2014 (I.Shivvers)
;
;  Inputs:
;  - filename
;  - y1, y2: the lower and upper y-axis bounds for trimming the image,
;            (correspond to the edges of the illuminated portion)
;  - prefix: string to prefix to the output image (defaults to 'b')
;  - imgleft, imgright: the lower and upper x-axis bounds for trimming the image,
;             defaults calculated internally.
;
;  Produces:
;  - output file named prefix+filename
;
; NOTES:
;  This script assumes sizes for the overscan/bias sections, and
;  also assumes gain values for each amplifier. It subtracts 
;  the row-specific value of (average_overscan * gain) from each
;  image. I (I.Shivvers) am not entirely sure that is the correct thing
;  to do.  FOLLOWUP: find out if this is the correct way to account for
;  the ccd bias!
;

    ; uncomment to print out timing info (another line near bottom)
    ;timer = systime(/seconds)

    ; determine whether this is blue or red side
    if n_elements(prefix) eq 0 then prefix = 'b'

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

        ; set the size of the final trimmed image
        if n_elements(imgleft) eq 0 then imgleft= 2. / rbin
        if n_elements(imgright) eq 0 then imgright= floor((naxis1-2.*over-3.) / rbin)
        if n_elements(y1) eq 0 then yy1 = round(10./cbin) else yy1 = y1
        if n_elements(y2) eq 0 then yy2 = 180./cbin else yy2 = y2

        ; pull out the overscan/bias section and average it
        biassec1 = file[1200:1231, *]
        bias1 = total(biassec1, 1)/32.

        ; get the trimmed size of the input image
        tempimg = file[imgleft:imgright, yy1:yy2]
        delvarx, file

        ; go through and apply the bias correction to each row
        nel1 = imgright - imgleft
        for i = 0, (yy2-yy1) do begin
            tempimg[*, i] = (tempimg[*, i] - $
                            (fltarr(nel1+1)+bias1[i+yy1]))*gain1
        endfor

        ; remove DATASEC header keyword if it exists and write to file
        sxdelpar, fhead, 'DATASEC'
        mwrfits, tempimg, prefix+filename, fhead
    endif

    if side eq 'kastb' then begin
        gain1 = 1.2
        gain2 = 1.237  ; gains are different for the two blue amps

        cbin = ABS(sxpar(fhead, 'CDELT1U'))  ; column bin
        rbin = ABS(sxpar(fhead, 'CDELT2U'))  ; row bin
        over = sxpar(fhead, 'COVER')         ; number of overscan columns
        naxis1 = sxpar(fhead, 'NAXIS1')      ; number of columns TOTAL

        ; set the size of the final trimmed image
        if n_elements(imgleft) eq 0 then imgleft= 2. / rbin
        if n_elements(imgright) eq 0 then imgright= floor((naxis1-2.*over-3.) / rbin)
        if n_elements(y1) eq 0 then yy1 = round(25./cbin) else yy1 = y1
        if n_elements(y2) eq 0 then yy2 = 300./cbin else yy2 = y2

        ; pull out the overscan/bias sections and average them
        biassec1=file[imgright+5:imgright+5+(over-4),*]
        biassec2=file[imgright+5+(over-1):imgright+5+(over-1)+(over-4),*]
        bias1=total(biassec1,1)/(over-3.)
        bias2=total(biassec2,1)/(over-3.)

        ; find the midpoint, to apply different corrections to the different amps
        mid=floor(imgright / 2) + 1
        
        ; get the trimmed size of the input image
        tempimg=file[imgleft:imgright,yy1:yy2]
        delvarx,file

        ; go through and apply the bias correction to each row
        nel1=mid-imgleft
        nel2=imgright-mid
        for i=0,(yy2-yy1) do begin
            tempimg[0:nel1,i]=(tempimg[0:nel1,i] - $
                              (fltarr(nel1+1)+bias1[i+yy1]))*gain1
            tempimg[nel1+1:*,i]=(tempimg[nel1+1:*,i] - $
                              (fltarr(nel2)+bias2[i+yy1]))*gain2
        endfor

        ; remove DATASEC header keyword if it exists and write to file
        sxdelpar, fhead, 'DATASEC'
        mwrfits, tempimg, prefix+filename, fhead     
    endif

  ; uncomment to print out timing info
  ;print, systime(/seconds)-timer, ' seconds to bias subtract ', filename

end
