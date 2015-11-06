#!python
#cython: boundscheck=False
#cython: wraparound=False
#cython: initializedcheck=False
#cython: cdivision=True

cimport numpy as np
import numpy as np
cimport Grid
cimport Lookup
cimport PrognosticVariables
cimport DiagnosticVariables
cimport ReferenceState
cimport ParallelMPI
cimport TimeStepping
from NetCDFIO cimport NetCDFIO_Stats
from Thermodynamics cimport LatentHeat, ClausiusClapeyron
from libc.math cimport fmax, fmin


cdef extern from "scalar_advection.h":
    void compute_advective_fluxes_a(Grid.DimStruct *dims, double *rho0, double *rho0_half, double *velocity, double *scalar, double* flux, int d, int scheme) nogil

cdef class No_Microphysics_Dry:
    def __init__(self, ParallelMPI.ParallelMPI Par, LatentHeat LH, namelist):
        LH.Lambda_fp = lambda_constant
        LH.L_fp = latent_heat_constant
        self.thermodynamics_type = 'dry'
        return
    cpdef initialize(self, Grid.Grid Gr, PrognosticVariables.PrognosticVariables PV,DiagnosticVariables.DiagnosticVariables DV, NetCDFIO_Stats NS, ParallelMPI.ParallelMPI Pa):
        return
    cpdef update(self, Grid.Grid Gr, ReferenceState.ReferenceState Ref, PrognosticVariables.PrognosticVariables PV, DiagnosticVariables.DiagnosticVariables DV, TimeStepping.TimeStepping TS,ParallelMPI.ParallelMPI Pa):
        return
    cpdef stats_io(self, Grid.Grid Gr, ReferenceState.ReferenceState Ref, PrognosticVariables.PrognosticVariables PV, DiagnosticVariables.DiagnosticVariables DV, NetCDFIO_Stats NS, ParallelMPI.ParallelMPI Pa):
        return



cdef class No_Microphysics_SA:
    def __init__(self, ParallelMPI.ParallelMPI Par, LatentHeat LH, namelist):
        LH.Lambda_fp = lambda_constant
        LH.L_fp = latent_heat_constant
        self.thermodynamics_type = 'SA'
        return
    cpdef initialize(self, Grid.Grid Gr, PrognosticVariables.PrognosticVariables PV,DiagnosticVariables.DiagnosticVariables DV, NetCDFIO_Stats NS, ParallelMPI.ParallelMPI Pa):
        return
    cpdef update(self, Grid.Grid Gr, ReferenceState.ReferenceState Ref, PrognosticVariables.PrognosticVariables PV, DiagnosticVariables.DiagnosticVariables DV, TimeStepping.TimeStepping TS,ParallelMPI.ParallelMPI Pa):
        return
    cpdef stats_io(self, Grid.Grid Gr, ReferenceState.ReferenceState Ref, PrognosticVariables.PrognosticVariables PV, DiagnosticVariables.DiagnosticVariables DV, NetCDFIO_Stats NS, ParallelMPI.ParallelMPI Pa):
        return



cdef extern from "microphysics_sb.h":
    double sb_rain_shape_parameter_0(double density, double qr, double Dm) nogil
    double sb_rain_shape_parameter_1(double density, double qr, double Dm) nogil
    double sb_rain_shape_parameter_2(double density, double qr, double Dm) nogil
    double sb_rain_shape_parameter_4(double density, double qr, double Dm) nogil
    double sb_droplet_nu_0(double density, double ql) nogil
    double sb_droplet_nu_1(double density, double ql) nogil
    double sb_droplet_nu_2(double density, double ql) nogil
    void sb_sedimentation_velocity_rain(Grid.DimStruct *dims, double (*rain_mu)(double,double,double),
                                        double* density, double* nr, double* qr, double* nr_velocity, double* qr_velocity) nogil
    void sb_sedimentation_velocity_liquid(Grid.DimStruct *dims, double*  density, double ccn, double* ql, double* qt_velocity)nogil

    void sb_microphysics_sources(Grid.DimStruct *dims, Lookup.LookupStruct *LT, double (*lam_fp)(double), double (*L_fp)(double, double),
                             double (*rain_mu)(double,double,double), double (*droplet_nu)(double,double),
                             double* density, double* p0, double* temperature,  double* qt, double ccn,
                             double* ql, double* nr, double* qr, double dt, double* nr_tendency_micro, double* qr_tendency_micro,
                             double* nr_tendency, double* qr_tendency) nogil

    void sb_thermodynamics_sources(Grid.DimStruct *dims, Lookup.LookupStruct *LT, double (*lam_fp)(double),
                                   double (*L_fp)(double, double), double*  p0, double* temperature, double* qt,
                                   double*  ql,double* qr_tendency, double* qt_tendency, double * entropy_tendency) nogil

    void sb_autoconversion_rain_wrapper(Grid.DimStruct *dims,  double (*droplet_nu)(double,double), double* density,
                                        double ccn, double* ql, double* qr, double*  nr_tendency, double* qr_tendency) nogil

    void sb_accretion_rain_wrapper(Grid.DimStruct *dims, double* density, double*  ql, double* qr, double* qr_tendency)nogil

    void sb_selfcollection_breakup_rain_wrapper(Grid.DimStruct *dims, double (*rain_mu)(double,double,double),
                                            double* density, double* nr, double* qr, double*  nr_tendency)nogil

    void sb_evaporation_rain_wrapper(Grid.DimStruct *dims, Lookup.LookupStruct *LT, double (*lam_fp)(double), double (*L_fp)(double, double),
                             double (*rain_mu)(double,double,double),  double* density, double* p0,  double* temperature,  double* qt,
                             double* ql, double* nr, double* qr, double* nr_tendency, double* qr_tendency)nogil

    void compute_qt_sedimentation_s_source(Grid.DimStruct *dims, double *p0_half,  double* rho0_half, double *flux,
                                           double* qt, double* qv, double* T, double* tendency, double (*lam_fp)(double),
                                           double (*L_fp)(double, double), double dx, ssize_t d)nogil


cdef class Microphysics_SB_Liquid:
    def __init__(self, ParallelMPI.ParallelMPI Par, LatentHeat LH, namelist):
        # Create the appropriate linkages to the bulk thermodynamics
        LH.Lambda_fp = lambda_constant
        LH.L_fp = latent_heat_constant
        self.thermodynamics_type = 'SA'
        #also set local versions
        self.Lambda_fp = lambda_constant
        self.L_fp = latent_heat_constant
        self.CC = ClausiusClapeyron()
        self.CC.initialize(namelist, LH, Par)


        # Extract case-specific parameter values from the namelist
        # Get number concentration of cloud condensation nuclei (1/m^3)
        try:
            self.ccn = namelist['microphysics']['SB_Liquid']['ccn']
        except:
            self.ccn = 100.0e6
        # Set option for calculation of mu (distribution shape parameter)
        try:
            mu_opt = namelist['microphysics']['SB_Liquid']['mu_rain']
            if mu_opt == 1:
                self.compute_rain_shape_parameter = sb_rain_shape_parameter_1
            elif mu_opt == 2:
                self.compute_rain_shape_parameter = sb_rain_shape_parameter_2
            elif mu_opt == 4:
                self.compute_rain_shape_parameter = sb_rain_shape_parameter_4
            elif mu_opt == 0:
                self.compute_rain_shape_parameter  = sb_rain_shape_parameter_0
            else:
                Par.root_print("SB_Liquid mu_rain option not recognized, defaulting to option 1")
                self.compute_rain_shape_parameter = sb_rain_shape_parameter_1
        except:
            Par.root_print("SB_Liquid mu_rain option not selected, defaulting to option 1")
            self.compute_rain_shape_parameter = sb_rain_shape_parameter_1
        # Set option for calculation of nu parameter of droplet distribution
        try:
            nu_opt = namelist['microphysics']['SB_Liquid']['nu_droplet']
            if nu_opt == 0:
                self.compute_droplet_nu = sb_droplet_nu_0
            elif nu_opt == 1:
                self.compute_droplet_nu = sb_droplet_nu_1
            elif nu_opt ==2:
                self.compute_droplet_nu = sb_droplet_nu_2
            else:
                Par.root_print("SB_Liquid nu_droplet_option not recognized, defaulting to option 0")
                self.compute_droplet_nu = sb_droplet_nu_0
        except:
            Par.root_print("SB_Liquid nu_droplet_option not selected, defaulting to option 0")
            self.compute_droplet_nu = sb_droplet_nu_0

        try:
            self.order = namelist['scalar_transport']['order_sedimentation']
        except:
            self.order = namelist['scalar_transport']['order']

        try:
            self.cloud_sedimentation = namelist['microphysics']['SB_Liquid']['cloud_sedimentation']
        except:
            self.cloud_sedimentation = False

        return

    cpdef initialize(self, Grid.Grid Gr, PrognosticVariables.PrognosticVariables PV, DiagnosticVariables.DiagnosticVariables DV, NetCDFIO_Stats NS, ParallelMPI.ParallelMPI Pa):
        # add prognostic variables for mass and number of rain
        PV.add_variable('nr', '1/kg', 'sym','scalar',Pa)
        PV.add_variable('qr', 'kg/kg', 'sym','scalar',Pa)

        # add sedimentation velocities as diagnostic variables
        DV.add_variables('w_qr', 'm/s', 'sym', Pa)
        DV.add_variables('w_nr', 'm/s', 'sym', Pa)
        if self.cloud_sedimentation:
            DV.add_variables('w_qt', 'm/s', 'sym', Pa)
            NS.add_profile('qt_sedimentation_flux', Gr, Pa)
            NS.add_profile('s_qt_sedimentation_source',Gr,Pa)


        # add statistical output for the class
        NS.add_profile('qr_sedimentation_flux', Gr, Pa)
        NS.add_profile('nr_sedimentation_flux', Gr, Pa)
        NS.add_profile('qr_autoconversion', Gr, Pa)
        NS.add_profile('nr_autoconversion', Gr, Pa)
        NS.add_profile('s_autoconversion', Gr, Pa)
        NS.add_profile('nr_selfcollection', Gr, Pa)
        NS.add_profile('qr_accretion', Gr, Pa)
        NS.add_profile('s_accretion', Gr, Pa)
        NS.add_profile('nr_evaporation', Gr, Pa)
        NS.add_profile('qr_evaporation', Gr,Pa)
        NS.add_profile('s_evaporation', Gr,Pa)
        return

    cpdef update(self, Grid.Grid Gr, ReferenceState.ReferenceState Ref, PrognosticVariables.PrognosticVariables PV, DiagnosticVariables.DiagnosticVariables DV, TimeStepping.TimeStepping TS, ParallelMPI.ParallelMPI Pa):
        cdef:


            Py_ssize_t t_shift = DV.get_varshift(Gr, 'temperature')
            Py_ssize_t ql_shift = DV.get_varshift(Gr,'ql')
            Py_ssize_t nr_shift = PV.get_varshift(Gr, 'nr')
            Py_ssize_t qr_shift = PV.get_varshift(Gr, 'qr')
            Py_ssize_t qt_shift = PV.get_varshift(Gr, 'qt')
            Py_ssize_t w_shift = PV.get_varshift(Gr, 'w')
            double dt = TS.dt
            Py_ssize_t wqr_shift = DV.get_varshift(Gr, 'w_qr')
            Py_ssize_t wnr_shift = DV.get_varshift(Gr, 'w_nr')
            Py_ssize_t wqt_shift
            double[:] qr_tend_micro = np.zeros((Gr.dims.npg,), dtype=np.double, order='c')
            double[:] nr_tend_micro = np.zeros((Gr.dims.npg,), dtype=np.double, order='c')


        sb_microphysics_sources(&Gr.dims, &self.CC.LT.LookupStructC, self.Lambda_fp, self.L_fp, self.compute_rain_shape_parameter,
                                self.compute_droplet_nu, &Ref.rho0_half[0],  &Ref.p0_half[0], &DV.values[t_shift],
                                &PV.values[qt_shift], self.ccn, &DV.values[ql_shift], &PV.values[nr_shift],
                                &PV.values[qr_shift], dt, &nr_tend_micro[0], &qr_tend_micro[0], &PV.tendencies[nr_shift], &PV.tendencies[qr_shift] )


        sb_sedimentation_velocity_rain(&Gr.dims,self.compute_rain_shape_parameter,
                                       &Ref.rho0_half[0],&PV.values[nr_shift], &PV.values[qr_shift],
                                       &DV.values[wnr_shift], &DV.values[wqr_shift])
        if self.cloud_sedimentation:
            wqt_shift = DV.get_varshift(Gr, 'w_qt')
            sb_sedimentation_velocity_liquid(&Gr.dims,  &Ref.rho0_half[0], self.ccn, &DV.values[ql_shift], &DV.values[wqt_shift])



        # update the Boundary conditions and ghost cells of the sedimentation velocities
        # wnr_nv = DV.name_index['w_nr']
        # wqr_nv = DV.name_index['w_qr']
        # DV.communicate_variable(Gr,Pa,wnr_nv)
        # DV.communicate_variable(Gr,Pa,wqr_nv )



        cdef Py_ssize_t s_shift = PV.get_varshift(Gr, 's')
        sb_thermodynamics_sources(&Gr.dims, &self.CC.LT.LookupStructC, self.Lambda_fp, self.L_fp, &Ref.p0_half[0],
                                  &DV.values[t_shift], &PV.values[qt_shift], &DV.values[ql_shift], &qr_tend_micro[0],
                                  &PV.tendencies[qt_shift], &PV.tendencies[s_shift])


        return

    #
    cpdef stats_io(self, Grid.Grid Gr, ReferenceState.ReferenceState Ref, PrognosticVariables.PrognosticVariables PV, DiagnosticVariables.DiagnosticVariables DV, NetCDFIO_Stats NS, ParallelMPI.ParallelMPI Pa):
        cdef:
            Py_ssize_t i, j, k, ijk
            Py_ssize_t gw = Gr.dims.gw
            Py_ssize_t imax = Gr.dims.nlg[0]
            Py_ssize_t jmax = Gr.dims.nlg[1]
            Py_ssize_t kmax = Gr.dims.nlg[2]
            Py_ssize_t istride = Gr.dims.nlg[1] * Gr.dims.nlg[2]
            Py_ssize_t jstride = Gr.dims.nlg[2]
            Py_ssize_t ishift, jshift

            Py_ssize_t t_shift = DV.get_varshift(Gr, 'temperature')
            Py_ssize_t qv_shift = DV.get_varshift(Gr, 'qv')
            Py_ssize_t ql_shift = DV.get_varshift(Gr,'ql')
            Py_ssize_t nr_shift = PV.get_varshift(Gr, 'nr')
            Py_ssize_t qr_shift = PV.get_varshift(Gr, 'qr')
            Py_ssize_t qt_shift = PV.get_varshift(Gr, 'qt')

            double[:] qr_tendency = np.empty((Gr.dims.npg,), dtype=np.double, order='c')
            double[:] nr_tendency = np.empty((Gr.dims.npg,), dtype=np.double, order='c')
            double[:] tmp




            double[:] dummy =  np.zeros((Gr.dims.npg,), dtype=np.double, order='c')
            Py_ssize_t wqr_shift = DV.get_varshift(Gr, 'w_qr')
            Py_ssize_t wnr_shift = DV.get_varshift(Gr, 'w_nr')
            Py_ssize_t wqt_shift

        cdef double[:] s_src =  np.zeros((Gr.dims.npg,), dtype=np.double, order='c')
        if self.cloud_sedimentation:
            wqt_shift = DV.get_varshift(Gr,'w_qt')

            compute_advective_fluxes_a(&Gr.dims, &Ref.rho0[0], &Ref.rho0_half[0], &DV.values[wqt_shift], &PV.values[qt_shift], &dummy[0], 2, self.order)
            tmp = Pa.HorizontalMean(Gr, &dummy[0])
            NS.write_profile('qt_sedimentation_flux', tmp[gw:-gw], Pa)

            compute_qt_sedimentation_s_source(&Gr.dims, &Ref.p0_half[0], &Ref.rho0_half[0], &dummy[0],
                                    &PV.values[qt_shift], &DV.values[qv_shift],&DV.values[t_shift], &s_src[0], self.Lambda_fp,
                                    self.L_fp, Gr.dims.dx[2], 2)



        #compute sedimentation flux only of nr
        compute_advective_fluxes_a(&Gr.dims, &Ref.rho0[0], &Ref.rho0_half[0], &DV.values[wnr_shift], &PV.values[nr_shift], &dummy[0], 2, self.order)
        tmp = Pa.HorizontalMean(Gr, &dummy[0])
        NS.write_profile('nr_sedimentation_flux', tmp[gw:-gw], Pa)

        #compute sedimentation flux only of qr
        compute_advective_fluxes_a(&Gr.dims, &Ref.rho0[0], &Ref.rho0_half[0], &DV.values[wqr_shift], &PV.values[qr_shift], &dummy[0], 2, self.order)
        tmp = Pa.HorizontalMean(Gr, &dummy[0])
        NS.write_profile('qr_sedimentation_flux', tmp[gw:-gw], Pa)



        #note we can re-use nr_tendency and qr_tendency because they are overwritten in each function
        #must have a zero array to pass as entropy tendency and need to send a dummy variable for qt tendency

        # Autoconversion tendencies of qr, nr, s
        sb_autoconversion_rain_wrapper(&Gr.dims,  self.compute_droplet_nu, &Ref.rho0_half[0], self.ccn,
                                       &DV.values[ql_shift], &PV.values[qr_shift], &nr_tendency[0], &qr_tendency[0])
        tmp = Pa.HorizontalMean(Gr, &nr_tendency[0])
        NS.write_profile('nr_autoconversion', tmp[gw:-gw], Pa)
        tmp = Pa.HorizontalMean(Gr, &qr_tendency[0])
        NS.write_profile('qr_autoconversion', tmp[gw:-gw], Pa)
        cdef double[:] s_auto =  np.zeros((Gr.dims.npg,), dtype=np.double, order='c')
        sb_thermodynamics_sources(&Gr.dims, &self.CC.LT.LookupStructC, self.Lambda_fp, self.L_fp, &Ref.p0_half[0],
                                  &DV.values[t_shift], &PV.values[qt_shift], &DV.values[ql_shift], &qr_tendency[0],
                                  &dummy[0], &s_auto[0])

        tmp = Pa.HorizontalMean(Gr, &s_auto[0])
        NS.write_profile('s_autoconversion', tmp[gw:-gw], Pa)


        # Accretion tendencies of qr, s
        sb_accretion_rain_wrapper(&Gr.dims, &Ref.rho0_half[0], &DV.values[ql_shift], &PV.values[qr_shift], &qr_tendency[0])
        tmp = Pa.HorizontalMean(Gr, &qr_tendency[0])
        NS.write_profile('qr_accretion', tmp[gw:-gw], Pa)
        cdef double[:] s_accr =  np.zeros((Gr.dims.npg,), dtype=np.double, order='c')
        sb_thermodynamics_sources(&Gr.dims, &self.CC.LT.LookupStructC, self.Lambda_fp, self.L_fp, &Ref.p0_half[0],
                                  &DV.values[t_shift], &PV.values[qt_shift], &DV.values[ql_shift], &qr_tendency[0],
                                  &dummy[0], &s_accr[0])
        tmp = Pa.HorizontalMean(Gr, &s_accr[0])
        NS.write_profile('s_accretion', tmp[gw:-gw], Pa)

        # Self-collection and breakup tendencies (lumped) of nr
        sb_selfcollection_breakup_rain_wrapper(&Gr.dims, self.compute_rain_shape_parameter, &Ref.rho0_half[0],
                                               &PV.values[nr_shift], &PV.values[qr_shift], &nr_tendency[0])
        tmp = Pa.HorizontalMean(Gr, &nr_tendency[0])
        NS.write_profile('nr_selfcollection', tmp[gw:-gw], Pa)

        # Evaporation tendencies of qr, nr, s
        sb_evaporation_rain_wrapper(&Gr.dims, &self.CC.LT.LookupStructC, self.Lambda_fp, self.L_fp,
                                    self.compute_rain_shape_parameter, &Ref.rho0_half[0], &Ref.p0_half[0],
                                    &DV.values[t_shift], &PV.values[qt_shift], &DV.values[ql_shift],
                                    &PV.values[nr_shift], &PV.values[qr_shift], &nr_tendency[0], &qr_tendency[0])

        tmp = Pa.HorizontalMean(Gr, &nr_tendency[0])
        NS.write_profile('nr_evaporation', tmp[gw:-gw], Pa)
        tmp = Pa.HorizontalMean(Gr, &qr_tendency[0])
        NS.write_profile('qr_evaporation', tmp[gw:-gw], Pa)
        cdef double[:] s_evp =  np.zeros((Gr.dims.npg,), dtype=np.double, order='c')
        sb_thermodynamics_sources(&Gr.dims, &self.CC.LT.LookupStructC, self.Lambda_fp, self.L_fp, &Ref.p0_half[0],
                                  &DV.values[t_shift], &PV.values[qt_shift], &DV.values[ql_shift], &qr_tendency[0],
                                  &dummy[0], &s_evp[0])
        tmp = Pa.HorizontalMean(Gr, &s_evp[0])
        NS.write_profile('s_evaporation', tmp[gw:-gw], Pa)

        return



def MicrophysicsFactory(namelist, LatentHeat LH, ParallelMPI.ParallelMPI Par):
    if(namelist['microphysics']['scheme'] == 'None_Dry'):
        return No_Microphysics_Dry(Par, LH, namelist)
    elif(namelist['microphysics']['scheme'] == 'None_SA'):
        return No_Microphysics_SA(Par, LH, namelist)
    elif(namelist['microphysics']['scheme'] == 'SB_Liquid'):
        return Microphysics_SB_Liquid(Par, LH, namelist)
