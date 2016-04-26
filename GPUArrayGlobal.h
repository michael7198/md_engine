#pragma once
#ifndef GPUARRAYGLOBAL_H
#define GPUARRAYGLOBAL_H

#include <vector>

#include "GPUArray.h"
#include "GPUArrayDeviceGlobal.h"

/*! \class GPUArray
 * \brief Array storing data on the CPU and the GPU
 *
 * \tparam T Data type stored in the array
 *
 * GPU array stores data on the host CPU and the GPU device and is able to
 * move the data from the CPU to the GPU and back again.
 */
template <typename T>
class GPUArrayGlobal : public GPUArray {

public:
    /*! \brief Constructor
     *
     * Constructor creating empty host CPU data vector.
     */
    GPUArrayGlobal() {}

    /*! \brief Constructor
     *
     * \param size_ Size (number of elements) on the CPU and GPU data array
     *
     * Constructor creating empty arrays of the specified size on the CPU
     * and the GPU.
     */
    explicit GPUArrayGlobal(int size_)
        : h_data(std::vector<T>(size_,T())), d_data(GPUArrayDeviceGlobal<T>(size_)) {}

    /*! \brief Constructor
     *
     * \param vals Vector to be passed to the CPU array
     *
     * Constructor setting the CPU data array with the specified vector.
     */
    explicit GPUArrayGlobal(std::vector<T> &vals) {
        set(vals);
        d_data = GPUArrayDeviceGlobal<T>(vals.size());
    }

    /*! \brief Set CPU data
     *
     * \param other Vector containing new data
     *
     * Set the CPU data to to data specified in the given vector.
     */
    void set(std::vector<T> &other) {
        if (other.size() > size()) {
            d_data = GPUArrayDeviceGlobal<T>(other.size());
        }
        h_data = other;

    }

    /*! \brief Return size of data array */
    size_t size() const { return h_data.size(); }

    /*! \brief Ensure that the GPU data array is large enough */
    void ensureSize() {
        if (h_data.size() > d_data.size()) {
            d_data = GPUArrayDeviceGlobal<T>(size());
        }
    }

    /*! \brief Send data from CPU to GPU */
    void dataToDevice() {
        d_data.set(h_data.data());
    }

    /*! \brief Send data from GPU to CPU asynchronously */
    void dataToHostAsync(cudaStream_t stream) {
        d_data.get(h_data.data(), stream);
    }

    /*! \brief Send data from GPU to CPU synchronously */
    void dataToHost() {
        //eeh, want to deal with the case where data originates on the device,
        //which is a real case, so removed checked on whether data is on device
        //or not
        d_data.get(h_data.data());
    }

    /*! \brief Copy data to GPU array */
    void copyToDeviceArray(void *dest) {
        d_data.copyToDeviceArray(dest);
    }

    /*! \brief Return pointer to GPU data array */
    T *getDevData() {
        return d_data.data();
    }

    /*! \brief Set Memory by value */
    void memsetByVal(T val) {
        d_data.memsetByVal(val);
    }

public:

    std::vector<T> h_data; //!< Array storing data on the CPU
    GPUArrayDeviceGlobal<T> d_data; //!< Array storing data on the GPU
};

#endif