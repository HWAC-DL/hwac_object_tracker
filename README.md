# hwac_object_tracker
FPGA accelerated TinyYOLO v2 object detection neural network, capable of detecting 95 object classes. The design obtained the **5th place out of 65 teams, in the FPGA category, in the System Design Contest in Design Automation Conference 2018, San Fransisco** (https://dac.com/content/2018-system-design-contest). 

The final rankings are published in http://www.cse.cuhk.edu.hk/~byu/2018-DAC-HDC/ranking.html#final

The team list is in http://www.cse.cuhk.edu.hk/~byu/2018-DAC-HDC/teams.html

![alt text](Others/Ranking.PNG?raw=true "Title")

The design was deployed in the Xilinx PYNQ-Z1 platform (http://www.pynq.io/)

![alt text](Others/0.jpg?raw=true "Title")

# Design

The design is based on the TinyYOLO v2 Object Detection Neural Network (https://pjreddie.com/darknet/yolo/). We used Half-Precision Floating point (16 bit) our design. The implementation was done on Verilog HDL and using the Vivado 2017.2

The block design of our architecture is as follows,

![alt text](Others/BD1.png?raw=true "Title")

The Vivado block design connecting our IP to the Zynq Processing System is as follows,

![alt text](Others/BD2.png?raw=true "Title")
   
# Repo Organization

* Images : contains the test images, annotations
* Others : contains documentation related files
* Results : contains the detection results
* hw : contains the RTL source files and the vivado projects
  * YOLO - contains the RTL sources and the Vivado project of TinyYOLO neural network implementation
  * TOP - contains the Vivado project with the top level block design
* py : contains the hardware overlay(.bit) and Jupyter Notebook, python libraries, executable on the ARM PS.
