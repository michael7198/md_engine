import sys
import os
import matplotlib.pyplot as plt

# relative path to /build/ dir
sys.path = sys.path + ['../build/python/build/lib.linux-x86_64-2.7']
sys.path.append('../util_py')

from DASH import *
import water
from water import *
import math
import numpy as np

state = State()
state.deviceManager.setDevice(0)

##############################
# Set initial density here
##############################
numMolecules = 512
sideLength = 27.0
numTurnsEquil = 500
numTurnsProd = 500
loVector = Vector(0,0,0)
hiVector = Vector(sideLength, sideLength, sideLength)

state.units.setReal()

state.bounds = Bounds(state, lo = loVector, hi = hiVector)
state.rCut = 9.0
state.padding = 1.0
state.periodicInterval = 3
state.shoutEvery = 100
state.dt = 1.0


##############################################
# PIMD parameters - as from examples from Mike
##############################################
nBeads = 32;
the_temp = 300.0;
the_temp *= nBeads

# handles for our atoms
oxygenHandle = 'OW'
hydrogenHandle = 'HY'
mSiteHandle = 'M'

# add our oxygen and hydrogen species to the simulation
state.atomParams.addSpecies(handle=oxygenHandle, mass=15.9994, atomicNum=8)
state.atomParams.addSpecies(handle=hydrogenHandle, mass=1.008, atomicNum=1)

##############################################################
# TIP3P parameters
##############################################################
epsilon = 0.1521 # given in kcal/mol
sigma = 3.5365 # given in Angstroms

######################
# LJ Interactions
######################
nonbond = FixLJCut(state,'cut')
nonbond.setParameter('sig',oxygenHandle, oxygenHandle, sigma)
nonbond.setParameter('eps',oxygenHandle, oxygenHandle, epsilon)
nonbond.setParameter('sig',hydrogenHandle, hydrogenHandle, 0.0)
nonbond.setParameter('eps',hydrogenHandle, hydrogenHandle, 0.0)
nonbond.setParameter('sig',oxygenHandle, hydrogenHandle, 0.0)
nonbond.setParameter('eps',oxygenHandle, hydrogenHandle, 0.0)


#############################################################
# and also, for now an arbitrary harmonic bond potential
# just so things don't explode.
#############################################################
#harmonicBonds = FixBondHarmonic(state,'harmonic')
#harmonicAngle = FixAngleHarmonic(state,'angleH')

#state.activateFix(harmonicBonds)
#state.activateFix(harmonicAngle)

rigid = FixRigid(state,'rigid','all')

# our vector of centers
positions = []

xyzrange = int(math.ceil(numMolecules**(1.0/3.0)))
xyzFloat = float(xyzrange)
for x in xrange(xyzrange):
    for y in xrange(xyzrange):
        for z in xrange(xyzrange):
            pos = Vector( float(x)/(xyzFloat)*(0.9*sideLength) + 0.05*sideLength,
                          float(y)/(xyzFloat)*(0.9*sideLength) + 0.05*sideLength,
                          float(z)/(xyzFloat)*(0.9*sideLength) + 0.05*sideLength)

            #print pos
            positions.append(pos)

velocities = Vector(0.02, 0.02, 0.02)

# create the molecules, and add them to the FixFlexibleTIP4P fix
for i in range(numMolecules):
    center = positions[i]

    ## for TIP4P
   # molecule = create_TIP3P(state,oxygenHandle,hydrogenHandle,mSiteHandle,center,"random")

    molecule = create_TIP3P(state,oxygenHandle,hydrogenHandle,bondLength=0.9572,center=center,orientation="random")
    ids = []
    for atomId in molecule.ids:
        #state.atoms[atomId].vel = velocities
        #state.atoms[atomId].force= Vector(0,0,0)
        ids.append(atomId)

    velocities *= -1.0

    # make a harmonic OH1 bond with some high stiffness, and OH2, and H1H2
    '''
    harmonicBonds.createBond(state.atoms[ids[0]], state.atoms[ids[1]],
                             k=200, r0 = 0.9572)
    harmonicBonds.createBond(state.atoms[ids[0]], state.atoms[ids[2]],
                             k=200, r0 = 0.9572)
    harmonicAngle.createAngle(state.atoms[ids[1]], state.atoms[ids[0]], state.atoms[ids[2]],
                              k=200, theta0=1.82421813)
    '''
    rigid.createRigid(ids[0], ids[1], ids[2])


print 'done adding molecules to simulation'

#############################################################
# Initialization of potentials
#############################################################

#####################
# Charge interactions
#####################
charge = FixChargeEwald(state, 'charge', 'all')
charge.setParameters(128,state.rCut-1, 3)
state.activateFix(charge)

#####################
# LJ Interactions
#####################
# -- we defined the LJ interactions above
state.activateFix(nonbond)

#############################################
# Rigid Fix
#############################################
state.activateFix(rigid)

#############################################
# initialize at some temperature
#############################################
InitializeAtoms.initTemp(state, 'all', 350.0)

#############################################
# Temperature control
#############################################
#fixNVT = FixNoseHoover(state,'nvt','all')
#fixNVT.setTemperature(300.0, 100*state.dt)
#state.activateFix(fixNVT)

fixNVT = FixNVTRescale(state,'nvt','all',350,100)
state.activateFix(fixNVT)
########################################
# our integrator
########################################
integVerlet = IntegratorVerlet(state)

########################################
# Data recording
########################################
#tempData = state.dataManager.recordTemperature('all','vector', interval = 1)
#enerData = state.dataManager.recordEnergy('all', interval = 1)

tempData = state.dataManager.recordTemperature('all','vector', interval = 1)
enerData = state.dataManager.recordEnergy('all', 'scalar', interval = 1, fixes = [nonbond,charge] )
comvData = state.dataManager.recordCOMV(interval=1)

#################################
# and some calls to PIMD
#################################
#state.nPerRingPoly = nBeads
#state.preparePIMD(the_temp)

writer = WriteConfig(state, handle='writer', fn='rigid_tip3p', format='xyz',
                     writeEvery=5)
state.activateWriteConfig(writer)

integVerlet.run(numTurnsEquil)
#print dir(tempData)
#print sum(tempData.vals[0])
state.deactivateFix(fixNVT)
integVerlet.run(numTurnsProd)

for index, item in enumerate(enerData.vals):
    print enerData.vals[index], sum(tempData.vals[index]), enerData.vals[index] + sum(tempData.vals[index])

#state.deactivateFix(fixNVT)

integVerlet.run(numTurnsProd)

for index, item in enumerate(enerData.vals):
    print enerData.vals[index], sum(tempData.vals[index]), enerData.vals[index] + sum(tempData.vals[index])

print "now printing COMV data\n"
for index, item in enumerate(comvData.vals):
    print item[0], "  ", item[1], "  ", item[2], "   ", item[3]

print "END printing COMV data\n"
fid = open('thermo.dat', "w")

for t, T in zip(tempData.turns, tempData.vals):
    fid.write("{:<8}{:>15.5f}\n".format(t,sum(T)))
