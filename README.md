ETML
====

Script for running eyetracking experiments in MATLAB

This is a framework for running vision experiments in MATLAB, with an emphasis on simple eyetracking studies.

By making just a few tab-delimited config files, you can set up an experiment that presents stimuli, and records gaze data and keypresses.

This is a pre-release that is mostly for personal use, but the goal is to make this easily use-able by anyone who has a few hours of MATLAB experience. Future releases will include (a) an instruction manual, (b) support for interest areas, (c) better support for custom scripts that present stimuli on each trial, (d) support for gaze-contingent stimuli.

To make a new experiment within this framework, download this .git. Then, create a folder with stimuli and config files. Finally, run ETML.m and when prompted for a directory, point it to the folder with the config files. This second step will actually be explained in future releases, but for now, a helpful example experiment can be found at https://github.com/jwdink/GroundPlane_V2 .
