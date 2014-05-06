## The Kast Shiv ##

_fast, easy, effective_


This is the Isaac version of the
Flipper group's Kast/Shane reduction pipeline.


### goals of this new code ###

- highly automated
- cuts no corners
- does not require a complicated environment
- lots of documentation
- easy to start/stop/resume at any point in the reduction
- robust to errors
- secondary: does not require IDL

### run setup.py ###

You will need to know the path to your IDL executable

    # from KastShiv root folder
    python setup.py


### include path in environment variables ###

You need to include the following commands in your `bash` login file (e.g., `~/.bashrc`):

    export IDL_PATH=$IDL_PATH:+<KAST_SHIV_DIRECTORY>/tools
    export PYTHONPATH=$PYTHONPATH:<KAST_SHIV_DIRECTORY>


### create the `credentials.py` file ###

There must exists a file named `credentials.py` in the KastShiv folder, and in
that file there must live the credentials for logging into the Kast data repository
and the flipperwiki.  For example:

    # credentials.py
    wiki_un = 'USERNAME'
	wiki_pw = 'PASSWORD'
	repository_un = 'USERNAME'
	repository_pw = 'PASSWORD'

### to do ###

- write an install script that takes template files and
  inserts into them the proper paths for all files that require
  modification.