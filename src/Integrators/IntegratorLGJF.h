#pragma once
#ifndef INTEGRATORLGJF_H
#define INTEGRATORLGJF_H

#include "Integrator.h"
#include "globalDefs.h"
#include "GPUArrayDeviceGlobal.h"

#include <curand_kernel.h>
//! Make the Integrator accessible to the Python interface
void export_IntegratorLGJF();

//! Gronbech-Jensen Farago -style Langevin integrator
/*!
 * This class implements a Langevin integration scheme
 * as described by Farago and Gronbech-Jensen 
 * Mol. Phys. 111 (8), 983-991, 2013
 * 
 */


//
//
//
// This integrator not to be used with langevin fixes or velocity-dependent fixes
//
//
//
class IntegratorLGJF : public Integrator
{
public:
    double temp;
    double alpha = 0.0;
    int seed;
    float scaleFactor;

    GPUArrayDeviceGlobal<curandState_t> randStates;
    //! Constructor
    /*!
     * \param statePtr Pointer to the simulation state
     * temperature temp in units of (k_b)*T
     * friction coefficient alpha, 
     * integer seed for the random number generator
     */
    IntegratorLGJF(State *statePtr,double temp_, double alpha_, int seed_) ; 
    IntegratorLGJF(State *statePtr,double temp_);
    //! Run the Integrator
    /*!
     * \param numTurns Number of steps to run
     */
    virtual void run(int numTurns);

    
private:
    //! Run first half-integration
    /*!
     * The G-JF Langevin integration scheme updates the positions and velocities
     * in tandem; however, the positions at step n+1 require information only from 
     * step n, wherease the velocities as step n+1 require information from both 
     * step n and n+1; therefore, in the preforce, we use the information at step n
     * to completely update the positions and to partially update the velocities. 
     * We can then compute the forces in the postforce() routine to complete the process
     * such that the velocities and positions are again in step with each other,
     * and the cycle is complete
     */
    void preForce();
    //
    //! Run second half-integration step
    /*!
     * \param index Active index of GPUArrayPairs
     * Here, we use information of the positions and the forces at step n+1 to 
     * update the velocities to also be at step n+1
     */
    void postForce();

};

#endif
