# hwac_object_tracker

An implementation of TinyYOLO V2.0 (https://pjreddie.com/darknet/yolo/)
Precision : Half-Precision Float (16 bit)


## Usage

1. Cell 1 : Importing libraries and initializing agent
2. Cell 2 : Downloading the overlay
3. Cell 3 : Downloading weights
            Configuring the PL
            images resizing and processing
4. Cell 4 : Writing results (Cordinates, Time, XML)
5. Cell 5 : Cleanup

Batch Size : 500

## Folder Structure

```
dac_2018
│   README.md
│
└───hwac_object_tracker
│   │   hwac_object_tracker.ipynb
│   │   preprocessing.py
│   │   
│   └───libraries
│   │   │   hwac.py
│   │
│   └───params 
└───images
│
└───overlay
│   │
│   └───hwac_object_tracker
│       │ hwac_object_tracker.bit
│       │ hwac_object_tracker.tcl
│       │ weights95tuned.npy
│       │ l4padding95.npy
│   
└───result
    │   
    └───coordinate
    │   │   
    │   └───hwac_object_tracker
    │   
    └───time
    │   
    └───xml
    


## Results

1. Cordinates : 
    Recorded in \result\coordinate\hwac_object_tracker\hwac_object_tracker.txt
    Each line correspond to <x_min, x_max, y_min, y_max> per image. The cordinates are in the order of images sent to PL
2. Time       :
    Recorded using agent.write function in preprocessing.py
3. XML        : 
    Recorded using agent.save_results_xml function in preprocessing.py


## Note
    
According to our testing on provided 1000 image data set,
    * Average IOU: 0.514
    * Frames per second: 4.91
    
We have tested on Pynq Image v2.1 large number of times and working without issue.
But we could submit in any of the previous months as we could not make a working design till now.
So please inform us if there is any issue/configuration problem.
(nisalp@lseg.com / duvindup@lseg.com)
