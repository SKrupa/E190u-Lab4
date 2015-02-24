#Introduction

The purpose of this lab was to use CUDA to post-process an image on the GPU. This could be achieved by modifying one of the provided samples.

I chose to implement two functions, one which would detect the edges of the image, and the other which would add motion blur to the animation.

#Edge Detection
##Design Methodology

The first thing that I tried to implement was edge detection since this can be achieved using a simple convolution. Since the code provided already had the architecture in place for convolutions, it seemed like it would be fairly trivial to implement a derivative convolution. I decided to implement the Sobel convolution by first convolving the image with the horizontal derivitive and then the vertical derivitive. The specific kernels I used can be seen below.

|    |     |    |
|----|-----|----|
| -3 | -10 | -3 |
| 0  | (1-edgeOnly)   | 0  |
| 3  | 10  |  3 |

|    |     |    |
|----|-----|----|
| -3 | 0 | 3 |
| -10  | (1-edgeOnly)   | 10  |
| -3  | 0  |  3 |

The center of the kernel can be set by the user to be either 0 or 1 by pressing the 'B' key which should toggle between overlaying the edges onto the image or just displaying the edges.

I found that when running these convolutions one after the other, only the most recent one actually affected the image. This may be due to overwriting memory, but I do not see how that should have been a problem since the threads synced inside the functions. Instead, I had to modify the code to do both convolutions within a single function. I acheived this by taking each convolution individually and then taking the square root of the sum of the squares of each convolution. This is not very desirable since it introduces a square root into every iteration of the function, but it solved the problem.

The next problem that I encountered was that the colors were not cooperating with the edge detection well. I would get blue and green edges in random spaces due to the light source since white light would blend into the red teapot. I tried converting the image to greyscale by setting each subpixel value to 0.2126 R + 0.7152 G + 0.0722 B. This returned a good greyscale image, but the edge detection did not work well on it since a lot of the contrast seemed to be lost in the conversion.

Even with the slight functionality that I was getting, I could see that running edge detection on an un-softened, illuminated object would accentuate the polygons. Thus I made the choice of repurposing my edge detection function into a function that would display contour lines. I did this by weighting the colors such that green was the most important and red the least. I chose this weighting because I wanted the countours to mostly track the light source and how the light is projected onto the shape.

![Side of the Contoured Model](https://github.com/SKrupa/E190u-Lab4/blob/master/wire%20frame%20side.png?raw=true)
![Top of the Contoured Model](https://github.com/SKrupa/E190u-Lab4/blob/master/wire%20frame%20top.png?raw=true)
![Bottom of the Contoured Model](https://github.com/SKrupa/E190u-Lab4/blob/master/wire%20frame%20bottom.png?raw=true)

##Results and Discussion

#Motion Blur
##Design Methodology

##Testing Methodology

##Results and Discussion

#Conclusions
