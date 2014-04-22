iqutils.py contains auxiliary scripts
kast_redux.py contains the main reduction scripts (imports iqutils)
01242014_kastredux.txt contains the pyraf script setup and calling sequences that get copy-pasted right into a terminal running the pyraf environment.

You will see that 01242014_kastredux.txt imports kast_redux, and then calls one of three scripts in kast_redux.py:
kast_redux.red_standard
kast_redux.blue_standard
kast_redux.do_all_science

So those are where you want to start, in kast_redux.py.




Some additional setup information in case you actually want to run it:

The file kast_instructions.txt includes more about setup, and step-by-step instructions on what to do when presented with the pop-up windows that require interaction. If you really want to run it, probably easiest to have an experienced person sitting next to you.

I included some processed data in 01242014. One directory for each for the blue and red sides of the standard (low.blue.uvir/, low.red.uvir/), and one directory for the science target (SN2014J/). The low.blue.uvir/ and low.red.uvir/ directories start out with just raw data in them. The SN2014J/ directory starts out with three sub-directories, red/ blue/ and combine/, with the raw data only in red/ and blue/. There is a caveat here that I altered the CR rejection in kast_redux.py when running it for SN2014J (but not in the version I sent you); the exposure times were so short, and SN2014J so bright, that the CR rejection would process e.g. the edge of the telluric as a CR. Messed things up.

On my Mac, I have this line in my ".profile"
export PYTHONPATH=$PATH:${PYTHONPATH}:$HOME/scripts/PTF/

In $HOME/scripts/PTF/ I have all the files in homescriptsptf.tar
