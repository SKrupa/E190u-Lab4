/*
 * Copyright 1993-2014 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 *
 */

// Utilities and system includes

#include <helper_cuda.h>

#ifndef USE_TEXTURE_RGBA8UI
texture<float4, 2, cudaReadModeElementType> inTex;
#else
texture<uchar4, 2, cudaReadModeElementType> inTex;
#endif

// clamp x to range [a, b]
__device__ float clamp(float x, float a, float b)
{
    return max(a, min(b, x));
}

__device__ int clamp(int x, int a, int b)
{
    return max(a, min(b, x));
}

// convert floating point rgb color to 8-bit integer
__device__ int rgbToInt(float r, float g, float b)
{
    r = clamp(r, 0.0f, 255.0f);
    g = clamp(g, 0.0f, 255.0f);
    b = clamp(b, 0.0f, 255.0f);
    return (int(b)<<16) | (int(g)<<8) | int(r);
}

// get pixel from 2D image, with clamping to border
__device__ uchar4 getPixel(int x, int y)
{
#ifndef USE_TEXTURE_RGBA8UI
    float4 res = tex2D(inTex, x, y);
    uchar4 ucres = make_uchar4(res.x*255.0f, res.y*255.0f, res.z*255.0f, res.w*255.0f);
#else
    uchar4 ucres = tex2D(inTex, x, y);
#endif
    return ucres;
}

// macros to make indexing shared memory easier
#define SMEM(X, Y) sdata[(Y)*tilew+(X)]

/*
    2D convolution using shared memory
    - operates on 8-bit RGB data stored in 32-bit int
    - assumes kernel radius is less than or equal to block size
    - not optimized for performance
     _____________
    |   :     :   |
    |_ _:_____:_ _|
    |   |     |   |
    |   |     |   |
    |_ _|_____|_ _|
  r |   :     :   |
    |___:_____:___|
      r    bw   r
    <----tilew---->
*/

__global__ void
cudaProcess(unsigned int *g_odata, int imgw, int imgh,
            int tilew, int r, float threshold, float highlight)
{
    extern __shared__ uchar4 sdata[];

    int tx = threadIdx.x;
    int ty = threadIdx.y;
    int bw = blockDim.x;
    int bh = blockDim.y;
    int x = blockIdx.x*bw + tx;
    int y = blockIdx.y*bh + ty;

#if 0
    uchar4 c4 = getPixel(x, y);
    g_odata[y*imgw+x] = rgbToInt(c4.z, c4.y, c4.x);
#else
    // copy tile to shared memory
    // center region
    SMEM(r + tx, r + ty) = getPixel(x, y);

    // borders
    if (threadIdx.x < r)
    {
        // left
        SMEM(tx, r + ty) = getPixel(x - r, y);
        // right
        SMEM(r + bw + tx, r + ty) = getPixel(x + bw, y);
    }

    if (threadIdx.y < r)
    {
        // top
        SMEM(r + tx, ty) = getPixel(x, y - r);
        // bottom
        SMEM(r + tx, r + bh + ty) = getPixel(x, y + bh);
    }

    // load corners
    if ((threadIdx.x < r) && (threadIdx.y < r))
    {
        // tl
        SMEM(tx, ty) = getPixel(x - r, y - r);
        // bl
        SMEM(tx, r + bh + ty) = getPixel(x - r, y + bh);
        // tr
        SMEM(r + bw + tx, ty) = getPixel(x + bh, y - r);
        // br
        SMEM(r + bw + tx, r + bh + ty) = getPixel(x + bw, y + bh);
    }

    // wait for loads to complete
    __syncthreads();

    // perform convolution
    float rsum = 0.0f;
    float gsum = 0.0f;
    float bsum = 0.0f;
    float samples = 0.0f;

    for (int dy=-r; dy<=r; dy++)
    {
        for (int dx=-r; dx<=r; dx++)
        {
#if 0
            // try this to see the benefit of using shared memory
            uchar4 pixel = getPixel(x+dx, y+dy);
#else
            uchar4 pixel = SMEM(r+tx+dx, r+ty+dy);
#endif

            // only sum pixels within disc-shaped kernel
            float l = dx*dx + dy*dy;

            if (l <= r*r)
            {
                float r = float(pixel.x);
                float g = float(pixel.y);
                float b = float(pixel.z);
#if 1
                // brighten highlights
                float lum = (r + g + b) / (255*3);

                if (lum > threshold)
                {
                    r *= highlight;
                    g *= highlight;
                    b *= highlight;
                }

#endif
                rsum += r;
                gsum += g;
                bsum += b;
                samples += 1.0f;
            }
        }
    }

    rsum /= samples;
    gsum /= samples;
    bsum /= samples;
    // ABGR
    g_odata[y*imgw+x] = rgbToInt(rsum, gsum, bsum);
    //g_odata[y*imgw+x] = rgbToInt(x,y,0);
#endif
}

__global__ void
cudaProcessEdge(unsigned int *g_odata, int imgw, int imgh,
            int tilew, float threshold, float highlight, int edge)
{
    extern __shared__ uchar4 sdata[];

    int tx = threadIdx.x;
    int ty = threadIdx.y;
    int bw = blockDim.x;
    int bh = blockDim.y;
    int x = blockIdx.x*bw + tx;
    int y = blockIdx.y*bh + ty;
	int r = 1;

    // copy tile to shared memory
    // center region
    SMEM(r + tx, r + ty) = getPixel(x, y);

    // borders
    if (threadIdx.x < r)
    {
        // left
        SMEM(tx, r + ty) = getPixel(x - r, y);
        // right
        SMEM(r + bw + tx, r + ty) = getPixel(x + bw, y);
    }

    if (threadIdx.y < r)
    {
        // top
        SMEM(r + tx, ty) = getPixel(x, y - r);
        // bottom
        SMEM(r + tx, r + bh + ty) = getPixel(x, y + bh);
    }

    // load corners
    if ((threadIdx.x < r) && (threadIdx.y < r))
    {
        // tl
        SMEM(tx, ty) = getPixel(x - r, y - r);
        // bl
        SMEM(tx, r + bh + ty) = getPixel(x - r, y + bh);
        // tr
        SMEM(r + bw + tx, ty) = getPixel(x + bh, y - r);
        // br
        SMEM(r + bw + tx, r + bh + ty) = getPixel(x + bw, y + bh);
    }

    // wait for loads to complete
    __syncthreads();

    // perform convolution
    float rsum = 0.0f;
    float gsum = 0.0f;
    float bsum = 0.0f;
	float rsumx = 0.0f;
    float gsumx = 0.0f;
    float bsumx = 0.0f;
	float rsumy = 0.0f;
    float gsumy = 0.0f;
    float bsumy = 0.0f;
	/*float sumx = 0.0f;
	float sumy = 0.0f;
	float sumtot = 0.0f;
	float pixval = 0.0f;*/
    

	//int Gx[3][3] = {{-3,-10,-3},{0,1-edge,0},{3,10,3}};
	//int Gy[3][3] = {{-3,0,3},{-10,1-edge,10},{-3,0,3}};
	int Gx[3][3] = {{-1,-2,-1},{0,1-edge,0},{1,2,1}};
	int Gy[3][3] = {{-1,0,1},{-2,1-edge,2},{-1,0,1}};

        for (int dy=-1; dy<=1; dy++) {
            for (int dx=-1; dx<=1; dx++) {

				//float samples = 0.0f;

				uchar4 pixel = SMEM(r+tx+dx, r+ty+dy);

						   
				float r = float(pixel.x);
				float g = float(pixel.y);
				float b = float(pixel.z);
/*
				// brighten highlights
				float lum = (r + g + b) / (255*3);

				if (lum > threshold) {
					r *= highlight;
					g *= highlight;
					b *= highlight;
				}*/
				//pixval = r*0.2126+g*0.7152+b*0.0722;
				//pixval = r+g+b;
				//sumx += pixval*(Gx[dx+1][dy+1]);
				//sumy += pixval*(Gy[dx+1][dy+1]);
                
				rsumx += Gx[dx+1][dy+1]*r;
				gsumx += Gx[dx+1][dy+1]*g;
				bsumx += Gx[dx+1][dy+1]*b;
				rsumy += Gy[dx+1][dy+1]*r;
				gsumy += Gy[dx+1][dy+1]*g;
				bsumy += Gy[dx+1][dy+1]*b;
				
            }
        
        }
	//rsum = rsqrtf(rsumx*rsumx+rsumy*rsumy);
	//gsum = rsqrtf(gsumx*gsumx+gsumy*gsumy);
	//bsum = rsqrtf(bsumx*bsumx+bsumy*bsumy);
	/*if(edge==0) {
		sumx = sumx/9.0;
		sumy = sumy/9.0;
	}*/

	int rsqrsums = rsumx*rsumx+rsumy*rsumy;
	int gsqrsums = gsumx*gsumx+gsumy*gsumy;
	int bsqrsums = bsumx*bsumx+bsumy*bsumy;
	
	if(rsqrsums)
		rsqrsums = 500*0.2126*rsqrtf(rsqrsums);
	if(gsqrsums)
		gsqrsums = 500*0.7125*rsqrtf(gsqrsums);
	if(bsqrsums)
		bsqrsums = 500*0.0722*rsqrtf(bsqrsums);

	rsum = rsqrsums;
	gsum = gsqrsums;
	bsum = bsqrsums;    
	//rsum /= samples;
    //gsum /= samples;
    //bsum /= samples;
    // ABGR
    g_odata[y*imgw+x] = rgbToInt(rsum, gsum, bsum);
    //g_odata[y*imgw+x] = rgbToInt(x,y,0);
}

__global__ void
cudaProcessBlur(unsigned int *g_odata, uchar4 *oldData, int imgw, int imgh)
{
    extern __shared__ uchar4 sdata[];

    int tx = threadIdx.x;
    int ty = threadIdx.y;
    int bw = blockDim.x;
    int bh = blockDim.y;
    int x = blockIdx.x*bw + tx;
    int y = blockIdx.y*bh + ty;
	//int r = 1;
    
	uchar4 pixel = getPixel(x, y);
	uchar4 oldPixel = oldData[y*imgw+x];

	float r = float(pixel.x);
	float g = float(pixel.y);
	float b = float(pixel.z);
	float ro = clamp(float(oldPixel.x), 0.0f, 255.0f);
	float go = clamp(float(oldPixel.y), 0.0f, 255.0f);
	float bo = clamp(float(oldPixel.z), 0.0f, 255.0f);

	int oldmult = 9;
	int newmult = 1;
	int div = oldmult+newmult;
	//oldData[y*imgw+x] = pixel;
	oldData[y*imgw+x].x = (oldmult*oldPixel.x + newmult*pixel.x)/div;
	oldData[y*imgw+x].y = (oldmult*oldPixel.y + newmult*pixel.y)/div;
	oldData[y*imgw+x].z = (oldmult*oldPixel.z + newmult*pixel.z)/div;	   
	
	float intensity = 0.6;

    g_odata[y*imgw+x] = rgbToInt(((1-intensity)*r + intensity*ro), 
								 ((1-intensity)*g + intensity*go), 
								 ((1-intensity)*b + intensity*bo));
    //g_odata[y*imgw+x] = rgbToInt(x,y,0);
}



extern "C" void
launch_cudaProcess(dim3 grid, dim3 block, int sbytes,
                   cudaArray *g_data_array, unsigned int *g_odata,
                   int imgw, int imgh, int tilew,
                   int radius, float threshold, float highlight, int edge, uchar4 *oldData)
{
    checkCudaErrors(cudaBindTextureToArray(inTex, g_data_array));

    struct cudaChannelFormatDesc desc;
    checkCudaErrors(cudaGetChannelDesc(&desc, g_data_array));

#if 0
    printf("CUDA Array channel descriptor, bits per component:\n");
    printf("X %d Y %d Z %d W %d, kind %d\n",
           desc.x,desc.y,desc.z,desc.w,desc.f);

    printf("Possible values for channel format kind: i %d, u%d, f%d:\n",
           cudaChannelFormatKindSigned, cudaChannelFormatKindUnsigned,
           cudaChannelFormatKindFloat);
#endif

    //printf("\n");
#ifdef GPU_PROFILING
    StopWatchInterface *timer = 0;
    sdkCreateTimer(&timer);

    int nIter = 30;

    for (int i = -1; i < nIter; ++i)
    {
        if (i == 0)
        {
            sdkStartTimer(&timer);
        }

#endif
		//unsigned int g_odata_old;
		//uchar4 *oldData;
		//cudaMalloc(&oldData, sizeof(uchar4)*imgw*imgh);
		//cudaProcessBlur<<< grid, block, sbytes >>>(g_odata, oldData, imgw, imgh);

        cudaProcessEdge<<< grid, block, sbytes >>>(g_odata, imgw, imgh,
                                               block.x+(2*1), 0.8f, 4.0f, edge);

        //cudaProcess<<< grid, block, sbytes >>>(g_odata, imgw, imgh,
        //                                       block.x+(2*radius), radius, 0.8f, 4.0f);
        


#ifdef GPU_PROFILING
    }

    cudaDeviceSynchronize();
    sdkStopTimer(&timer);
    double dSeconds = sdkGetTimerValue(&timer)/((double)nIter * 1000.0);
    double dNumTexels = (double)imgw * (double)imgh;
    double mtexps = 1.0e-6 * dNumTexels/dSeconds;

    if (radius == 4)
    {
        printf("\n");
        printf("postprocessGL, Throughput = %.4f MTexels/s, Time = %.5f s, Size = %.0f Texels, NumDevsUsed = %d, Workgroup = %u\n",
               mtexps, dSeconds, dNumTexels, 1, block.x * block.y);
    }

#endif
}
