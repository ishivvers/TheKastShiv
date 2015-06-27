# LOGIN.CL -- User login file for the IRAF command language.

# Identify login.cl version (checked in images.cl).
if (defpar ("logver"))
    logver = "IRAF V2.11 May 1997"

set	home		= "replace_me:home"
set	imdir		= "HDR$"
set	uparm		= "home$uparm/"
set	userid		= "replace_me:name"

# Set the terminal type.
if (envget("TERM") == "sun") {
    if (!access (".hushiraf"))
	print "setting terminal type to gterm..."
    stty gterm
} else {
    if (!access (".hushiraf"))
	print "setting terminal type to xgterm..."
    stty xgterm
}

# Uncomment and edit to change the defaults.
set	editor		= vi
set	printer		= lp
set	stdimage	= imt2048
set	stdimcur	= stdimage
set	stdplot		= lw
set	imtype		= fits,inherit
#set	clobber		= no
#set	filewait	= yes
#set	cmbuflen	= 512000
#set	min_lenuserarea	= 24000
#set	imtype		= "imh"

# IMTOOL/XIMAGE stuff.  Set node to the name of your workstation to
# enable remote image display.
#set	node		= ""

# CL parameters you mighth want to change.
#ehinit   = "nostandout eol noverify"
#epinit   = "standout showall"
showtype = yes

# Default USER package; extend or modify as you wish.  Note that this can
# be used to call FORTRAN programs from IRAF.

package user

task    kastfixhead = home$kastfixhead.cl
task    optpa=home$optpa.cl
task    mydisp=home$mydisp.cl

if (access ("home$loginuser.cl"))
    cl < "home$loginuser.cl"
;

keep;   clpackage

prcache directory
cache   directory page type help

# Print the message of the day.
if (access (".hushiraf"))
    menus = no
else {
    clear; type hlib$motd
}

# Print a welcome message
print "\n\n    Welcome to Flipper IRAF!\n\n"

# Delete any old MTIO lock (magtape position) files.
if (deftask ("mtclean"))
    mtclean
else
    delete uparm$mt?.lok,uparm$*.wcs verify-

# List any packages you want loaded at login time, ONE PER LINE.
images          # general image operators
plot            # graphics tasks
dataio          # data conversions, import export
lists           # list processing

# The if(deftask...) is needed for V2.9 compatibility.
if (deftask ("proto"))
    proto       # prototype or ad hoc tasks

tv              # image display
utilities       # miscellaneous utilities
noao            # optical astronomy packages
imred
ccdred
kpnoslit
astutil

keep


