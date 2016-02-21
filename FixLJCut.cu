#include "FixLJCut.h"
#include "State.h"
#include "cutils_func.h"
FixLJCut::FixLJCut(SHARED(State) state_, string handle_, string groupHandle_) : FixPair(state_, handle_, groupHandle_, LJCutType, 1), epsHandle("eps"), sigHandle("sig") {
    initializeParameters(epsHandle, epsilons);
    initializeParameters(sigHandle, sigmas);
    forceSingle = true;

}



__global__ void compute_cu(int nAtoms, float4 *xs, float4 *fs, int *neighborCounts, uint *neighborlist, int *cumulSumMaxPerBlock, int warpSize, float *sigs, float *eps, int numTypes, float rCut, BoundsGPU bounds, float oneFourStrength) {
    float multipliers[4] = {1, 0, 0, oneFourStrength};
    extern __shared__ float paramsAll[];
    int sqrSize = numTypes*numTypes;
    float *sigs_shr = paramsAll;
    float *eps_shr = paramsAll + sqrSize;
    //TWO THINGS - FIRST, MAKE IT SO YOU DON'T DO STRIDED MEMORY ACCESS.  DO BLOCK-SIZE CHUNKS INSTED, THEN iT'S SEQUENTIAL. SECOND, GENERALIZE THIS OPERATION.  USE blockDim.x, NOT PERBLOCK FOR STRIDE SIZE WHEN DOING BLOCK CHUNKS
    copyToShared<float>(eps, eps_shr, sqrSize);
    copyToShared<float>(eps, sigs_shr, sqrSize);
    __syncthreads();

    int idx = GETIDX();
    if (idx < nAtoms) {
        int baseIdx = baseNeighlistIdx<void>(cumulSumMaxPerBlock, warpSize);
        float4 posWhole = xs[idx];
        int type = * (int *) &posWhole.w;
       // printf("type is %d\n", type);
        float3 pos = make_float3(posWhole);

        float3 forceSum = make_float3(0, 0, 0);

        int numNeigh = neighborCounts[idx];
        //printf("start, end %d %d\n", start, end);
        for (int i=0; i<numNeigh; i++) {
            int nlistIdx = baseIdx + warpSize * i;
            uint otherIdxRaw = neighborlist[nlistIdx];
            uint neighDist = otherIdxRaw >> 30;
            uint otherIdx = otherIdxRaw & EXCL_MASK;
            float4 otherPosWhole = xs[otherIdx];
            int otherType = * (int *) &otherPosWhole.w;
            float3 otherPos = make_float3(otherPosWhole);
            //then wrap and compute forces!
            float sig = squareVectorItem(sigs_shr, numTypes, type, otherType);
            float eps = squareVectorItem(eps_shr, numTypes, type, otherType);
            float3 dr = bounds.minImage(pos - otherPos);
            float lenSqr = lengthSqr(dr);
         //   printf("dist is %f %f %f\n", dr.x, dr.y, dr.z);
            if (lenSqr < rCut*rCut) {
                float multiplier = multipliers[neighDist];
               // printf("mult is %f between idxs %d %d\n", multiplier, idx, otherIdx);
                float sig6 = powf(sig, 6);//compiler should optimize this 
                float p1 = eps*48*sig6*sig6;
                float p2 = eps*24*sig6;
                float r2inv = 1/lenSqr;
                float r6inv = r2inv*r2inv*r2inv;
                double forceScalar = r6inv * r2inv * (p1 * r6inv - p2) * multiplier;

                float3 forceVec = dr * forceScalar;
                forceSum += forceVec;
            }

        }   
        //printf("force %f %f %f with %d atoms \n", forceSum.x, forceSum.y, forceSum.z, end-start);
        fs[idx] += forceSum;

    }


//__host__ __device__ T squareVectorItem(T *vals, int nCol, int i, int j) {

}

//__global__ void compute_cu(int nAtoms, cudaTextureObject_t xs, float4 *fs, int *neighborIdxs, cudaTextureObject_t neighborlist, float *sigs, float *eps, cudaTextureObject_t types, int numTypes, float rCut, BoundsGPU bounds) {
void FixLJCut::compute() {
    int nAtoms = state->atoms.size();
    int numTypes = state->atomParams.numTypes;
    GPUData &gpd = state->gpd;
    GridGPU &grid = state->gridGPU;
    int activeIdx = gpd.activeIdx;
    int *neighborCounts = grid.perAtomArray.d_data.ptr;
    double oneFourStrength = 0.5;

    compute_cu<<<NBLOCK(nAtoms), PERBLOCK, 2*numTypes*numTypes*sizeof(float)>>>(nAtoms, gpd.xs(activeIdx), gpd.fs(activeIdx), neighborCounts, grid.neighborlist.ptr, grid.perBlockArray.d_data.ptr, state->devManager.prop.warpSize, sigmas.getDevData(), epsilons.getDevData(), numTypes, state->rCut, state->boundsGPU, oneFourStrength);



}

bool FixLJCut::prepareForRun() {
    //loop through all params and fill with appropriate lambda function, then send all to device
    auto fillEps = [] (float a, float b) {
        return sqrt(a*b);
    };
    auto fillSig = [] (float a, float b) {
        return (a+b) / 2.0;
    };
    prepareParameters(epsilons, fillEps);
    prepareParameters(sigmas, fillSig);
    sendAllToDevice();
    return true;
}

string FixLJCut::restartChunk(string format) {
    //test this
    stringstream ss;
    ss << "<" << restartHandle << ">\n";
    ss << restartChunkPairParams(format);
    ss << "</" << restartHandle << ">\n";
    return ss.str();
}

bool FixLJCut::readFromRestart(pugi::xml_node restData) {
    
    vector<float> epsilons_raw = xml_readNums<float>(restData, epsHandle);
    epsilons.set(epsilons_raw);
    initializeParameters(epsHandle, epsilons);
    vector<float> sigmas_raw = xml_readNums<float>(restData, sigHandle);
    sigmas.set(sigmas_raw);
    initializeParameters(sigHandle, sigmas);
    return true;

}

void FixLJCut::addSpecies(string handle) {
    initializeParameters(epsHandle, epsilons);
    initializeParameters(sigHandle, sigmas);
}

void export_FixLJCut() {
    class_<FixLJCut, SHARED(FixLJCut), bases<Fix> > ("FixLJCut", init<SHARED(State), string, string> (args("state", "handle", "groupHandle")))
        .def("setParameter", &FixLJCut::setParameter, (python::arg("param"), python::arg("handleA"), python::arg("handleB"), python::arg("val")))
        ;
}
