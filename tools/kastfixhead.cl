procedure fixhead (images)

# kastfixhead.cl
#
#  Updates and fixes a few header values in
#   Kast ccd images.
#  Authored: long time ago (Silverman, Foley, Matheson, ?)
#  Modified: 2014 (I.Shivvers)
#
 
	string images {prompt="Image(s) to be fixed"}
	struct *imglist

	begin

		string imgfile,timeo,dateo,dateobs
        struct img

        if (!defpac("noao")) noao
        if (!defpac("astutil")) astutil     # need asthedit task
        
        imgfile = mktemp("tmp$ctr")
        sections (images,option="fullname", >imgfile)
        imglist = imgfile
 
		while (fscan(imglist,img) != EOF) {
	    	imgets(img,"DATE-OBS")
		    dateobs=imgets.value
	        timeo=substr(dateobs,12,33)
		    #print (timeo)
			hedit(img,"UT",timeo,add+,del-,ver-,show+,upd+)

		    hedit(img,"OBSERVAT","lick",add+,del-,ver-,show+,upd+)
	        hedit(img,"DISPAXIS",1,add+,del-,ver-,show+,upd+)
	        asthedit(img,'/o/ishivvers/kastreductions/TheKastShiv/tools/cmds.asthedit',upd+,verbose+,oldstyl-)
		    optpa(img)
		}
	
	end
