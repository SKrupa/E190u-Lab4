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

The end result actually looks fairly good even though it is not what was intended. As can be seen in the images above, the filter evokes the feel of some existing effects that produce a green wireframe. This could be applied to a game to produce a fairly unique visual that would still be familiar to the player.

A possible improvement to this filter while still keeping with the aesthetic design would be to either remove or increase the amount by which polygons are accented. Currently, the polygons are only accented in direct light which makes it go from a blocky representation to smooth contour lines abruptly. Removing all polygon accents would create a much cleaner shape while increasing the accents would evoke an even stronger wire frame feeling.

#Motion Blur
##Design Methodology

To implement motion blur, I actually used a bug in my code from the edge detection as a starting point. At some point I had written "+=" instead of "=" which was giving my a bizarre multicolored trail behind the teapot. I noticed that by scaling the image properly instead of overflowing the values, once could do this to implement motion blur. 

In order to become more familiar with CUDA, instead of just using the "+=" operator, I made an array of uchar4's in the GPU's memory where I stored the entire motion blur tail. This tail was simply an exponential decay of all the previous frames of the animation. This scaling was adjustable so it generalized to something like this:

Blur[n] = (c1 * Frame[n-1] + c2 * Blur[n-1])/(c1 + c2)

the ratio of c1 to c2 determines how quickly the tail of the blur drops of.

This blur was then added to the display image using another scaling as follows:

DisplayedImage = (c3 * Frame[n] + c4 * Blur[n]) / (c3 + c4)

This behaves identically as the previous function, and the two can be simplified into a single equation removing the need to store the blur seperately, but the one benefit of this is that the intensity of the blur and the length of the tail can be controlled seperately. For example you could have a long, dull tail or a short, bright tail, which would not be possible if there were not a seperate array to store blur values in.


##Results and Discussion

![No blur](https://github.com/SKrupa/E190u-Lab4/blob/master/no%20blur%201.png?raw=true)
No blur
![Low blur length and intensity](https://github.com/SKrupa/E190u-Lab4/blob/master/blur%201.png?raw=true)
Low blur length and intensity
![Medium blur length and intensity](https://github.com/SKrupa/E190u-Lab4/blob/master/blur%202.png?raw=true)
Medium blur length and intensity
![High blur length and intensity](https://github.com/SKrupa/E190u-Lab4/blob/master/blur%203.png?raw=true)
High blur length and intensity

The blur works as intended, showing a clear trail behind quickly moving parts of the object while keeping slower moving parts sharp. There also seems to be a minimal performance hit when the motion blur is turned on.

This architecture could be expanded further than just a single stored blur array. With each added array, a degree of freedom could be added to the blur which would allow more custimization than just intensity and length. Fore example, the exponential drop off could be modified into a square drop off by adding a second blur which would be subracted rather than added.

#Conclusions

Both post-processing functions successfully take an incoming stream and modify it to change the graphics of the output display. Although the edge detection algorithm does not work as was originally intended, I am satisfied with that I was able to do with it

I spent the most time trying to debug the edge detection, which I spend about 4 hours on. It was fairly productive since it made me dig deeper into the code that I had initially planned to. It also served as a kick start to my motion blur function. The actual initial functionality took about 30 minutes. I spent a further 45 minutes at the end making the edge detection fit better as a contour line detector.

The motion blur algorithm took me about 2 hours to implement and test.
