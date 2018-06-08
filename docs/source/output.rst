Output Files
============

Statistics
----------

All output statistics are stored in NetCDF format in the file `stats/Stats.CASE_NAME.nc`, where `CASE_NAME` is the name of the simulated case. 

Profiles
++++++++

Contains the vertical profile of horizontally-averaged variables at every output timestep: `var = var(t, z)`

**u_mean** : :math:`\bar{\tilde{u}} = \bar{\tilde{u}}(t, z)`
	x-axis component of the mean filtered velocity.

**v_mean** : :math:`\bar{\tilde{v}} = \bar{\tilde{v}}(t, z)`
	y-axis component of the mean filtered velocity.

**w_mean** : :math:`\bar{\tilde{w}} = \bar{\tilde{w}}(t, z)`
	z-axis (i.e. vertical) component of the mean filtered velocity.

**u_mean2** : :math:`\overline{{\tilde{u}}^2} = \overline{\tilde{u}\tilde{u}}(t, z)` 
	Second moment of the x-axis component of the filtered velocity.

**v_mean2** : :math:`\overline{{\tilde{v}}^2} = \overline{\tilde{v}\tilde{v}}(t, z)` 
	Second moment of the x-axis component of the filtered velocity.

**w_mean2** : :math:`\overline{{\tilde{w}}^2} = \overline{\tilde{w}\tilde{w}}(t, z)` 
	Second moment of the y-axis component of the filtered velocity.

**u_mean3** : :math:`\overline{{\tilde{u}}^3} = \overline{\tilde{u}\tilde{u}\tilde{u}}(t, z)` 
	Third moment of the x-axis component of the filtered velocity.

**v_mean3** : :math:`\overline{{\tilde{v}}^3} = \overline{\tilde{v}\tilde{v}\tilde{v}}(t, z)` 
	Third moment of the y-axis component of the filtered velocity.

**w_mean3** : :math:`\overline{{\tilde{w}}^3} = \overline{\tilde{w}\tilde{w}\tilde{w}}(t, z)` 
	Third moment of the z-axis component of the filtered velocity.

**tke_nd_mean** : :math:`\bar{\tilde{e}} = \dfrac{1}{2}\overline{\tilde{u'_i}\tilde{u'_i}}(t, z)`
	Nondimensional turbulence kinetic energy of the filtered fields (resolved TKE).

**tke_mean** : :math:`\bar{\tilde{e_m}} = \dfrac{1}{2}\rho\overline{\tilde{u'_i}\tilde{u'_i}}(t, z)`
	Turbulence kinetic energy of the filtered fields (resolved TKE).

**e_mean** : :math:`\bar{e}_{sgs} = \bar{e}_{sgs}(t, z)`
	Nondimensional subgrid-scale turbulence kinetic energy, prognostic variable in the 1.5-order TKE SGS closure.



