"""
Library of tools pulled from the I.Shivvers iAstro package.

-I.Shivvers, June 2015
"""

from scikits import datasmooth
from scipy.optimize import curve_fit


def smooth( x, y, width=None, window='hanning' ):
    '''
    Smooth the input spectrum y (on wl x) with a <window> kernel
     of width ~ width (in x units)
    If width is not given, chooses an optimal smoothing width.
    <window> options: 'flat', 'hanning', 'hamming', 'bartlett', 'blackman'
    Returns the smoothed y array.
    '''
    if width == None:
        ys,l = datasmooth.smooth_data(x,y,midpointrule=True)
        print 'chose smoothing lambda of',l
        return ys
    # if given an explicit width, do it all out here
    if y.ndim != 1:
        raise ValueError, "smooth only accepts 1 dimension arrays."
    if x.size != y.size:
        raise ValueError, "Input x,y vectors must be of same size"
    if not window in ['flat', 'hanning', 'hamming', 'bartlett', 'blackman']:
        raise ValueError, "Window must be one of 'flat', 'hanning', 'hamming', 'bartlett', 'blackman'"
    avg_width = np.abs(np.mean(x[1:]-x[:-1]))
    window_len = int(round(width/avg_width))
    if y.size < window_len:
        raise ValueError, "Input vector needs to be bigger than window size."
    if window_len<3:
        return y

    s=np.r_[y[window_len-1:0:-1],y,y[-1:-window_len:-1]]

    if window == 'flat': #moving average
        w=np.ones(window_len,'d')
    else:
        w=eval('np.'+window+'(window_len)')

    y=np.convolve(w/w.sum(),s,mode='valid')
    yout = y[(window_len/2):-(window_len/2)]
    if len(yout) < len(x):
        yout = y[(window_len/2):-(window_len/2)+1]
    elif len(yout) > len(x):
        yout = y[(window_len/2):-(window_len/2)-1]
    return yout

def gauss(x, A, mu, sigma):
    return A*np.exp(-(x-mu)**2/(2*sigma**2))
def line(x, a, b):
    return a+b*x
def gpl(x, a,b, A,mu,sigma):
    return gauss(x,A,mu,sigma)+line(x,a,b)
def fit_gaussian( x, y, interactive=False, plot=True, floor=True, p0={} ):
    '''
    Fit a straight line plus a single 1D Gaussian profile to the array y on x.
    Returns a dictionary of the best-fit parameters and the numerical array of the
     best fit.
     
    Options:
     interactive=[False,True]
     If True, will ask for graphical input when fitting line.
     If False, will make reasonable assumptions and try to fit the
      line without human input.
      
     plot=[True,False]
     Only relevant if interactive=False.
     If True, will display final fit plot to verify the quality of fit.
     If False, does not display any plots.
     
     floor=[True,False]
     Include a linear noise floor in the fit.
     
     p0: a dictionary including any of {A,mu,sigma}, to force
         inital parameter guesses if desired.  Only used if interactive=False.
    '''
    
    x = np.array(x)
    y = np.array(y)

    if interactive:
        # get range from plot
        plt.ion()
        plt.figure( figsize=(12,6) )
        plt.clf()
        plt.plot( x, y )
        plt.title('Click twice to define the x-limits of the feature')
        plt.draw()
        print "Click twice to define the x-limits of the feature"
        [x1,y1],[x2,y2] = plt.ginput(n=2)
        # redraw to only that range
        xmin, xmax = min([x1,x2]), max([x1,x2])
        mask = (xmin<x)&(x<xmax)
        plt.clf()
        plt.plot( x[mask], y[mask] )
        plt.title('Click on the peak, and then at one of the edges of the base')
        sized_ax = plt.axis()
        plt.draw()
        print "Click on the peak, and then at one of the edges of the base"
        [x1,y1],[x2,y2] = plt.ginput(n=2)

        A0 = y1-y2
        mu0 = x1
        sig0 = np.abs( x2-x1 )

        if floor:
            # estimate line parameters
            a0 = np.percentile(y[mask], 5.)
            b0 = 0.
            [a,b, A,mu,sigma], pcov = curve_fit(gpl, x[mask], y[mask], p0=[a0,b0, A0,mu0,sig0])
        else:
            [A,mu,sigma], pcov = curve_fit(gauss, x[mask], y[mask], p0=[A0,mu0,sig0])

        # finally, plot the result
        xplot = np.linspace(min(x[mask]), max(x[mask]), len(x[mask])*100)
        plt.ioff()
        plt.close()
        plt.scatter( x,y, marker='x' )
        if floor:
            plt.plot( xplot, gpl(xplot, a,b, A,mu,sigma), lw=2, c='r' )
        else:
            plt.plot( xplot, gauss(xplot, A,mu,sigma), lw=2, c='r' )
        # plt.title('center: {} -- sigma: {} -- FWHM: {}'.format(round(mu,4), round(sigma,4), round(2.35482*sigma,4)))
        plt.axis( sized_ax )
        plt.show()
        
    else:
        # estimate Gaussian parameters or get from input dictionary
        A0 = np.max(y)
        imax = np.argmax(y)
        mu0 = x[imax]
        # estimate sigma as the distance needed to get down to halfway between peak and median value
        median = np.median(y)
        sig0 = 1.
        for i,val in enumerate(y[imax:]):
            if np.abs( (val-median)/(A0-median) ) < .5:
                sig0 = np.abs( x[ imax+i ] - x[imax] )
                break
        # any given parameters trump estimates
        try:
            A0 = p0['A']
        except KeyError:
            pass
        try:
            mu0 = p0['mu']
        except KeyError:
            pass
        try:
            sig0 = p0['sigma']
        except KeyError:
            pass
        if floor:
            # estimate line parameters
            a0 = np.percentile(y, 5.)
            b0 = 0.
            [a,b, A,mu,sigma], pcov = curve_fit(gpl, x, y, p0=[a0,b0, A0,mu0,sig0])
        else:
            [A,mu,sigma], pcov = curve_fit(gauss, x, y, p0=[A0,mu0,sig0])

        if plot:
            plt.figure()
            xplot = np.linspace(min(x), max(x), len(x)*100)
            plt.scatter( x,y, marker='x' )
            if floor:
                plt.plot( xplot, gpl(xplot, a,b, A,mu,sigma), lw=2, c='r' )
            else:
                plt.plot( xplot, gauss(xplot, A,mu,sigma), lw=2, c='r' )
            plt.title('center: {} -- sigma: {} -- FWHM: {}'.format(round(mu,4), round(sigma,4), round(2.35482*sigma,4)))
            plt.show()

    outdict = {'A':A, 'mu':mu, 'sigma':sigma, 'FWHM':2.35482*sigma}
    if floor:
        outdict['line_intercept'] = a
        outdict['line_slope'] = b
        return outdict, gpl(x, a,b, A,mu,sigma)
    else:
        return outdict, gauss(x, A,mu,sigma)