ETML
====
A Framework for Running Eyetracking Experiments in MATLAB

# Author

All original code written by Jacob Dink (jacobwdink@gmail.com)

Structure of this code was originally based on Brock Ferguson's scripts for running studies on infants. See https://github.com/brockf/ORT

# Introduction

This is a framework for running experiments in MATLAB. By making a few spreadsheet files (config.txt, stim_config.txt) to specify your experiment's stucture, you can easily and quickly set up many different types of experiments.

The emphasis is on vision experiments that interface with SR-Research Eyelink Eyetrackers. However, this framework can be helpful in a broader set of cases than that.

Usage  | Solution
------ | --------
You need a quick and ready eyetracking experiment that presents simple instructions, images, and video.  | Simply copy-and-paste the 'Example' folder and adapt it to your needs
You need a fairly simple experiment, but want complete control over the code for a custom need that other experimental software can't accomodate  | Same as above, but tweak the ETML codebase itself to your need. The entire framework is in MATLAB, so you have the full power of MATLAB & PsychToolBox at your disposal
You need to completely customize what happens on each trial, but you want easy management of the trial/block/phase structure (and, optionally, you want an easy, preconfigured interface with the eyetracker). | Same as #1, except also copy the "custom_function.m" template to your folder. Specify what happens on each trial within that function. ETML and the stim_config.txt will handle the ordering of trials, and the sending of data to the eyetracker!

### Key Features:

* Manage experiment structure via a file viewable in Excel, rather than a series of convoluted, nested 'for'-loops inside your experiment code.
* All interfacing with Eyelink eyetracker abstracted and taken care of for you. Worry about making your experiment, not sifting through the eye tracker documentation.
* Detailed, timestamped information sent to eye tracker and to a log text file as experiment runs. Includes all messages, warnings, and keypresses. 
* Key information about trial (condition, stimuli information) sent to a text file, with included R code to parse into 'tidy' R dataframe, ready for analysis. This is important, because it means you can run experiments that don't even use an eyetracker. For those that do, same information is sent to eye tracker.
* Experiment can be terminated at any point by pressing and holding ESC, and data so far will be saved.
* Ability to write your own script for what's presented on each trial. Let ETML handle the eyetracker and the experiment structure, and just worry about scripting the actual trial contents.

# Guide

### Requirements

- MATLAB
- [Psych Toolbox](psychtoolbox.com)
- GStreamer (for playing videos; see Psych Toolbox website for instructions)

### Getting Started

To get started, download this git (click "clone in desktop" above). The easiest way to get going is simply to copy and paste the "Example" folder, renaming it to your experiment's name. Additionally, make sure you add the ETML folder, as well as the 'Functions' subfolder, to the MATLAB search path.

## Getting Set-Up : Config.txt

If you open the example config.txt in Excel, you'll see it has a couple entries, along with a description of what each of these entries is for. I won't relist those here, since the example config.txt explains everything fully (exception is the 'CustomFields', explained in the next paragraph). The only fields that are strictly required are 'StudyName' and 'RecordingPhases' (all others will be supplied a default) but you'll likely want to explicitly set the other fields as well.

The 'CustomFields' entry specifies columns in 'Stim_Config' that you have added yourself (i.e., they aren't the pre-designated ones described below) that you'd liked saved in your data. All columns described in the next section are automatically saved in your data, but you might want to add your own columns--either for convenience (they give descriptions to blocks/trials that are otherwise just numbered) or necessity (they help determine things in a custom trial).

## Getting Set-Up : Stim_Config.txt

Open this file in Excel to follow along with this guide. You'll see a table where each column specifies some details about trial or trials, and each row represents either a single trial, or a sequence of trials.

### Basic Structure:

Here are the required columns:

* **Condition** : between subjects condition
* **PhaseNum** : Phase within experiment
* **BlockNum** : Block within phase
* **TrialNum** : Trial within block
* **Stim** : Path or specification of stimulus. 
* **StimType** : What kind of stimuli is being presented? Supported options described below.

An ETML experiment is structured heirarchically, where phases are composed of blocks, blocks are composed of trials. If you include optional column **"ShuffleTrialsInBlock"**, you can set this to 1 for a block, and this will shuffle the trials in that block. Similarly for the optional column **"ShuffleBlockssInPhase"**. Leave this option blank on a given trial/block, or set it 0, to *not* shuffle. 

If your block is set up with multiple trials that have the same stimulus (e.g., 30 trials for 10 different images), one useful option is to set 'ShuffleTrialsInBlock' to `no_consec` (instead of `1`), which will prevent the same stimulus from being presented on two trials in a row.

*Note that in the data output from the experiment, 'trial' and 'block' numbers will specify the order these trials/blocks were shown in, not the original number from this stim_config.txt. In other words, the trial number specified in the config.txt is not meaningful on those blocks where 'TrialShuffle' is on (and ditto for blocks and blockshuffle).*

A 'trial' should, for the most part, be thought of as a single stimulus presentation. This makes analysis much easier: each trial has its own image/video, its own interest areas, etc. However, as decribed below, pre/post stimuli can be added to a trial.

### StimTypes

There are several stimuli types supported:

* **Image** : An image or directory of images
* **Video** : A video or directory of videos (requires GStreamer).
* **Slideshow** : Identical to image, except images are advanced using arrow keys, and you can go backwards to previous images. Useful for presenting instructions to experiment.
* **Text** : Display a line of text.
* **Custom** : A custom script you wrote yourself. Will simply call 'custom_function' on trials with this stim_type. See 'Custom Trials' section below.

ETML knows how to interpret any of the following optional columns (for images, videos, and text):

* **StimCenterX, StimCenterY** : What position on the screen do you want the stim to be? (E.g., `400,400` puts the center of the 400 pixels below the top of the screen, and 400 pixels rightwards of the left-side of the screen). Default is centered.
* **FlipX, FlipY** : Mirror the stim? Default no.
* **DimX, DimY** : What dimensions in pixels do you want the stim to have? Default is original dimensions


### Trial / Stimuli Duration

Trials have a duration, which can be specified (*in units of seconds*) with the **"StimDuration"** column. 

A single number entered here will specify the minimum and maximum duration of this stimulus (i.e., time to keep stim up, regardless of keypress). 

If you enter two numbers in brackets (i.e., valid MATLAB syntax-- e.g., `[1,3]`), the first will be used as the minimum duration (i.e., stays up at least this long, regardless of keypress), the second will be used as the maximum duration (i.e., ends by this time even if no keypress registered).

For 'default' behavior, leave blank or enter 0. 'Default' behavior is different for images and videos. For images, default means keep on screen indefinitely until keypress; for videos, default means keep on screen until end of video (and keypress will not terminate video early).

### Repeating Trials with 'TrialNum':

A key feature of ETML is that you don't have to specify every single trial manually. Instead, you can use indexing to specify trials. This follows the same syntax as MATLAB, except you must always wrap the numbers in brackets (otherwise excel will think it's a timestamp).

For example, if I have a row where stim is "repetitive_picture.png", and I want that stim to be shown on trials 1 through 10, I would enter `[1:10]` in the TrialNum column for that row (brackets required!!). Or, if I wanted it presented only on *even* trials, I could enter `[2:2:10]`. Any indexing possible in MATLAB will be obeyed here, making this a powerful tool. For example, I could easily make an image flipped on half of the trials, or change its position every fourth trial, etc.

This feature applies not just to the TrialNum column, but to the Condition, PhaseNum, and BlockNum columns as well.

### Draw Stimuli from a Folder:

The "Stim" column, especially in conjunction with the capacity to repeat trials described above, can be particularly useful. **Instead of specifying a particular stimulus to be repeated, you can specify a folder of stimuli. In this case, stimuli will be drawn from that folder, with a different one presented on each trial.**

___
##### Advanced: Method of Drawing Stim from Folder:

You can specify how to draw stimuli from the folder with the optional column **"StimDrawFromFolderMethod"**.

**Note:** *If your number of trials = your number of stim, and you're simply shuffling your trials (as described above), or simply running your trials in order, these options aren't something you have to worry about.*

The options for **"StimDrawFromFolderMethod"** are:

- **Ascending ('asc')** : The default. Pick the filenames within the folder in alphabetical/numeric order.
- **Descending ('desc')** : Pick the filenames within the folder in reverse-alphabetical/numeric order.
- **Sample Randomly without Replacement ('sample')** : Randomly sample without replacement. 
  - If number of stimuli is greater than or equal to number of trials, this has obvious behavior: draw from pool of possible stimuli for each trial.
  - If number of stimuli is less than number of trials, exhaust contents of folder before looping back through.
- **Sample Randomly with Replacement ('sample_replace')** : Randomly sample *with* replacement. 

___

### Pre/Post Stimuli

The main focus of a trial is the stimulus being presented. Often, however, we want to ask a question before a stimulus presentation, and/or await a response.

ETML supports the following columns: **PreStim**, **PreStimType**, **PreStimDuration**, **PostStim**, **PostStimType**, **PostStimDuration**. The options and details for these are identical to those for 'Stim', described above.

These columns can be ommitted or left blank if these are not needed.
___

##### Advanced: Looping Through Multiple Pre/Post-Stim for Given Stimulus:

PreStim, PostStim, and Stim all should indicate a stim-directory, stim-path, text (for StimType = 'text'), or a cell-array filled with these. For example, for PreStimType = 'text', you could enter (all on one line):

```
{"Find the largest object in the following image", 
 "Find the reddest object in the following image", 
 "Find the oddball in this image"}
``` 

When a cell array like this is supplied, the stimulus in the 'Stim' column will be presented once for EACH of these messages. Similarly, if 'Stim' specifies a folder (not a single file), each image will be shown three times in a row, one for each message. So if you want *all* stim-files in a folder to be shown, make sure your TrialNum column reflects this: for example, for ten images in a folder, and three different 'before' messages, the "TrialNum" column should specify `[1:30]` (3 trials for each of the 10 images). The idea behind this method of pairing is to follow a common study design: you may want to ask multiple questions of the same image. 

In contrast, PreStim and PostStim are assumed to be matched: e.g., if one is a cell array of length three, the other must be length three as well. Again, this is to follow the common study design of (1) telling the participant what they will be asked, (2) showing stimuli, (3) asking them about what they saw. In other words, it's assumed that (1) and (3) go together (e.g., "you will be asked about X"; [image]; "here's a question about X").

You can also randomly sample from these question/stim-item pairings with the options described in the previous section ('ShuffleTrialsInBlock'). One useful option is the non-consecutive option: randomly select a stim-item and a question to show before/after it, with the constraint that the same stim-item can't be shown twice in a row.

___


## Custom Trials

*[This section a work in progress. For now, the 'custom_function.m' file in the Example folder should give you much of the information you need. The main 'TO DO' for me is to give better documentation to the various functions in ETML, so that they can be used by anyone writing their own custom trial (e.g., logging messages, recording/logging keypresses).]*

## Running the Experiment

Simply run ETML.m in MATLAB. It will open up a directory-chooser. Navigate to the directory with your experiment in it.

You'll then be asked to enter session information about the participant, condition, etc. After this is done, the experiment will begin. 

___
##### Advanced: Custom Session Information and Calling ETML Programmatically

*[This section a work in progress]*

___

## Getting the Data

### Session Data

Included in this package is an R script that takes a folder of session files, and turns them into a DataFrame in R.

*[This section a work in progress. Using the convert_session_files function should be relatively straightforward, however.]*

### Eye-Tracker Data

You can get data from the EDF files, just like any other Eyelink experiment, using Dataviewer. Note that all timestamps--both those made by EyeLink for gaze data, and those made by ETML for keypresses, stim-presentation, etc.--are relative to the beginning of the recording on that trial. The columns 'StimStartMS' and 'StimStopMS' should therefore allow you to easily derive a 'TimeInTrial' column. For example, in R:

```
library('dplyr')
df = read.delim("./fixation_report.txt") # data you got from Eyelink DataViewer
df_clean = df %>%
    group_by(RECORDING_SESSION_LABEL, TRIAL_INDEX) %>%
    mutate(CurrentFixStartTime = CURRENT_FIX_START - StimStartMS,           # make new columns for stim-start-adjusted timestamp
           CurrentFixEndTime   = CURRENT_FIX_END   - StimStartMS ) %>%
    filter(CURRENT_FIX_START > StimStartMS, CURRENT_FIX_START < StimStopMS) # filter out everything before and after stim presentation
```
And so on for other (e.g., keypress) columns.

# To Do:

- [ ] Doc-style commenting for all functions
- [ ] More transparent syntax for check_keypress key summary
- [ ] Add to ReadMe: getting session data
- [ ] Add to ReadMe: getting eye-tracker data from DataViewer
- [ ] Add script for common pre-processing steps in R









