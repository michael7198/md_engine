Simulation State
====================

Overview
^^^^^^^^

The ``State`` class holds all data pertaining to a given simulation.  This includes atoms, connectivity information, simulation box size, thermodynamic information, recorded data, and more.  ``State`` has many member variables and functions which help you to prepare your simulation for running.  

Basic Usage
^^^^^^^^^^^

The following is an example which shows basic preparation of the simulation state with detailed explanation of each command

.. code-block:: python

    #Initializing the simulation state variable 
    state = State()

    #Set simulation box 
    #Vector is a DASH-specific class which allows for easy vector math
    state.bounds = Bounds(state, lo=Vector(0, 0, 0), hi=Vector(20, 20, 20))

    #The box can be changed at any time
    state.bounds.lo = Vector(-10, -10, 0)

    #Now add a new atom type - atomParams stores atom type information
    state.atomParams.addSpecies(handle='species1', mass=1)

    #Now we create a fix to apply Lennard-Jones forces
    #the fix gets a handle (name), which is useful for restarting simulations
    nonbond = FixLJCut(state, handle='myLJCut')

    #sets species1-species1 sigma and epsilon to 0.5 and 2, respectively
    nonbond.setParameter('sig', 'species1', 'species1', 0.5)
    nonbond.setParameter('eps', 'species1', 'species1', 2)

    #turn on the fix
    state.activateFix(nonbond)

    #create some atoms on a lattice
    lo = state.bounds.lo
    hi = state.bounds.hi
    for x in range(lo[0], hi[0]):
        for y in range(lo[1], hi[1]):
            for z in range(lo[2], hi[2]):
                state.addAtom(handle='species1', pos=Vector(x, y, z)) 

    #give the atoms a temperature
    InitializeAtoms.initTemp(groupHandle='all', temp=1.0)

    #create a Nose-Hoover thermostat
    #other 
    fixNVT = FixNoseHoover(state, handle='myThermostat', groupHandle='all', temp=1.0, timeConstant=0.5)

    #then activate it like other fixes
    state.activateFix(fixNVT)
    
    #create an integrator - this is a standard langevin integrator, 
    #though other options are available.

    integrator = IntegratorVerlet(state)

    #set the timestep
    state.dt = 0.005
    #run for 10000 turns
    integrator.run(10000)


Python Member Functions
^^^^^^^^^^^^^^^^^^^^^^^

**Adding and removing atoms**


.. code-block:: python
    
    state.addAtom(handle='...', pos=Vector(...), q=0)

``handle``
    Species handle 

``pos``
    Position of atom

``q``
    Charge of atom

.. code-block:: python
    
    anAtom = state.atoms[3]
    #deletes all bonds, dihedrals, etc as well
    state.deleteAtom(anAtom)

:doc:`Initialize Atoms</initialize-atoms>` also provides tools for initializing groups of atoms.

**Creating groups of atoms**

.. code-block:: python

    state.createGroup(handle='...' atoms=[...])

``handle``
    Name of group

``atoms``
    List of atom ids to be in group.  Optional argument

.. code-block:: python

    state.addToGroup(handle='...' atoms=[...])

``handle``
    Name of group

``atoms``
    List of atom ids to be in group.  Optional argument

.. code-block:: python

    state.deleteGroup(handle='...')


``handle``
    Name of group to delete

One can easily select all atoms in a group as follows:

.. code-block:: python

    atomsInGroup = [a for a in state.atoms if state.atomInGroup(a, 'myGroup')]
    
**Creating molecules**

:doc:`Molecules</molecule>` are a tool for duplicating and manipulating groups of atoms.  Molecules are particularly useful for initializing systems. 

.. code-block:: python

    #assigns atoms to a molecule
    molec = state.createMolecule(ids=[...])
    #create a complete copy of the molecule including bonds, angles, etc.
    duplicate = state.duplicateMolecule(molec)
    #move the molecule by x=10
    duplicate.translate(Vector(10, 0, 0))
    #rotate the molecule by pi around the axis (1, 0, 0)
    duplicate.rotate(Vector(1, 0, 0), pi)

Creating a molecule groups already-existing atoms into a molecule.  This molecule can then be duplicated, translated, and rotated.  Molecules can be accessed through the ``state.molecules`` member, which is a python list.  

.. code-block:: python

    state.deleteAtom(molec)

Deleting molecules, on the other hand, deletes the member atoms and all associated bonds, angles, etc.


**Setting special neighbor coefficients**

Most force fields scale down forces for atoms which are topologically nearby.  The 1-2, 1-3, and 1-4 neighbor coefficients can be set as follows:

.. code-block:: python
    #1-2, 1-3, 1-4 neighbor coefficients
    state.setSpecialNeighborCoefs(0, 0, 0.5)

*Note*: When using the :doc:'CHARMM</ljcharmm>' potential, the 1-4 coefficient must be different than 1-2 and 1-3.

**Activating fixes**

.. code-block:: python
    
    #turns on the fix
    state.activateFix(myFix)    

    #turns off the fix
    state.deactivateFix(myFix)    


**Activating configuration writers**

.. code-block:: python
    
    #turns on the writer
    state.activateWriteConfig(myWriter)    

    #turns off the writer
    state.deactivateWriteConfig(myWriter)    


**Activating python operations**

.. code-block:: python
    
    #turns on the python operation
    state.activatePythonOperation(myOp)    

    #turns off the writer
    state.deactivatePythonOperation(myOp)  

**Converting particle id to index**

.. code-block:: python
    
    currentIdx = state.idToIdx(id)
    atom = state.atoms[currentIdx]

**Setting periodicity**

.. code-block:: python

    #0, 1, 2 -> x, y, z
    state.setPeriodic(0, False)
    isPeriodicZ = state.getPeriodic(2)

Python members
^^^^^^^^^^^^^^

**Current turn**

.. code-block:: python

    turn = state.turn 
    #reset current turn to 0
    state.turn = 0

**Simulation timestep**

.. code-block:: python

    #Setting simulation timestep
    #This will be in femptoseconds or LJ time units
    #depending on the current units 
    state.dt = 2 

**Cutoff radius**

    Cutoff distance for non-bonded forces, except for charge forces which have their cutoff specially set

.. code-block:: python

    state.rCut = 10.0

**Neighborlist padding**

     Distant past ``rCut`` for which neighborlists are built.  This parameter can be manipulated to optimize performance.  Suggested values are ``0.5`` in Lennard-Jones units and ``2.0`` Angstroms in real units

.. code-block:: python

    state.padding = 2.0


    

