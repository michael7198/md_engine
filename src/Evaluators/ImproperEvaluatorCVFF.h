#pragma once
#ifndef IMPROPER_CVFF_H
#include "Improper.h"
class ImproperEvaluatorCVFF {
public:
    inline __device__ float dPotential(ImproperCVFFType improperType, float theta) {
        return -improperType.d * improperType.k * improperType.n * sinf(improperType.n * theta);
    }
    
    // double precision
    inline __device__ double dPotential(ImproperCVFFType improperType, double theta) {
        return  double(-improperType.d) * double(improperType.k) * double(improperType.n) * sin(double(improperType.n) * theta);
    }
    inline __device__ float potential(ImproperCVFFType improperType, float theta) {
        return improperType.k * (1.0f + improperType.d * cosf(improperType.n * theta));

    }


};

#endif

