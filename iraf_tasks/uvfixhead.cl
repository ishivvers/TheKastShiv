procedure uvfixhead (images)
 
        string images {prompt="Image(s) to be fixed"}
#        string epoch {prompt="Epoch of coordinates YYYY.YY"}
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
	   print (timeo)
#	   dateo="19"//substr(dateo,17,18)//"-"//substr(dateo,14,15)//"-"//substr(dateo,11,12)
#	   hedit(img,"DATE-OBS",dateo,add+,del-,ver-,show+,upd+)
	   hedit(img,"OBSERVAT","lick",add+,del-,ver-,show+,upd+)
#           hedit(img,"EXPTIME","(EXPOSURE)",add+,del-,ver-,show+,upd+)
	   hedit(img,"UT",'temp',add+,del-,ver-,show+,upd+)
           hedit(img,"UT",timeo,add+,del-,ver-,show+,upd+)
           hedit(img,"DISPAXIS",1,add+,del-,ver-,show+,upd+)
#           hedit(img,"EPOCH",epoch,add+,del-,ver-,show+,upd+)
           asthedit(img,'/j/jsilv/iraf/scripts/cmds.asthedit',upd+,verbose+,oldstyl-) #I.S. Note: CANNOT FIND CMDS.ASTHEDIT#
	   optpa(img)
	}
end
