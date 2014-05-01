PRO ra, inputfile, wave, flux
data = read_ascii(inputfile)
wave = data.field1[0,*]
flux = data.field1[1,*]
npix = (size(wave))[2]
wave = wave[0:npix-1]
flux = flux[0:npix-1]
return
end
