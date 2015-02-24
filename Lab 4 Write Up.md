#Introduction

The purpose of this lab was to use CUDA to post-process an image on the GPU. This could be achieved by modifying one of the provided samples.

#Design Methodology

The first thing that I tried to implement was edge detection since this can be achieved using a simple convolution. Since the code provided already had the architecture in place for convolutions, it seemed like it would be fairly trivial to implement a derivative convolution. I decided to implement the Sobel convolution by first convolving the image with the horizontal derivitive and then the vertical derivitive. The specific kernels I used can be seen below.

|    |     |    |
|----|-----|----|
| -3 | -10 | -3 |
| 0  | (1-edgeOnly)   | 0  |
| 3  | 10  |  3 |

|    |     |    |
|----|-----|----|
| 3 | 0 | 3 |
| 10  | (1-edgeOnly)   | 10  |
| 3  | 0  |  3 |

#Testing Methodology

#Results and Discussion

#Conclusions
