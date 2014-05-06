function mycorrelate, x, y

  fx = fft(x, /double)
  xmean = mean(x)
  ymean = mean(y)
  sigx = sqrt(total((x-xmean)^2.)/n_elements(x))
  sigy = sqrt(total((y-ymean)^2.)/n_elements(y))
  fy = fft(y, /double)
  thingy = shift(float(fft(fx* conj(fy)/sigx/sigy, /double, /inverse)), n_elements(x)/2-1) 
  return, reverse(thingy)

end
