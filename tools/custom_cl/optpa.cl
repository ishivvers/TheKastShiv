procedure optpa (images)

# optpa.cl
#
#  Sets the "OPT_PA" header value in Kast ccd images.
#
#  Authored: long time ago (Silverman, Foley, Matheson, ?)
#  Modified: 2014 (Shivvers)
#  Bug Fix:  2017 (tgbrink) ha=ha+haadj ----> ha=ha-haadj
#

string images {prompt="Image(s) to be fixed"}
struct *imglist

begin

    string imgfile
    string site
    real   ha
    real   dec
    real   lat
    real   colat
    real   codec
    real   hacrit
    real   sineta
    real   pa
    real   factor
    real   pi
    real   exptime
    real   haadj
    struct img
	pi=3.14159265358979

	if (!defpac("noao")) noao
	if (!defpac("astutil")) astutil     # need asthedit task
        
	imgfile = mktemp("tmp$ctr")
	sections (images,option="fullname", >imgfile)
	imglist = imgfile

	while (fscan(imglist,img) != EOF) {
	    imgets(img,"OBSERVAT")
	    site=imgets.value
	    if (site == 'lick') {
	        lat= 0.65176412033641
	    }
	    else if (site == 'keck') {
	        lat=0.3460697018496
	    }
	    else {
	        # assume we're at lick
	        lat= 0.65176412033641
	    }
	    imgets(img,"HA")
	    ha=real(imgets.value)*15.0*pi/180.0
	    imgets(img,"DEC")
	    dec=real(imgets.value)*pi/180.0
	    imgets(img,"EXPTIME")
	    exptime=real(imgets.value)
	    haadj=(exptime/3600.0/2.0)*15.0*pi/180.0
	    ha=ha-haadj
	    
        factor=(sin(lat)*sin(dec)+cos(lat)*cos(dec)*cos(ha))
	    sineta = sin(ha)*cos(lat)/sqrt((1.-factor*factor))
	
	    if (dec<lat) {
	        pa=atan2(sineta,sqrt(1.0-sineta*sineta))*180.0/pi
	    }
        else {
			colat=pi/2.0 -lat
			codec=pi/2.0 -dec
			hacrit = 1.-(cos(colat)*cos(colat))/(cos(codec)*cos(codec))
			hacrit=sqrt(hacrit)/sin(colat)
			hacrit=atan2(hacrit,sqrt(1.0-hacrit*hacrit))
			if (abs(ha) > abs(hacrit)) {
			    pa=atan2(sineta,sqrt(1.0-sineta*sineta))*180.0/pi
			}
			else if (ha > 0) {
			    pa=((pi-atan2(sineta,sqrt(1.0-sineta*sineta)))*180.0/pi)
		    }
			else {
			    pa=((-1.*pi - atan2(sineta,sqrt(1.0-sineta*sineta)))*180.0/pi)
		    }
        }

        hedit(img,"OPT_PA",pa,add+,del-,ver-,show+,upd+)
	}

end
