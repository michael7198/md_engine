#pragma once
#ifndef GPUARRAYDEVICE_H
#define GPUARRAYDEVICE_H

/*! \brief Base class for GPUArrayDevices
 *
 * A GPUArrayDevice is a memory-managed pointer for storgage on the GPU. It is
 * mainly used by the GPUArray which manages the GPU memory and takes care of
 * sending data from CPU to GPU and back.
 *
 * This class is a Base class defining the function common to all memory
 * operations on the GPU. The child classes differ in which type of memory
 * they store the data: Global memory or Texture memory. Not yet
 * used/implemented is memory stored to Constant memory or Local memory.
 */
class GPUArrayDevice {
protected:
    /*! \brief Constructor
     *
     * \param size Size of the array
     */
    GPUArrayDevice(size_t size = 0) : n(size) {}

public:
    /*! \brief Destructor */
    virtual ~GPUArrayDevice() = default;

    size_t size() const { return n; }

protected:
    size_t n; //!< Number of elements stored in the array
};

#endif

