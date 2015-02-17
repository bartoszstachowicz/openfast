!**********************************************************************************************************************************
! $Id: InflowWind.f90 125 2014-10-29 22:28:35Z aplatt $
!
! This module is used to read and process the (undisturbed) inflow winds.  It must be initialized
! using InflowWind_Init() with the name of the file, the file type, and possibly reference height and
! width (depending on the type of wind file being used).  This module calls appropriate routines
! in the wind modules so that the type of wind becomes seamless to the user.  InflowWind_End()
! should be called when the program has finshed.
!
! Data are assumed to be in units of meters and seconds.  Z is measured from the ground (NOT the hub!).
!
!  7 Oct 2009    Initial Release with AeroDyn 13.00.00         B. Jonkman, NREL/NWTC
! 14 Nov 2011    v1.00.01b-bjj                                 B. Jonkman
!  1 Aug 2012    v1.01.00a-bjj                                 B. Jonkman
! 10 Aug 2012    v1.01.00b-bjj                                 B. Jonkman
!    Feb 2013    v2.00.00a-adp   conversion to Framework       A. Platt
!
!..................................................................................................................................
! Files with this module:
!!!!!  InflowWind_Subs.f90
!  InflowWind.txt       -- InflowWind_Types will be auto-generated based on the descriptions found in this file.
!**********************************************************************************************************************************
! LICENSING
! Copyright (C) 2013  National Renewable Energy Laboratory
!
!    This file is part of InflowWind.
!
! Licensed under the Apache License, Version 2.0 (the "License");
! you may not use this file except in compliance with the License.
! You may obtain a copy of the License at
!
!     http://www.apache.org/licenses/LICENSE-2.0
!
! Unless required by applicable law or agreed to in writing, software
! distributed under the License is distributed on an "AS IS" BASIS,
! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
! See the License for the specific language governing permissions and
! limitations under the License.
!
!**********************************************************************************************************************************
! File last committed: $Date: 2014-10-29 16:28:35 -0600 (Wed, 29 Oct 2014) $
! (File) Revision #: $Rev: 125 $
! URL: $HeadURL$
!**********************************************************************************************************************************
MODULE InflowWind


   USE                              InflowWind_Types
   USE                              NWTC_Library

      !-------------------------------------------------------------------------------------------------
      ! The included wind modules
      !-------------------------------------------------------------------------------------------------

   USE                              IfW_UniformWind_Types      ! Types for IfW_UniformWind
   USE                              IfW_UniformWind            ! uniform wind files (text)
!!!   USE                              IfW_FFWind_Types           ! Types for IfW_FFWind
!!!   USE                              IfW_FFWind                 ! full-field binary wind files
!!!   USE                              HAWCWind                   ! full-field binary wind files in HAWC format
!!!   USE                              FDWind                     ! 4-D binary wind files
!!!   USE                              CTWind                     ! coherent turbulence from KH billow - binary file superimposed on another wind type
!!!   USE                              UserWind                   ! user-defined wind module




   IMPLICIT NONE
   PRIVATE

   TYPE(ProgDesc), PARAMETER            :: IfW_Ver = ProgDesc( 'InflowWind', 'v3.00.01a-adp', '01-Nov-2014' )



      ! ..... Public Subroutines ...................................................................................................

   PUBLIC :: InflowWind_Init                                   !< Initialization routine
   PUBLIC :: InflowWind_CalcOutput                             !< Calculate the wind velocities
   PUBLIC :: InflowWind_End                                    !< Ending routine (includes clean up)

   PUBLIC :: WindInf_ADhack_diskVel

      ! These routines satisfy the framework, but do nothing at present.
   PUBLIC :: InflowWind_UpdateStates                           !< Loose coupling routine for solving for constraint states, integrating continuous states, and updating discrete states
   PUBLIC :: InflowWind_CalcConstrStateResidual                !< Tight coupling routine for returning the constraint state residual
   PUBLIC :: InflowWind_CalcContStateDeriv                     !< Tight coupling routine for computing derivatives of continuous states
   PUBLIC :: InflowWind_UpdateDiscState                        !< Tight coupling routine for updating discrete states


      ! Not coded
   !NOTE: Jacobians have not been coded.



CONTAINS
!====================================================================================================
!> This routine is called at the start of the simulation to perform initialization steps.
!! The parameters are set here and not changed during the simulation.
!! The initial states and initial guess for the input are defined.
!! Since this module acts as an interface to other modules, on some things are set before initiating
!! calls to the lower modules.
!----------------------------------------------------------------------------------------------------
SUBROUTINE InflowWind_Init( InitData,   u,    ParamData,                   &
                     ContStates, DiscStates,    ConstrStateGuess,    OtherStates,   &
                     OutData,    TimeInterval,  InitOutData,                        &
                     ErrStat,    ErrMsg )



         ! Initialization data and guesses

      TYPE(InflowWind_InitInputType),        INTENT(IN   )  :: InitData          !< Input data for initialization
      TYPE(InflowWind_InputType),            INTENT(  OUT)  :: u                 !< An initial guess for the input; the input mesh must be defined
      TYPE(InflowWind_ParameterType),        INTENT(  OUT)  :: ParamData         !< Parameters
      TYPE(InflowWind_ContinuousStateType),  INTENT(  OUT)  :: ContStates        !< Initial continuous states
      TYPE(InflowWind_DiscreteStateType),    INTENT(  OUT)  :: DiscStates        !< Initial discrete states
      TYPE(InflowWind_ConstraintStateType),  INTENT(  OUT)  :: ConstrStateGuess  !< Initial guess of the constraint states
      TYPE(InflowWind_OtherStateType),       INTENT(  OUT)  :: OtherStates       !< Initial other/optimization states
      TYPE(InflowWind_OutputType),           INTENT(  OUT)  :: OutData           !< Initial output (outputs are not calculated; only the output mesh is initialized)
      REAL(DbKi),                            INTENT(IN   )  :: TimeInterval      !< Coupling time interval in seconds: InflowWind does not change this.
      TYPE(InflowWind_InitOutputType),       INTENT(  OUT)  :: InitOutData       !< Initial output data -- Names, units, and version info.


         ! Error Handling

      INTEGER(IntKi),                        INTENT(  OUT)  :: ErrStat           !< Error status of the operation
      CHARACTER(*),                          INTENT(  OUT)  :: ErrMsg            !< Error message if ErrStat /= ErrID_None


         ! Local variables

      TYPE(InflowWind_InputFile)                            :: InputFileData     !< Data from input file

!!!      TYPE(IfW_UniformWind_InitInputType)                   :: Uniform_InitData       !< initialization info
!!!      TYPE(IfW_UniformWind_InputType)                       :: Uniform_InitGuess      !< input positions.
!!!      TYPE(IfW_UniformWind_ContinuousStateType)             :: Uniform_ContStates     !< Unused
!!!      TYPE(IfW_UniformWind_DiscreteStateType)               :: Uniform_DiscStates     !< Unused
!!!      TYPE(IfW_UniformWind_ConstraintStateType)             :: Uniform_ConstrStates   !< Unused
!!!      TYPE(IfW_UniformWind_OutputType)                      :: Uniform_OutData        !< output velocities
!!!
!!!      TYPE(IfW_FFWind_InitInputType)                        :: FF_InitData       !< initialization info
!!!      TYPE(IfW_FFWind_InputType)                            :: FF_InitGuess      !< input positions.
!!!      TYPE(IfW_FFWind_ContinuousStateType)                  :: FF_ContStates     !< Unused
!!!      TYPE(IfW_FFWind_DiscreteStateType)                    :: FF_DiscStates     !< Unused
!!!      TYPE(IfW_FFWind_ConstraintStateType)                  :: FF_ConstrStates   !< Unused
!!!      TYPE(IfW_FFWind_OutputType)                           :: FF_OutData        !< output velocities


!!!     TYPE(CTTS_Backgr)                                        :: BackGrndValues


         ! Temporary variables for error handling
      INTEGER(IntKi)                                        :: TmpErrStat
      CHARACTER(LEN(ErrMsg))                                :: TmpErrMsg         !< temporary error message




         !----------------------------------------------------------------------------------------------
         ! Initialize variables and check to see if this module has been initialized before.
         !----------------------------------------------------------------------------------------------

      ErrStat = ErrID_None
      ErrMsg  = ""


         ! Set a few variables.

      ParamData%DT            = TimeInterval             ! InflowWind does not require a specific time interval, so this is never changed.
      CALL NWTC_Init()
      CALL DispNVD( IfW_Ver )



         ! check to see if we are already initialized. Return if it has.
         ! If for some reason a different type of windfile should be used, then call InflowWind_End first, then reinitialize.

      IF ( ParamData%Initialized ) THEN
         CALL SetErrStat( ErrID_Warn, ' InflowWind has already been initialized.', ErrStat, ErrMsg, ' IfW_Init' )
         IF ( ErrStat >= AbortErrLev ) RETURN
      ENDIF


         !----------------------------------------------------------------------------------------------
         ! Read the input file
         !----------------------------------------------------------------------------------------------


         ! Set the names of the files based on the inputfilename
      ParamData%InputFileName = InitData%InputFileName
      CALL GetRoot( ParamData%InputFileName, ParamData%RootFileName )
      ParamData%EchoFileName  = TRIM(ParamData%RootFileName)//".IfW.ech"
      ParamData%SumFileName   = TRIM(ParamData%RootFileName)//".IfW.sum"


         ! Parse all the InflowWind related input files and populate the *_InitDataType derived types

      IF ( InitData%UseInputFile ) THEN
         CALL InflowWind_ReadInput( ParamData%InputFileName, ParamData%EchoFileName, InputFileData, TmpErrStat, TmpErrMsg )
         CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,'InflowWind_Init')
         IF ( ErrStat >= AbortErrLev ) THEN
            CALL Cleanup()
            RETURN
         ENDIF
      ELSE
            !  In the future we will make it possible to just copy the data from the InitData%PassedFileData (of derived type
            !  InflowWind_InputFile), and run things as normal using that data.  For now though, we will not allow this.
         CALL SetErrStat(ErrID_Fatal,' The UseInputFile flag cannot be set to .FALSE. at present.  This feature is not '// &
               'presently supported.',ErrStat,ErrMsg,'InflowWind_Init')
         CALL Cleanup()
         RETURN
      ENDIF





         ! Validate the InflowWind input file information.

      CALL InflowWind_ValidateInput( InputFileData, TmpErrStat, TmpErrMsg )
      CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,'InflowWind_Init')
      IF ( ErrStat>= AbortErrLev ) THEN
         CALL Cleanup()
         RETURN
      ENDIF


         ! Set the ParamData for InflowWind using the input file information.

      CALL InflowWind_SetParameters( InputFileData, ParamData, TmpErrStat, TmpErrMsg )
      CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,'InflowWind_Init')
      IF ( ErrStat>= AbortErrLev ) THEN
         CALL Cleanup()
         RETURN
      ENDIF



         ! Allocate the arrays for passing points in and velocities out
      IF ( .NOT. ALLOCATED(u%PositionXYZ) ) THEN
         CALL AllocAry( u%PositionXYZ, 3, InitData%NumWindPoints, &
                     "Array of positions at which to find wind velocities", TmpErrStat, TmpErrMsg )
         CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,'InflowWind_Init')
         IF ( ErrStat>= AbortErrLev ) THEN
            CALL Cleanup()
            RETURN
         ENDIF
      ENDIF
      IF ( .NOT. ALLOCATED(OutData%VelocityXYZ) ) THEN
         CALL AllocAry( OutData%VelocityXYZ, 3, InitData%NumWindPoints, &
                     "Array of wind velocities returned by InflowWind", TmpErrStat, TmpErrMsg )
         CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,'InflowWind_Init')
         IF ( ErrStat>= AbortErrLev ) THEN
            CALL Cleanup()
            RETURN
         ENDIF
      ENDIF


RETURN
      !-----------------------------------------------------------------
      ! Initialize the submodules based on the WindType
      !-----------------------------------------------------------------


      SELECT CASE ( ParamData%WindType )


         CASE ( Steady_WindNumber )
               ! This is a special case of the Uniform wind, so we call UniformWind_Init
            CALL SetErrStat( ErrID_Fatal,' Steady winds not supported yet.',ErrStat,ErrMsg,'InflowWind_Init')

         CASE ( Uniform_WindNumber )
               ! Initialize the UniformWind module
            CALL SetErrStat( ErrID_Fatal,' Uniform winds not supported yet.',ErrStat,ErrMsg,'InflowWind_Init')

         CASE ( TSFF_WindNumber )
               ! Initialize the TSFFWind module
            CALL SetErrStat( ErrID_Fatal,' TSFF winds not supported yet.',ErrStat,ErrMsg,'InflowWind_Init')

         CASE ( BladedFF_WindNumber )
               ! Initialize the BladedFFWind module
            CALL SetErrStat( ErrID_Fatal,' BladedFF winds not supported yet.',ErrStat,ErrMsg,'InflowWind_Init')

         CASE ( HAWC_WindNumber )
               ! Initialize the HAWCWind module
            CALL SetErrStat( ErrID_Fatal,' HAWC winds not supported yet.',ErrStat,ErrMsg,'InflowWind_Init')

         CASE ( User_WindNumber )
               ! Initialize the User_Wind module
            CALL SetErrStat( ErrID_Fatal,' User winds not supported yet.',ErrStat,ErrMsg,'InflowWind_Init')

         CASE DEFAULT  ! keep this check to make sure that all new wind types have been accounted for
            CALL SetErrStat(ErrID_Fatal,' Undefined wind type.',ErrStat,ErrMsg,'InflowWind_Init()')


      END SELECT


      IF ( ParamData%CTTS_Flag ) THEN
         ! Initialize the CTTS_Wind module
      ENDIF



!!!         !----------------------------------------------------------------------------------------------
!!!         ! Check for coherent turbulence file (KH superimposed on a background wind file)
!!!         ! Initialize the CTWind module and initialize the module of the other wind type.
!!!         !----------------------------------------------------------------------------------------------
!!!
!!!      IF ( ParamData%WindType == CTP_WindNumber ) THEN
!!!
!!!!FIXME: remove this error message when we add CTP_Wind in
!!!            CALL SetErrStat( ErrID_Fatal, ' InflowWind cannot currently handle the CTP_Wind type.', ErrStat, ErrMsg, ' IfW_Init' )
!!!            RETURN
!!!
!!!         CALL CTTS_Init(UnWind, ParamData%WindFileName, BackGrndValues, ErrStat, ErrMsg)
!!!         IF (ErrStat /= 0) THEN
!!!   !         CALL IfW_End( ParamData, ErrStat )
!!!   !FIXME: cannot call IfW_End here -- requires InitData to be INOUT. Not allowed by framework.
!!!   !         CALL IfW_End( InitData, ParamData, ContStates, DiscStates, ConstrStateGuess, OtherStates, &
!!!   !                       OutData, ErrStat, ErrMsg )
!!!            ParamData%WindType = Undef_Wind
!!!            ErrStat  = 1
!!!            RETURN
!!!         END IF
!!!
!!!   !FIXME: check this
!!!         ParamData%WindFileName = BackGrndValues%WindFile
!!!         ParamData%WindType = BackGrndValues%WindType
!!!   !      CTTS_Flag  = BackGrndValues%CoherentStr
!!!         ParamData%CTTS_Flag  = BackGrndValues%CoherentStr    ! This might be wrong
!!!
!!!      ELSE
!!!
!!!         ParamData%CTTS_Flag  = .FALSE.
!!!
!!!      END IF
!!!
!!!         !----------------------------------------------------------------------------------------------
!!!         ! Initialize based on the wind type
!!!         !----------------------------------------------------------------------------------------------
!!!
!!!      SELECT CASE ( ParamData%WindType )
!!!
!!!         CASE (Uniform_WindNumber)
!!!
!!!            Uniform_InitData%ReferenceHeight = InitData%ReferenceHeight
!!!            Uniform_InitData%Width           = InitData%Width
!!!            Uniform_InitData%WindFileName    = ParamData%WindFileName
!!!
!!!            CALL IfW_UniformWind_Init(Uniform_InitData,   Uniform_InitGuess,  ParamData%UniformWind,                         &
!!!                                 Uniform_ContStates, Uniform_DiscStates, Uniform_ConstrStates,     OtherStates%UniformWind,  &
!!!                                 Uniform_OutData,    TimeInterval,  InitOutData%UniformWind,  TmpErrStat,          TmpErrMsg)
!!!
!!!               CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, ' IfW_Init' )
!!!               IF ( ErrStat >= AbortErrLev ) RETURN
!!!
!!!
!!!              ! Copy Relevant info over to InitOutData
!!!
!!!                  ! Allocate and copy over the WriteOutputHdr info
!!!               CALL AllocAry( InitOutData%WriteOutputHdr, SIZE(InitOutData%UniformWind%WriteOutputHdr,1), &
!!!                              'Empty array for names of outputable information.', TmpErrStat, TmpErrMsg )
!!!                  CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, ' IfW_Init' )
!!!                  IF ( ErrStat >= AbortErrLev ) RETURN
!!!               InitOutData%WriteOutputHdr    =  InitOutData%UniformWind%WriteOutputHdr
!!!
!!!                  ! Allocate and copy over the WriteOutputUnt info
!!!               CALL AllocAry( InitOutData%WriteOutputUnt, SIZE(InitOutData%UniformWind%WriteOutputUnt,1), &
!!!                              'Empty array for units of outputable information.', TmpErrStat, TmpErrMsg )
!!!                  CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, ' IfW_Init' )
!!!                  IF ( ErrStat >= AbortErrLev ) RETURN
!!!
!!!               InitOutData%WriteOutputUnt    =  InitOutData%UniformWind%WriteOutputUnt
!!!
!!!                  ! Copy the hub height info over
!!!               InitOutData%HubHeight         =  InitOutData%UniformWind%HubHeight
!!!
!!!!           IF (CTTS_Flag) CALL CTTS_SetRefVal(FileInfo%ReferenceHeight, 0.5*FileInfo%Width, ErrStat)  !FIXME: check if this was originally used
!!!!           IF (ErrStat == ErrID_None .AND. ParamData%CTTS_Flag) &
!!!!              CALL CTTS_SetRefVal(InitData%ReferenceHeight, REAL(0.0, ReKi), ErrStat, ErrMsg)      !FIXME: will need to put this routine in the Init of CT
!!!
!!!
!!!         CASE (FF_WindNumber)
!!!
!!!            FF_InitData%ReferenceHeight = InitData%ReferenceHeight
!!!            FF_InitData%Width           = InitData%Width
!!!            FF_InitData%WindFileName    = ParamData%WindFileName
!!!
!!!            CALL IfW_FFWind_Init(FF_InitData,   FF_InitGuess,  ParamData%FFWind,                         &
!!!                                 FF_ContStates, FF_DiscStates, FF_ConstrStates,     OtherStates%FFWind,  &
!!!                                 FF_OutData,    TimeInterval,  InitOutData%FFWind,  TmpErrStat,          TmpErrMsg)
!!!
!!!               CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, ' IfW_Init' )
!!!               IF ( ErrStat >= AbortErrLev ) RETURN
!!!
!!!
!!!              ! Copy Relevant info over to InitOutData
!!!
!!!                  ! Allocate and copy over the WriteOutputHdr info
!!!               CALL AllocAry( InitOutData%WriteOutputHdr, SIZE(InitOutData%FFWind%WriteOutputHdr,1), &
!!!                              'Empty array for names of outputable information.', TmpErrStat, TmpErrMsg )
!!!                  CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, ' IfW_Init' )
!!!                  IF ( ErrStat >= AbortErrLev ) RETURN
!!!
!!!               InitOutData%WriteOutputHdr    =  InitOutData%FFWind%WriteOutputHdr
!!!
!!!                  ! Allocate and copy over the WriteOutputUnt info
!!!               CALL AllocAry( InitOutData%WriteOutputUnt, SIZE(InitOutData%FFWind%WriteOutputUnt,1), &
!!!                              'Empty array for units of outputable information.', TmpErrStat, TmpErrMsg )
!!!                  CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, ' IfW_Init' )
!!!                  IF ( ErrStat >= AbortErrLev ) RETURN
!!!
!!!               InitOutData%WriteOutputUnt    =  InitOutData%FFWind%WriteOutputUnt
!!!
!!!                  ! Copy the hub height info over
!!!               InitOutData%HubHeight         =  InitOutData%FFWind%HubHeight
!!!
!!!            !FIXME: Fix this when CTTS_Wind is available
!!!!               ! Set CT parameters
!!!!            IF ( ErrStat == ErrID_None .AND. ParamData%CTTS_Flag ) THEN
!!!!               Height     = FF_GetValue('HubHeight', ErrStat, ErrMsg)
!!!!               IF ( ErrStat /= 0 ) Height = InitData%ReferenceHeight
!!!!
!!!!               HalfWidth  = 0.5*FF_GetValue('GridWidth', ErrStat, ErrMsg)
!!!!               IF ( ErrStat /= 0 ) HalfWidth = 0
!!!!
!!!!               CALL CTTS_SetRefVal(Height, HalfWidth, ErrStat, ErrMsg)
!!!!            END IF
!!!
!!!
!!!         CASE (User_WindNumber)
!!!
!!!               !FIXME: remove this error message when we add UD_Wind in
!!!            CALL SetErrStat( ErrID_Fatal, ' InflowWind cannot currently handle the UD_Wind type.', ErrStat, ErrMsg, ' IfW_Init' )
!!!            RETURN
!!!
!!!!            CALL UsrWnd_Init(ErrStat)
!!!
!!!
!!!         CASE (FD_WindNumber)
!!!
!!!               !FIXME: remove this error message when we add FD_Wind in
!!!            CALL SetErrStat( ErrID_Fatal, ' InflowWind cannot currently handle the FD_Wind type.', ErrStat, ErrMsg, ' IfW_Init' )
!!!            RETURN
!!!
!!!!           CALL IfW_FDWind_Init(UnWind, ParamData%WindFileName, InitData%ReferenceHeight, ErrStat)
!!!
!!!
!!!         CASE (HAWC_WindNumber)
!!!
!!!               !FIXME: remove this error message when we add HAWC_Wind in
!!!            CALL SetErrStat( ErrID_Fatal, ' InflowWind cannot currently handle the HAWC_Wind type.', ErrStat, ErrMsg, ' IfW_Init' )
!!!            RETURN
!!!
!!!!           CALL HW_Init( UnWind, ParamData%WindFileName, ErrStat )
!!!
!!!
!!!         CASE DEFAULT
!!!
!!!            CALL SetErrStat( ErrID_Fatal, ' Error: Undefined wind type in WindInflow_Init()', ErrStat, ErrMsg, ' IfW_Init' )
!!!            RETURN
!!!
!!!      END SELECT
!!!
!!!
!!!         ! If we've arrived here, we haven't reached an AbortErrLev:
!!!      ParamData%Initialized = .TRUE.
!!!
!!!
!!!         ! Set the version information in InitOutData
!!!      InitOutData%Ver   = IfW_Ver



!FIXME: remove this when done with writing InflowWind_Init
CALL SetErrStat(ErrID_Fatal,' Routine not complete yet.',ErrStat,ErrMsg,'InflowWind_Init')


!FIXME: Set value for InitOutput_WindFileDT
!FIXME: Set values for InitOutput_WindFileTRange
!FIXME: Set values for InitOutput_WindFileNumTSteps

      RETURN


   !----------------------------------------------------------------------------------------------------
CONTAINS

   SUBROUTINE CleanUp()

      ! add in stuff that we need to dispose of here
      CALL InflowWind_DestroyInputFile( InputFileData, TmpErrsTat, TmpErrMsg )
      CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,'InflowWind_Init')

!!!      CALL InflowWind_DestroyInitInput( InitLocal,  TmpErrStat, TmpErrMsg );  CALL SetErrStat(TmpErrStat,TmpErrMsg,ErrStat,ErrMsg,'InflowWind_Init')


   END SUBROUTINE CleanUp



END SUBROUTINE InflowWind_Init



!====================================================================================================
SUBROUTINE InflowWind_CalcOutput( Time, InputData, ParamData, &
                              ContStates, DiscStates, ConstrStates, OtherStates, &   ! States -- none in this case
                              OutputData, ErrStat, ErrMsg )
   ! This routine takes an input dataset of type InputType which contains a position array of dimensions 3*n. It then calculates
   ! and returns the output dataset of type OutputType which contains a corresponding velocity array of dimensions 3*n. The input
   ! array contains XYZ triplets for each position of interest (first index is X/Y/Z for values 1/2/3, second index is the point
   ! number to evaluate). The returned values in the OutputData are similar with U/V/W for the first index of 1/2/3.
   !----------------------------------------------------------------------------------------------------

!FIXME: add ability to use the ASyncronous flag to prevent output of WindVi info.

         ! Inputs / Outputs

      REAL(DbKi),                               INTENT(IN   )  :: Time              !< Current simulation time in seconds
      TYPE(InflowWind_InputType),               INTENT(IN   )  :: InputData         !< Inputs at Time
      TYPE(InflowWind_ParameterType),           INTENT(IN   )  :: ParamData         !< Parameters
      TYPE(InflowWind_ContinuousStateType),     INTENT(IN   )  :: ContStates        !< Continuous states at Time
      TYPE(InflowWind_DiscreteStateType),       INTENT(IN   )  :: DiscStates        !< Discrete states at Time
      TYPE(InflowWind_ConstraintStateType),     INTENT(IN   )  :: ConstrStates      !< Constraint states at Time
      TYPE(InflowWind_OtherStateType),          INTENT(INOUT)  :: OtherStates       !< Other/optimization states at Time
      TYPE(InflowWind_OutputType),              INTENT(INOUT)  :: OutputData        !< Outputs computed at Time (IN for mesh reasons and data allocation)

      INTEGER(IntKi),                           INTENT(  OUT)  :: ErrStat           !< Error status of the operation
      CHARACTER(*),                             INTENT(  OUT)  :: ErrMsg            !< Error message if ErrStat /= ErrID_None


         ! Local variables

      TYPE(IfW_UniformWind_InitInputType)                           :: Uniform_InitData       !< initialization info
      TYPE(IfW_UniformWind_InputType)                               :: Uniform_InData         !< input positions.
      TYPE(IfW_UniformWind_ContinuousStateType)                     :: Uniform_ContStates     !< Unused
      TYPE(IfW_UniformWind_DiscreteStateType)                       :: Uniform_DiscStates     !< Unused
      TYPE(IfW_UniformWind_ConstraintStateType)                     :: Uniform_ConstrStates   !< Unused
      TYPE(IfW_UniformWind_OutputType)                              :: Uniform_OutData        !< output velocities

!!!      TYPE(IfW_FFWind_InitInputType)                           :: FF_InitData       !< initialization info
!!!      TYPE(IfW_FFWind_InputType)                               :: FF_InData         !< input positions.
!!!      TYPE(IfW_FFWind_ContinuousStateType)                     :: FF_ContStates     !< Unused
!!!      TYPE(IfW_FFWind_DiscreteStateType)                       :: FF_DiscStates     !< Unused
!!!      TYPE(IfW_FFWind_ConstraintStateType)                     :: FF_ConstrStates   !< Unused
!!!      TYPE(IfW_FFWind_OutputType)                              :: FF_OutData        !< output velocities




!NOTE: It isn't entirely clear what the purpose of Height is. Does it sometimes occur that Height  /= ParamData%ReferenceHeight???
      REAL(ReKi)                                               :: Height            ! Retrieved from FF
      REAL(ReKi)                                               :: HalfWidth         ! Retrieved from FF



         ! Temporary variables for error handling
      INTEGER(IntKi)                                           :: TmpErrStat
      CHARACTER(LEN(ErrMsg))                                   :: TmpErrMsg            ! temporary error message

!FIXME/TODO:  Need to add the wrapping layer for the Coordinate tranformations.  When this is added, the UniformWind will need to be modified so that a warning is given when the global PropogationDir and the wind-direction within the file are both non-zero.



!FIXME: add a check that the size of the input points array and the output velocity arrays are the same.

         ! Initialize ErrStat
      ErrStat  = ErrID_None
      ErrMsg   = ""


         ! Allocate the velocity array to get out
      IF ( .NOT. ALLOCATED(OutputData%VelocityXYZ) ) THEN
         CALL AllocAry( OutputData%VelocityXYZ, 3, SIZE(InputData%PositionXYZ,DIM=2), &
                     "Velocity array returned from IfW_CalcOutput", TmpErrStat, TmpErrMsg )
         CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, ' IfW_CalcOutput' )
         IF ( ErrStat >= AbortErrLev ) RETURN
      ELSEIF ( SIZE(InputData%PositionXYZ,DIM=2) /= SIZE(OutputData%VelocityXYZ,DIM=2) ) THEN
         CALL SetErrStat( ErrID_Fatal," Programming error: Position and Velocity arrays are not sized the same.",  &
               ErrStat, ErrMsg, ' IfW_CalcOutput')
      ENDIF

         ! Compute the wind velocities by stepping through all the data points and calling the appropriate GetWindSpeed routine
      SELECT CASE ( ParamData%WindType )
!!!         CASE (Uniform_WindNumber)
!!!
!!!               ! Allocate the position array to pass in
!!!            CALL AllocAry( Uniform_InData%Position, 3, SIZE(InputData%Position,2), &
!!!                           "Position grid for passing to IfW_UniformWind_CalcOutput", TmpErrStat, TmpErrMsg )
!!!            CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, ' IfW_CalcOutput' )
!!!            IF ( ErrStat >= AbortErrLev ) RETURN
!!!
!!!               ! Copy positions over
!!!            Uniform_InData%Position   = InputData%Position
!!!
!!!            CALL  IfW_UniformWind_CalcOutput(  Time,          Uniform_InData,     ParamData%UniformWind,                         &
!!!                                          Uniform_ContStates, Uniform_DiscStates, Uniform_ConstrStates,     OtherStates%UniformWind,  &
!!!                                          Uniform_OutData,    TmpErrStat,    TmpErrMsg)
!!!
!!!               ! Copy the velocities over
!!!            OutputData%Velocity  = Uniform_OutData%Velocity
!!!
!!!            CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, ' IfW_CalcOutput' )
!!!            IF ( ErrStat >= AbortErrLev ) RETURN
!!!
!!!
!!!         CASE (FF_WindNumber)
!!!
!!!               ! Allocate the position array to pass in
!!!            CALL AllocAry( FF_InData%Position, 3, SIZE(InputData%Position,2), &
!!!                           "Position grid for passing to IfW_FFWind_CalcOutput", TmpErrStat, TmpErrMsg )
!!!            CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, ' IfW_CalcOutput' )
!!!            IF ( ErrStat >= AbortErrLev ) RETURN
!!!
!!!            ! Copy positions over
!!!            FF_InData%Position   = InputData%Position
!!!
!!!            CALL  IfW_FFWind_CalcOutput(  Time,          FF_InData,     ParamData%FFWind,                         &
!!!                                          FF_ContStates, FF_DiscStates, FF_ConstrStates,     OtherStates%FFWind,  &
!!!                                          FF_OutData,    TmpErrStat,    TmpErrMsg)
!!!
!!!               ! Copy the velocities over
!!!            OutputData%Velocity  = FF_OutData%Velocity
!!!
!!!            CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, ' IfW_CalcOutput' )
!!!            IF ( ErrStat >= AbortErrLev ) RETURN


!!!               OutputData%Velocity(:,PointCounter) = FF_GetWindSpeed(     Time, InputData%Position(:,PointCounter), ErrStat, ErrMsg)


!!!         CASE (User_WindNumber)

!!!               OutputData%Velocity(:,PointCounter) = UsrWnd_GetWindSpeed( Time, InputData%Position(:,PointCounter), ErrStat )!, ErrMsg)


!!!         CASE (FD_WindNumber)

!!!               OutputData%Velocity(:,PointCounter) = FD_GetWindSpeed(     Time, InputData%Position(:,PointCounter), ErrStat )



!!!         CASE (HAWC_WindNumber)

!!!               OutputData%Velocity(:,PointCounter) = HW_GetWindSpeed(     Time, InputData%Position(:,PointCounter), ErrStat )



            ! If it isn't one of the above cases, we have a problem and won't be able to continue

         CASE DEFAULT

            CALL SetErrStat( ErrID_Fatal, ' Error: Undefined wind type in IfW_CalcOutput. ' &
                      //'Call WindInflow_Init() before calling this function.', ErrStat, ErrMsg, ' IfW_CalcOutput' )

            OutputData%VelocityXYZ(:,:) = 0.0
            RETURN

      END SELECT


            ! Add coherent turbulence to background wind

!!!         IF (ParamData%CTTS_Flag) THEN
!!!
!!!            DO PointCounter = 1, SIZE(InputData%Position, 2)
!!!
!!!               TempWindSpeed = CTTS_GetWindSpeed(     Time, InputData%Position(:,PointCounter), ErrStat, ErrMsg )
!!!
!!!                  ! Error Handling -- move ErrMsg inside CTTS_GetWindSPeed and simplify
!!!               IF (ErrStat >= ErrID_Severe) THEN
!!!                  ErrMsg   = 'IfW_CalcOutput: Error in CTTS_GetWindSpeed for point number '//TRIM(Num2LStr(PointCounter))
!!!                  EXIT        ! Exit the loop
!!!               ENDIF
!!!
!!!               OutputData%Velocity(:,PointCounter) = OutputData%Velocity(:,PointCounter) + TempWindSpeed
!!!
!!!            ENDDO
!!!
!!!               ! If something went badly wrong, Return
!!!            IF (ErrStat >= ErrID_Severe ) RETURN
!!!
!!!         ENDIF
!!!
      !ENDIF



END SUBROUTINE InflowWind_CalcOutput



!====================================================================================================
SUBROUTINE InflowWind_End( InitData, ParamData, ContStates, DiscStates, ConstrStateGuess, OtherStates, &
                       OutData, ErrStat, ErrMsg )
   ! Clean up the allocated variables and close all open files.  Reset the initialization flag so
   ! that we have to reinitialize before calling the routines again.
   !----------------------------------------------------------------------------------------------------

         ! Initialization data and guesses

      TYPE(InflowWind_InputType),               INTENT(INOUT)  :: InitData          !< Input data for initialization
      TYPE(InflowWind_ParameterType),           INTENT(INOUT)  :: ParamData         !< Parameters
      TYPE(InflowWind_ContinuousStateType),     INTENT(INOUT)  :: ContStates        !< Continuous states
      TYPE(InflowWind_DiscreteStateType),       INTENT(INOUT)  :: DiscStates        !< Discrete states
      TYPE(InflowWind_ConstraintStateType),     INTENT(INOUT)  :: ConstrStateGuess  !< Guess of the constraint states
      TYPE(InflowWind_OtherStateType),          INTENT(INOUT)  :: OtherStates       !< Other/optimization states
      TYPE(InflowWind_OutputType),              INTENT(INOUT)  :: OutData           !< Output data


         ! Error Handling

      INTEGER( IntKi ),                         INTENT(  OUT)  :: ErrStat
      CHARACTER(*),                             INTENT(  OUT)  :: ErrMsg

         ! Local variables

      TYPE(IfW_UniformWind_InputType)                               :: Uniform_InitData       !< input positions.
      TYPE(IfW_UniformWind_ContinuousStateType)                     :: Uniform_ContStates     !< Unused
      TYPE(IfW_UniformWind_DiscreteStateType)                       :: Uniform_DiscStates     !< Unused
      TYPE(IfW_UniformWind_ConstraintStateType)                     :: Uniform_ConstrStates   !< Unused
      TYPE(IfW_UniformWind_OutputType)                              :: Uniform_OutData        !< output velocities

!!!      TYPE(IfW_FFWind_InputType)                               :: FF_InitData       !< input positions.
!!!      TYPE(IfW_FFWind_ContinuousStateType)                     :: FF_ContStates     !< Unused
!!!      TYPE(IfW_FFWind_DiscreteStateType)                       :: FF_DiscStates     !< Unused
!!!      TYPE(IfW_FFWind_ConstraintStateType)                     :: FF_ConstrStates   !< Unused
!!!      TYPE(IfW_FFWind_OutputType)                              :: FF_OutData        !< output velocities


!!!     TYPE(CTTS_Backgr)                                           :: BackGrndValues


!NOTE: It isn't entirely clear what the purpose of Height is. Does it sometimes occur that Height  /= ParamData%ReferenceHeight???
      REAL(ReKi)                                         :: Height      ! Retrieved from FF
      REAL(ReKi)                                         :: HalfWidth   ! Retrieved from FF



         ! End the sub-modules (deallocates their arrays and closes their files):

      SELECT CASE ( ParamData%WindType )

         CASE (Uniform_WindNumber)
!!!            CALL IfW_UniformWind_End( Uniform_InitData,   ParamData%UniformWind,                                        &
!!!                                 Uniform_ContStates, Uniform_DiscStates,    Uniform_ConstrStates,  OtherStates%UniformWind,  &
!!!                                 Uniform_OutData,    ErrStat,          ErrMsg )
!!!
!!!         CASE (FF_WindNumber)
!!!            CALL IfW_FFWind_End( FF_InitData,   ParamData%FFWind,                                        &
!!!                                 FF_ContStates, FF_DiscStates,    FF_ConstrStates,  OtherStates%FFWind,  &
!!!                                 FF_OutData,    ErrStat,          ErrMsg )
!!!
!!!         CASE (User_WindNumber)
!!!            CALL UsrWnd_Terminate( ErrStat )
!!!
!!!         CASE (FD_WindNumber)
!!!            CALL FD_Terminate(     ErrStat )
!!!
!!!         CASE (HAWC_WindNumber)
!!!            CALL HW_Terminate(     ErrStat )

         CASE ( Undef_WindNumber )
            ! Do nothing

         CASE DEFAULT  ! keep this check to make sure that all new wind types have been accounted for
            CALL SetErrStat(ErrID_Fatal,' Undefined wind type.',ErrStat,ErrMsg,'InflowWind_End')

      END SELECT

!!!  !   IF (CTTS_Flag) CALL CTTS_Terminate( ErrStat ) !FIXME: should it be this line or the next?
!!!         CALL CTTS_Terminate( ErrStat, ErrMsg )


         ! Reset the wind type so that the initialization routine must be called
      ParamData%WindType = Undef_WindNumber
      ParamData%Initialized = .FALSE.
      ParamData%CTTS_Flag  = .FALSE.


END SUBROUTINE InflowWind_End



!====================================================================================================
! The following routines were added to satisfy the framework, but do nothing useful.
!====================================================================================================
SUBROUTINE InflowWind_UpdateStates( Time, u, p, x, xd, z, OtherState, ErrStat, ErrMsg )
! Loose coupling routine for solving for constraint states, integrating continuous states, and updating discrete states
! Constraint states are solved for input Time; Continuous and discrete states are updated for Time + Interval
!..................................................................................................................................

      REAL(DbKi),                               INTENT(IN   )  :: Time        !< Current simulation time in seconds
      TYPE(InflowWind_InputType),               INTENT(IN   )  :: u           !< Inputs at Time
      TYPE(InflowWind_ParameterType),           INTENT(IN   )  :: p           !< Parameters
      TYPE(InflowWind_ContinuousStateType),     INTENT(INOUT)  :: x           !< Input: Continuous states at Time;
                                                                              !! Output: Continuous states at Time + Interval
      TYPE(InflowWind_DiscreteStateType),       INTENT(INOUT)  :: xd          !< Input: Discrete states at Time;
                                                                              !! Output: Discrete states at Time  + Interval
      TYPE(InflowWind_ConstraintStateType),     INTENT(INOUT)  :: z           !< Input: Initial guess of constraint states at Time;
                                                                              !! Output: Constraint states at Time
      TYPE(InflowWind_OtherStateType),          INTENT(INOUT)  :: OtherState  !< Other/optimization states
      INTEGER(IntKi),                           INTENT(  OUT)  :: ErrStat     !< Error status of the operation
      CHARACTER(*),                             INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None

         ! Local variables

      TYPE(InflowWind_ContinuousStateType)                     :: dxdt        !< Continuous state derivatives at Time
      TYPE(InflowWind_ConstraintStateType)                     :: z_Residual  !< Residual of the constraint state equations (Z)

      INTEGER(IntKi)                                           :: TmpErrStat    !< Error status of the operation (occurs after initial error)
      CHARACTER(LEN(ErrMsg))                                   :: TmpErrMsg     !< Error message if TmpErrStat /= ErrID_None

         ! Initialize ErrStat


      ! BJJ: Please don't make my code end just because I called a routine that you don't use :)
      ErrStat = ErrID_None
      ErrMsg  = ""

      RETURN


      ErrStat = ErrID_Warn
      ErrMsg  = "IfW_UpdateStates was called.  That routine does nothing useful."



         ! Solve for the constraint states (z) here:

         ! Check if the z guess is correct and update z with a new guess.
         ! Iterate until the value is within a given tolerance.

      CALL IfW_CalcConstrStateResidual( Time, u, p, x, xd, z, OtherState, z_Residual, ErrStat, ErrMsg )
      IF ( ErrStat >= AbortErrLev ) THEN
         CALL IfW_DestroyConstrState( z_Residual, TmpErrStat, TmpErrMsg)
         ErrMsg = TRIM(ErrMsg)//' '//TRIM(TmpErrMsg)
         RETURN
      ENDIF

      ! DO WHILE ( z_Residual% > tolerance )
      !
      !  z =
      !
      !  CALL IfW_FFWind_CalcConstrStateResidual( Time, u, p, x, xd, z, OtherState, z_Residual, ErrStat, ErrMsg )
      !  IF ( ErrStat >= AbortErrLev ) THEN
      !     CALL IfW_FFWind_DestroyConstrState( z_Residual, TmpErrStat, TmpErrMsg)
      !     ErrMsg = TRIM(ErrMsg)//' '//TRIM(TmpErrMsg)
      !     RETURN
      !  ENDIF
      !
      ! END DO


         ! Destroy z_Residual because it is not necessary for the rest of the subroutine:

      CALL IfW_DestroyConstrState( z_Residual, ErrStat, ErrMsg)
      IF ( ErrStat >= AbortErrLev ) RETURN



         ! Get first time derivatives of continuous states (dxdt):

      CALL IfW_CalcContStateDeriv( Time, u, p, x, xd, z, OtherState, dxdt, ErrStat, ErrMsg )
      IF ( ErrStat >= AbortErrLev ) THEN
         CALL IfW_DestroyContState( dxdt, TmpErrStat, TmpErrMsg)
         ErrMsg = TRIM(ErrMsg)//' '//TRIM(TmpErrMsg)
         RETURN
      ENDIF


         ! Update discrete states:
         !   Note that xd [discrete state] is changed in IfW_FFWind_UpdateDiscState(), so IfW_FFWind_CalcOutput(),
         !   IfW_FFWind_CalcContStateDeriv(), and IfW_FFWind_CalcConstrStates() must be called first (see above).

      CALL IfW_UpdateDiscState(Time, u, p, x, xd, z, OtherState, ErrStat, ErrMsg )
      IF ( ErrStat >= AbortErrLev ) THEN
         CALL IfW_DestroyContState( dxdt, TmpErrStat, TmpErrMsg)
         ErrMsg = TRIM(ErrMsg)//' '//TRIM(TmpErrMsg)
         RETURN
      ENDIF


         ! Integrate (update) continuous states (x) here:

      !x = function of dxdt and x


         ! Destroy dxdt because it is not necessary for the rest of the subroutine

      CALL IfW_DestroyContState( dxdt, ErrStat, ErrMsg)
      IF ( ErrStat >= AbortErrLev ) RETURN



END SUBROUTINE InflowWind_UpdateStates



!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE InflowWind_CalcContStateDeriv( Time, u, p, x, xd, z, OtherState, dxdt, ErrStat, ErrMsg )
! Tight coupling routine for computing derivatives of continuous states
!..................................................................................................................................

      REAL(DbKi),                               INTENT(IN   )  :: Time        !< Current simulation time in seconds
      TYPE(InflowWind_InputType),               INTENT(IN   )  :: u           !< Inputs at Time
      TYPE(InflowWind_ParameterType),           INTENT(IN   )  :: p           !< Parameters
      TYPE(InflowWind_ContinuousStateType),     INTENT(IN   )  :: x           !< Continuous states at Time
      TYPE(InflowWind_DiscreteStateType),       INTENT(IN   )  :: xd          !< Discrete states at Time
      TYPE(InflowWind_ConstraintStateType),     INTENT(IN   )  :: z           !< Constraint states at Time
      TYPE(InflowWind_OtherStateType),          INTENT(INOUT)  :: OtherState  !< Other/optimization states
      TYPE(InflowWind_ContinuousStateType),     INTENT(  OUT)  :: dxdt        !< Continuous state derivatives at Time
      INTEGER(IntKi),                           INTENT(  OUT)  :: ErrStat     !< Error status of the operation
      CHARACTER(*),                             INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None


         ! Initialize ErrStat

      ErrStat = ErrID_None
      ErrMsg  = ""


         ! Compute the first time derivatives of the continuous states here:

      dxdt%DummyContState = 0.0_ReKi


END SUBROUTINE InflowWind_CalcContStateDeriv



!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE InflowWind_UpdateDiscState( Time, u, p, x, xd, z, OtherState, ErrStat, ErrMsg )
! Tight coupling routine for updating discrete states
!..................................................................................................................................

      REAL(DbKi),                               INTENT(IN   )  :: Time        !< Current simulation time in seconds
      TYPE(InflowWind_InputType),               INTENT(IN   )  :: u           !< Inputs at Time
      TYPE(InflowWind_ParameterType),           INTENT(IN   )  :: p           !< Parameters
      TYPE(InflowWind_ContinuousStateType),     INTENT(IN   )  :: x           !< Continuous states at Time
      TYPE(InflowWind_DiscreteStateType),       INTENT(INOUT)  :: xd          !< Input: Discrete states at Time;
                                                                              !! Output: Discrete states at Time + Interval
      TYPE(InflowWind_ConstraintStateType),     INTENT(IN   )  :: z           !< Constraint states at Time
      TYPE(InflowWind_OtherStateType),          INTENT(INOUT)  :: OtherState  !< Other/optimization states
      INTEGER(IntKi),                           INTENT(  OUT)  :: ErrStat     !< Error status of the operation
      CHARACTER(*),                             INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None


         ! Initialize ErrStat

      ErrStat = ErrID_None
      ErrMsg  = ""


         ! Update discrete states here:

      ! StateData%DiscState =

END SUBROUTINE InflowWind_UpdateDiscState



!----------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE InflowWind_CalcConstrStateResidual( Time, u, p, x, xd, z, OtherState, z_residual, ErrStat, ErrMsg )
! Tight coupling routine for solving for the residual of the constraint state equations
!..................................................................................................................................

      REAL(DbKi),                               INTENT(IN   )  :: Time        !< Current simulation time in seconds
      TYPE(InflowWind_InputType),               INTENT(IN   )  :: u           !< Inputs at Time
      TYPE(InflowWind_ParameterType),           INTENT(IN   )  :: p           !< Parameters
      TYPE(InflowWind_ContinuousStateType),     INTENT(IN   )  :: x           !< Continuous states at Time
      TYPE(InflowWind_DiscreteStateType),       INTENT(IN   )  :: xd          !< Discrete states at Time
      TYPE(InflowWind_ConstraintStateType),     INTENT(IN   )  :: z           !< Constraint states at Time (possibly a guess)
      TYPE(InflowWind_OtherStateType),          INTENT(INOUT)  :: OtherState  !< Other/optimization states
      TYPE(InflowWind_ConstraintStateType),     INTENT(  OUT)  :: z_residual  !< Residual of the constraint state equations using
                                                                              !! the input values described above
      INTEGER(IntKi),                           INTENT(  OUT)  :: ErrStat     !< Error status of the operation
      CHARACTER(*),                             INTENT(  OUT)  :: ErrMsg      !< Error message if ErrStat /= ErrID_None


         ! Initialize ErrStat

      ErrStat = ErrID_None
      ErrMsg  = ""


         ! Solve for the constraint states here:

      z_residual%DummyConstrState = 0

END SUBROUTINE InflowWind_CalcConstrStateResidual
!====================================================================================================
!====================================================================================================
FUNCTION WindInf_ADhack_diskVel( Time,ParamData, OtherStates,ErrStat, ErrMsg )
! This function should be deleted ASAP.  It's purpose is to reproduce results of AeroDyn 12.57;
! when a consensus on the definition of "average velocity" is determined, this function will be
! removed.
!----------------------------------------------------------------------------------------------------

      ! Passed variables

   REAL(DbKi),                                  INTENT(IN   )  :: Time              !< Time
   TYPE(InflowWind_ParameterType),              INTENT(IN   )  :: ParamData         !< Parameters
   TYPE(InflowWind_OtherStateType),             INTENT(INOUT)  :: OtherStates       !< Other/optimization states

   INTEGER(IntKi),                              INTENT(  OUT)  :: ErrStat
   CHARACTER(*),                                INTENT(  OUT)  :: ErrMsg

      ! Function definition
   REAL(ReKi)                    :: WindInf_ADhack_diskVel(3)

      ! Local variables
   REAL(ReKi)                    :: Delta_tmp            ! interpolated Delta   at input TIME
   REAL(ReKi)                    :: P                    ! temporary storage for slope (in time) used in linear interpolation
   REAL(ReKi)                    :: V_tmp                ! interpolated V       at input TIME
   REAL(ReKi)                    :: VZ_tmp               ! interpolated VZ      at input TIME



   ErrStat = ErrID_None

   SELECT CASE ( ParamData%WindType )
!!!      CASE (Uniform_WindNumber)
!!!
!!!         !-------------------------------------------------------------------------------------------------
!!!         ! Linearly interpolate in time (or use nearest-neighbor to extrapolate)
!!!         ! (compare with NWTC_Num.f90\InterpStpReal)
!!!         !-------------------------------------------------------------------------------------------------
!!!
!!!
!!!            ! Let's check the limits.
!!!         IF ( Time <= OtherStates%UniformWind%Tdata(1) .OR. OtherStates%UniformWind%NumDataLines == 1 )  THEN
!!!
!!!            OtherStates%UniformWind%TimeIndex      = 1
!!!            V_tmp         = OtherStates%UniformWind%V      (1)
!!!            Delta_tmp     = OtherStates%UniformWind%Delta  (1)
!!!            VZ_tmp        = OtherStates%UniformWind%VZ     (1)
!!!
!!!         ELSE IF ( Time >= OtherStates%UniformWind%Tdata(OtherStates%UniformWind%NumDataLines) )  THEN
!!!
!!!            OtherStates%UniformWind%TimeIndex = OtherStates%UniformWind%NumDataLines - 1
!!!            V_tmp                 = OtherStates%UniformWind%V      (OtherStates%UniformWind%NumDataLines)
!!!            Delta_tmp             = OtherStates%UniformWind%Delta  (OtherStates%UniformWind%NumDataLines)
!!!            VZ_tmp                = OtherStates%UniformWind%VZ     (OtherStates%UniformWind%NumDataLines)
!!!
!!!         ELSE
!!!
!!!              ! Let's interpolate!
!!!
!!!            OtherStates%UniformWind%TimeIndex = MAX( MIN( OtherStates%UniformWind%TimeIndex, OtherStates%UniformWind%NumDataLines-1 ), 1 )
!!!
!!!            DO
!!!
!!!               IF ( Time < OtherStates%UniformWind%Tdata(OtherStates%UniformWind%TimeIndex) )  THEN
!!!
!!!                  OtherStates%UniformWind%TimeIndex = OtherStates%UniformWind%TimeIndex - 1
!!!
!!!               ELSE IF ( Time >= OtherStates%UniformWind%Tdata(OtherStates%UniformWind%TimeIndex+1) )  THEN
!!!
!!!                  OtherStates%UniformWind%TimeIndex = OtherStates%UniformWind%TimeIndex + 1
!!!
!!!               ELSE
!!!                  P           =  ( Time - OtherStates%UniformWind%Tdata(OtherStates%UniformWind%TimeIndex) )/     &
!!!                                 ( OtherStates%UniformWind%Tdata(OtherStates%UniformWind%TimeIndex+1)             &
!!!                                 - OtherStates%UniformWind%Tdata(OtherStates%UniformWind%TimeIndex) )
!!!                  V_tmp       =  ( OtherStates%UniformWind%V(      OtherStates%UniformWind%TimeIndex+1)           &
!!!                                 - OtherStates%UniformWind%V(      OtherStates%UniformWind%TimeIndex) )*P         &
!!!                                 + OtherStates%UniformWind%V(      OtherStates%UniformWind%TimeIndex)
!!!                  Delta_tmp   =  ( OtherStates%UniformWind%Delta(  OtherStates%UniformWind%TimeIndex+1)           &
!!!                                 - OtherStates%UniformWind%Delta(  OtherStates%UniformWind%TimeIndex) )*P         &
!!!                                 + OtherStates%UniformWind%Delta(  OtherStates%UniformWind%TimeIndex)
!!!                  VZ_tmp      =  ( OtherStates%UniformWind%VZ(     OtherStates%UniformWind%TimeIndex+1)           &
!!!                                 - OtherStates%UniformWind%VZ(     OtherStates%UniformWind%TimeIndex) )*P  &
!!!                                 + OtherStates%UniformWind%VZ(     OtherStates%UniformWind%TimeIndex)
!!!                  EXIT
!!!
!!!               END IF
!!!
!!!            END DO
!!!
!!!         END IF
!!!
!!!      !-------------------------------------------------------------------------------------------------
!!!      ! calculate the wind speed at this time
!!!      !-------------------------------------------------------------------------------------------------
!!!
!!!         WindInf_ADhack_diskVel(1) =  V_tmp * COS( Delta_tmp )
!!!         WindInf_ADhack_diskVel(2) = -V_tmp * SIN( Delta_tmp )
!!!         WindInf_ADhack_diskVel(3) =  VZ_tmp
!!!
!!!
!!!
!!!      CASE (FF_WindNumber)
!!!
!!!         WindInf_ADhack_diskVel(1)   = OtherStates%FFWind%MeanFFWS
!!!         WindInf_ADhack_diskVel(2:3) = 0.0

      CASE DEFAULT
         ErrStat = ErrID_Fatal
         ErrMsg = ' WindInf_ADhack_diskVel: Undefined wind type.'

   END SELECT

   RETURN

END FUNCTION WindInf_ADhack_diskVel




!====================================================================================================
SUBROUTINE InflowWind_ReadInput( InputFileName, EchoFileName, InputFileData, ErrStat, ErrMsg )
!     This public subroutine reads the input required for InflowWind from the file whose name is an
!     input parameter.
!----------------------------------------------------------------------------------------------------


      ! Passed variables
   CHARACTER(*),                       INTENT(IN   )  :: InputFileName
   CHARACTER(*),                       INTENT(IN   )  :: EchoFileName
   TYPE(InflowWind_InputFile),         INTENT(INOUT)  :: InputFileData            !< The data for initialization
   INTEGER(IntKi),                     INTENT(  OUT)  :: ErrStat              !< Returned error status  from this subroutine
   CHARACTER(*),                       INTENT(  OUT)  :: ErrMsg               !< Returned error message from this subroutine


      ! Local variables
   INTEGER(IntKi)                                     :: UnitInput            !< Unit number for the input file
   INTEGER(IntKi)                                     :: UnitEcho             !< The local unit number for this module's echo file
   CHARACTER(1024)                                    :: TmpPath              !< Temporary storage for relative path name
   CHARACTER(1024)                                    :: TmpFmt               !< Temporary storage for format statement
   CHARACTER(35)                                      :: Frmt                 !< Output format for logical parameters. (matches NWTC Subroutine Library format)


      ! Temoporary messages
   INTEGER(IntKi)                                     :: TmpErrStat
   CHARACTER(LEN(ErrMsg))                             :: TmpErrMsg


      ! Initialize local data

   UnitEcho                = -1
   Frmt                    = "( 2X, L11, 2X, A, T30, ' - ', A )"
   ErrStat                 = ErrID_None
   ErrMsg                  = ""
   InputFileData%EchoFlag  = .FALSE.  ! initialize for error handling (cleanup() routine)



   !-------------------------------------------------------------------------------------------------
   ! Open the file
   !-------------------------------------------------------------------------------------------------

   CALL GetNewUnit( UnitInput, TmpErrStat, TmpErrMsg )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )

   CALL OpenFInpFile( UnitInput, TRIM(InputFileName), TmpErrStat, TmpErrMsg )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF


      ! Tell the users what we are doing... though this part should be rather quick.
   CALL WrScr( ' Opening InflowWind input file:  '//InputFileName )


   !-------------------------------------------------------------------------------------------------
   ! File header
   !-------------------------------------------------------------------------------------------------

   CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file header line 1', TmpErrStat, TmpErrMsg )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

   CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file header line 2', TmpErrStat, TmpErrMsg )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

   CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file separator line', TmpErrStat, TmpErrMsg )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF


     ! Echo Input Files.

   CALL ReadVar ( UnitInput, InputFileName, InputFileData%EchoFlag, 'Echo', 'Echo Input', TmpErrStat, TmpErrMsg )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! If we are Echoing the input then we should re-read the first three lines so that we can echo them
      ! using the NWTC_Library routines.  The echoing is done inside those routines via a global variable
      ! which we must store, set, and then replace on error or completion.

   IF ( InputFileData%EchoFlag ) THEN

      CALL OpenEcho ( UnitEcho, TRIM(EchoFileName), TmpErrStat, TmpErrMsg )
      CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
      IF (ErrStat >= AbortErrLev) THEN
         CALL CleanUp()
         RETURN
      END IF

      REWIND(UnitInput)


         ! The input file was already successfully read through up to this point, so we shouldn't have any read
         ! errors in the first four lines.  So, we won't worry about checking the error status here.

      CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file header line 1', TmpErrStat, TmpErrMsg, UnitEcho )
      CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )

      CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file header line 2', TmpErrStat, TmpErrMsg, UnitEcho )
      CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )

      CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file separator line', TmpErrStat, TmpErrMsg, UnitEcho )
      CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )

         ! Echo Input Files.

      CALL ReadVar ( UnitInput, InputFileName, InputFileData%EchoFlag, 'Echo', 'Echo the input file data', TmpErrStat, TmpErrMsg, UnitEcho )
      CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )

   END IF



   !-------------------------------------------------------------------------------------------------
   !> Read general section with wind type, direction, and output point list (applies to all wind types)
   !-------------------------------------------------------------------------------------------------


      ! Read WindType
   CALL ReadVar( UnitInput, InputFileName, InputFileData%WindType, 'WindType', &
               'switch for wind file type (1=steady; 2=uniform; 3=binary TurbSim FF; '//&
               '4=binary Bladed-style FF; 5=HAWC format; 6=User defined)', &
               TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF


      ! Read PropogationDir
   CALL ReadVar( UnitInput, InputFileName, InputFileData%PropogationDir, 'PropogationDir', &
               'Direction of wind propogation (meteoroligical direction)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF


      ! Read the number of points for the wind velocity output
   CALL ReadVar( UnitInput, InputFileName, InputFileData%NWindVel, 'NWindVel', &
               'Number of points to output the wind velocity (0 to 9)', &
               TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF

      ! Before proceeding, make sure that NWindVel makes sense
   IF ( InputFileData%NWindVel < 0 .OR. InputFileData%NwindVel > 9 ) THEN
      CALL SetErrStat( ErrID_Fatal, 'NWindVel must be greater than or equal to zero and less than 10.', &
                        ErrStat, ErrMsg, 'InflowWind_ReadInput' )
      CALL CleanUp()
      RETURN
   ELSE

      ! Allocate space for the output location arrays:
      CALL AllocAry( InputFileData%WindVxiList, InputFileData%NWindVel, 'WindVxiList', TmpErrStat, TmpErrMsg )
      CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
      CALL AllocAry( InputFileData%WindVyiList, InputFileData%NWindVel, 'WindVyiList', TmpErrStat, TmpErrMsg )
      CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
      CALL AllocAry( InputFileData%WindVziList, InputFileData%NWindVel, 'WindVziList', TmpErrStat, TmpErrMsg )
      CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
      IF (ErrStat >= AbortErrLev) THEN
         CALL CleanUp()
         RETURN
      ENDIF
   ENDIF

      ! Read in the values of WindVxiList
   CALL ReadAry( UnitInput, InputFileName, InputFileData%WindVxiList, InputFileData%NWindVel, 'WindVxiList', &
               'List of coordinates in the inertial X direction (m)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF

      ! Read in the values of WindVxiList
   CALL ReadAry( UnitInput, InputFileName, InputFileData%WindVyiList, InputFileData%NWindVel, 'WindVyiList', &
               'List of coordinates in the inertial Y direction (m)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF

      ! Read in the values of WindVziList
   CALL ReadAry( UnitInput, InputFileName, InputFileData%WindVziList, InputFileData%NWindVel, 'WindVziList', &
               'List of coordinates in the inertial Z direction (m)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF


   !-------------------------------------------------------------------------------------------------
   !> Read the _Parameters for Steady Wind Conditions [used only for WindType = 1]_ section
   !-------------------------------------------------------------------------------------------------

      ! Section separator line
   CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file separator line', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF


      ! Read HWindSpeed
   CALL ReadVar( UnitInput, InputFileName, InputFileData%Steady_HWindSpeed, 'HWindSpeed', &
                  'Horizontal windspeed for steady wind', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF

      ! Read RefHt
   CALL ReadVar( UnitInput, InputFileName, InputFileData%Steady_RefHt, 'RefHt', &
                  'Reference height for horizontal wind speed for steady wind', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF

      ! Read PLexp
   CALL ReadVar( UnitInput, InputFileName, InputFileData%Steady_PLexp, 'PLexp', &
                  'Power law exponent for steady wind', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF


   !-------------------------------------------------------------------------------------------------
   !> Read the _Parameters for Uniform wind file [used only for WindType = 2]_ section
   !-------------------------------------------------------------------------------------------------

      ! Section separator line
   CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file separator line', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read UniformWindFile
   CALL ReadVar( UnitInput, InputFileName, InputFileData%Uniform_FileName, 'WindFileName', &
                  'Filename of time series data for uniform wind field', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF

      ! Read RefHt
   CALL ReadVar( UnitInput, InputFileName, InputFileData%Uniform_RefHt, 'RefHt', &
                  'Reference height for uniform wind file', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF

      ! Read RefLength
   CALL ReadVar( UnitInput, InputFileName, InputFileData%Uniform_RefLength, 'RefLength', &
                  'Reference length for uniform wind file', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF


   !-------------------------------------------------------------------------------------------------
   !> Read the _Parameters for Binary TurbSim Full-Field files [used only for WindType = 3]_ section
   !-------------------------------------------------------------------------------------------------

      ! Section separator line
   CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file separator line', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read TSFFWind info
   CALL ReadVar( UnitInput, InputFileName, InputFileData%TSFF_FileName, 'FileName', &
               'Name of the TurbSim full field wind file to use (.bts)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF


   !-------------------------------------------------------------------------------------------------
   !> Read the _Parameters for Binary Bladed-style Full-Field files [used only for WindType = 4]_ section
   !-------------------------------------------------------------------------------------------------

      ! Section separator line
   CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file separator line', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read BladedStyle%WindFileName
   CALL ReadVar( UnitInput, InputFileName, InputFileData%Bladed_FileName, 'FileName', &
               'Name of the TurbSim full field wind file to use (.bts)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF

      ! Read TowerFileFlag
   CALL ReadVar( UnitInput, InputFileName, InputFileData%Bladed_TowerFile, 'TowerFileFlag', &
               'Have tower file (.twr) [flag]', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF


   !-------------------------------------------------------------------------------------------------
   !> Read the _Parameters for coherent turbulence [used only for WindType = 3 or 4]_ section
   !-------------------------------------------------------------------------------------------------

      ! Section separator line
   CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file separator line', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read CTTS_Flag
   CALL ReadVar( UnitInput, InputFileName, InputFileData%CTTS_CoherentTurb, 'CTTS_CoherentTurbFlag', &
               'Flag to coherent turbulence', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF

      ! Read CTWind%WindFileName
   CALL ReadVar( UnitInput, InputFileName, InputFileData%CTTS_FileName, 'CTTS_FileName', &
               'Name of coherent turbulence file', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF

      ! Read CTWind%PathName
   CALL ReadVar( UnitInput, InputFileName, InputFileData%CTTS_Path, 'CTTS_Path', &
               'Path to coherent turbulence binary files', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput')
   IF (ErrStat >= AbortErrLev) THEN
      CALL CleanUp()
      RETURN
   ENDIF



   !-------------------------------------------------------------------------------------------------
   !> Read the _Parameters for HAWC-formatted binary files [used only for WindType = 5]_ section
   !-------------------------------------------------------------------------------------------------

      ! Section separator line
   CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file separator line', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_FileName_u
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_FileName_u, 'HAWC_FileName_u', &
               'Name of the file containing the u-component fluctuating wind', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_FileName_v
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_FileName_v, 'HAWC_FileName_v', &
               'Name of the file containing the v-component fluctuating wind', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_FileName_w
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_FileName_w, 'HAWC_FileName_w', &
               'Name of the file containing the w-component fluctuating wind', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_nx
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_nx, 'HAWC_nx', &
               'Number of grids in the x direction (in the 3 files above)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_ny
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_ny, 'HAWC_ny', &
               'Number of grids in the y direction (in the 3 files above)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_nz
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_nz, 'HAWC_nz', &
               'Number of grids in the z direction (in the 3 files above)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_dx
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_dx, 'HAWC_dx', &
               'Number of grids in the x direction (in the 3 files above)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_dy
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_dy, 'HAWC_dy', &
               'Number of grids in the y direction (in the 3 files above)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_dz
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_dz, 'HAWC_dz', &
               'Number of grids in the z direction (in the 3 files above)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_RefHt
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_RefHt, 'HAWC_RefHt', &
               'Reference (hub) height of the grid', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF



      !----------------------------------------------------------------------------------------------
      !> Read the _Scaling parameters for turbulence (HAWC-format files) [used only for WindType = 5]_ subsection
      !----------------------------------------------------------------------------------------------

      ! Section separator line
   CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file separator line', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_ScaleMethod
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_ScaleMethod, 'HAWC_ScaleMethod', &
               'Turbulence scaling method [0=none, 1=direct scaling, 2= calculate scaling '// &
               'factor based on a desired standard deviation]', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_SFx
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_SFx, 'HAWC_SFx', &
               'Turbulence scaling factor for the x direction [ScaleMethod=1]', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_SFy
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_SFy, 'HAWC_SFy', &
               'Turbulence scaling factor for the y direction [ScaleMethod=1]', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_SFz
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_SFz, 'HAWC_SFz', &
               'Turbulence scaling factor for the z direction [ScaleMethod=1]', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_SigmaFx
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_SigmaFx, 'HAWC_SigmaFx', &
               'Turbulence standard deviation to calculate scaling from in x direction [ScaleMethod=2]', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_SigmaFy
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_SigmaFy, 'HAWC_SigmaFy', &
               'Turbulence standard deviation to calculate scaling from in y direction [ScaleMethod=2]', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_SigmaFz
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_SigmaFz, 'HAWC_SigmaFz', &
               'Turbulence standard deviation to calculate scaling from in z direction [ScaleMethod=2]', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

!FIXME:  TStart has no comment
      ! Read HAWC_TStart
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_TStart, 'HAWC_TStart', &
               '', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

!FIXME:  TStart has no comment
      ! Read HAWC_TEnd
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_TEnd, 'HAWC_TEnd', &
               '', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF


      !----------------------------------------------------------------------------------------------
      !> Read the _Mean wind profile paramters (added to HAWC-format files) [used only for WindType = 5]_ subsection
      !----------------------------------------------------------------------------------------------

      ! Section separator line
   CALL ReadCom( UnitInput, InputFileName, 'InflowWind input file separator line', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_URef
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_URef, 'HAWC_URef', &
               'Mean u-component wind speed at the reference height', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_ProfileType
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_ProfileType, 'HAWC_ProfileType', &
               'Wind profile type ("LOG"=logarithmic, "PL"=power law, or "UD"=user defined)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_PLExp
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_PLExp, 'HAWC_PLExp', &
               'Power law exponent (used for PL wind profile type only)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF

      ! Read HAWC_Z0
   CALL ReadVar( UnitInput, InputFileName, InputFileData%HAWC_Z0, 'HAWC_Z0', &
               'Surface roughness length (used for LOG wind profile type only)', TmpErrStat, TmpErrMsg, UnitEcho )
   CALL SetErrStat( TmpErrStat, TmpErrMsg, ErrStat, ErrMsg, 'InflowWind_ReadInput' )
   IF (ErrStat >= AbortErrLev) THEN
      CALL Cleanup()
      RETURN
   END IF




!FIXME: read the outlist


   !-------------------------------------------------------------------------------------------------
   ! This is the end of the input file
   !-------------------------------------------------------------------------------------------------

   CALL Cleanup()

   RETURN

      CONTAINS
         !..............................
         SUBROUTINE Cleanup()


               ! Close input file
            CLOSE ( UnitInput )

               ! Cleanup the Echo file and global variables
            IF ( InputFileData%EchoFlag ) THEN
               CLOSE(UnitEcho)
            END IF


         END SUBROUTINE Cleanup

END SUBROUTINE InflowWind_ReadInput


!====================================================================================================
!> This private subroutine verifies the input required for InflowWind is correctly specified.  This
!! routine checkes all the parameters that are common with all the wind types, then calls subroutines
!! that check the parameters specific to each wind type.  Only the parameters corresponding to the
!! desired wind type are evaluated; the rest are ignored.  Additional checks will be performed after
!! the respective wind file has been read in, but these checks will be performed within the respective
!! wind module.
!
!  The reason for structuring it this way is to allow for relocating the validation routines for the
!  wind type into their respective modules. It might also prove useful later if we change languages
!  but retain the fortran wind modules.
SUBROUTINE InflowWind_ValidateInput( InputFileData, ErrStat, ErrMsg )


      ! Passed variables

   TYPE(InflowWind_InputFile),         INTENT(INOUT)  :: InputFileData        !< The data for initialization
   INTEGER(IntKi),                     INTENT(  OUT)  :: ErrStat              !< Error status  from this subroutine
   CHARACTER(*),                       INTENT(  OUT)  :: ErrMsg               !< Error message from this subroutine


      ! Temporary variables
   INTEGER(IntKi)                                     :: TmpErrStat           !< Temporary error status  for subroutine and function calls
   CHARACTER(LEN(ErrMsg))                             :: TmpErrMsg            !< Temporary error message for subroutine and function calls

      ! Local variables



      ! Initialize ErrStat

   ErrStat = ErrID_None
   ErrMsg  = ""


      !-----------------------------------------------
      ! Data that applies to all wind types
      !-----------------------------------------------

      ! WindType
   IF ( InputFileData%WindType <= Undef_WindNumber .OR. InputFileData%WindType > Highest_WindNumber ) THEN
      CALL SetErrStat(ErrID_Fatal,' Invalid WindType specified.  Only values of '//   &
            TRIM(Num2LStr( Steady_WindNumber    ))//','// &
            TRIM(Num2LStr( Uniform_WindNumber   ))//','// &
            TRIM(Num2LStr( TSFF_WindNumber      ))//','// &
            TRIM(Num2LStr( BladedFF_WindNumber  ))//','// &
            TRIM(Num2LStr( HAWC_WindNumber      ))//', or '// &
            TRIM(Num2LStr( User_WindNumber      ))//' are supported.', &
            ErrStat,ErrMsg,'InflowWind_ValidateInput')
      RETURN
   ENDIF




      !-----------------------------------------------
      ! Data specific to a WindType
      !-----------------------------------------------

   SELECT CASE ( InputFileData%WindType )

      CASE ( Steady_WindNumber )
         CALL Steady_ValidateInput()

      CASE ( Uniform_WindNumber )
         CALL Uniform_ValidateInput()

      CASE ( TSFF_WindNumber )
         CALL TSFF_ValidateInput()

      CASE ( BladedFF_WindNumber )
         CALL BladedFF_ValidateInput()

      CASE ( HAWC_WindNumber )
         CALL HAWC_ValidateInput()

      CASE ( User_WindNumber )
         CALL User_ValidateInput()

      CASE DEFAULT  ! keep this check to make sure that all new wind types have been accounted for
         CALL SetErrStat(ErrID_Fatal,' Undefined wind type.',ErrStat,ErrMsg,'InflowWind_ValidateInput')

   END SELECT

      ! NOTE: we are not checking the error status yet, but rather will run through the Coherent turbulence section
      !        before returning.  This way a user will know of errors there as well before having to fix the first
      !        section.

      ! Coherent turbulence
   IF ( InputFileData%CTTS_CoherentTurb ) THEN
      CALL CTTS_ValidateInput()
   ENDIF


   RETURN

CONTAINS

   !> This subroutine checks that the values for the steady wind make sense.  There aren't many to check.
   SUBROUTINE Steady_ValidateInput()

         ! Check that HWindSpeed is positive
      IF ( InputFileData%Steady_HWindSpeed <= 0.0_ReKi ) THEN
         CALL SetErrStat(ErrID_Fatal,' Horizontal wind speed (HWindSpeed) for steady winds must be greater than zero.',  &
               ErrStat,ErrMsg,'Steady_ValidateInput')
      ENDIF

         ! Check that RefHt is positive
      IF ( InputFileData%Steady_RefHt <= 0.0_ReKi ) THEN
         CALL SetErrStat(ErrID_Fatal,' Reference height (RefHt) for steady winds must be greater than zero.',  &
               ErrStat,ErrMsg,'Steady_ValidateInput')
      ENDIF

         ! Check that PLexp is positive
      IF ( InputFileData%Steady_PLexp < 0.0_ReKi ) THEN
         CALL SetErrStat(ErrID_Fatal,' Power law exponent (PLexp) for steady winds must be positive or zero.',  &
               ErrStat,ErrMsg,'Steady_ValidateInput')
      ENDIF

      RETURN
   END SUBROUTINE Steady_ValidateInput



   !> This subroutine checks that the values for the uniform wind make sense.  There isn't much to check.
   SUBROUTINE Uniform_ValidateInput()

         ! Local variables
      LOGICAL                                         :: TmpFileExist

         ! Check that the filename requested actually exists
      INQUIRE( file=InputFileData%Uniform_FileName, exist=TmpFileExist )
      IF ( .NOT. TmpFileExist ) THEN
         CALL SetErrStat( ErrID_Fatal," Cannot find uniform wind input file: '"//TRIM(InputFileData%Uniform_FileName)//"'", &
               ErrStat,ErrMsg,'Uniform_ValidateInput')
      ENDIF

         ! Check that RefHt is positive
      IF ( InputFileData%Uniform_RefHt <= 0.0_ReKi ) THEN
         CALL SetErrStat(ErrID_Fatal,' Reference height (RefHt) for uniform winds must be greater than zero.',  &
               ErrStat,ErrMsg,'Uniform_ValidateInput')
      ENDIF

!FIXME: Do I need to check the RefLength?
      RETURN

   END SUBROUTINE Uniform_ValidateInput



   !> There isn't much to check for the TurbSim full-field section of the input file.
   SUBROUTINE TSFF_ValidateInput()

         ! Local variables
      LOGICAL                                         :: TmpFileExist

         ! Check that the filename requested actually exists
      INQUIRE( file=InputFileData%TSFF_FileName, exist=TmpFileExist )
      IF ( .NOT. TmpFileExist ) THEN
         CALL SetErrStat( ErrID_Fatal," Cannot find TurbSim full-field wind input file: '"//TRIM(InputFileData%TSFF_FileName)//"'", &
               ErrStat,ErrMsg,'TSFF_ValidateInput')
      ENDIF

      RETURN

   END SUBROUTINE TSFF_ValidateInput



   !> We will only check the main bladed input file here.  We will check the existance of the towerfile (if requested) in the SetParameters routine.
   SUBROUTINE BladedFF_ValidateInput()

         ! Local variables
      LOGICAL                                         :: TmpFileExist

         ! Check that the filename requested actually exists
      INQUIRE( file=InputFileData%Bladed_FileName, exist=TmpFileExist )
      IF ( .NOT. TmpFileExist ) THEN
         CALL SetErrStat( ErrID_Fatal," Cannot find Bladed-style full-field wind input file: '"//TRIM(InputFileData%Bladed_FileName)//"'", &
               ErrStat,ErrMsg,'BladedFF_ValidateInput')
      ENDIF

      RETURN
   END SUBROUTINE BladedFF_ValidateInput



   !> This routine checks to see if coherent turbulence can be used or not.  We check the path and file
   !! information before proceeding.  The coherent turbulence info is loaded after the full-field files have
   !! been read, and those can be very slow to load.  So we preemptively check the existence of the coherent
   !! turbulence file.  Further checking that the coherent turbulence can actually be used is check by the
   !! CTTS_Wind submodule (after the loading of the other stuff).
   SUBROUTINE CTTS_ValidateInput()

         ! Local variables
      LOGICAL                                         :: TmpFileExist

         ! Check if coherent turbulence can be used or not.  It is only applicable to the TSFF and BladedFF wind
         ! file types.
      IF ( InputFileData%CTTS_CoherentTurb .AND. ( .NOT. InputFileData%WindType == TSFF_WindNumber ) &
               .AND. ( .NOT. InputFileData%WindType == BladedFF_WindNumber ) ) THEN
         CALL SetErrStat(ErrID_Fatal,' Coherent turbulence may only be used with full field wind data (WindType = '// &
               TRIM(Num2LStr(TSFF_WindNumber))//' or '//TRIM(Num2LStr(BladedFF_WindNumber))//').', &
               ErrStat,ErrMsg,'CTTS_ValidateInput')
         RETURN
      ENDIF

         ! Check that the CT input file exists.
      INQUIRE( file=InputFileData%CTTS_FileName, exist=TmpFileExist )
      IF ( .NOT. TmpFileExist ) THEN
         CALL SetErrStat( ErrID_Fatal," Cannot find the coherent turbulence input file: '"//TRIM(InputFileData%CTTS_FileName)//"'", &
               ErrStat,ErrMsg,'CTTS_ValidateInput')
      ENDIF

         ! Check that the CT Event path exists.
      ! Unfortunately there is no good portable method to do this, so we won't try.
!FIXME: See if we have anything in the library.  -- Nothing I found...

      RETURN

   END SUBROUTINE CTTS_ValidateInput



   !> This routine checks the HAWC wind file type section of the input file.
   SUBROUTINE HAWC_ValidateInput()

         ! Local variables
      LOGICAL                                         :: TmpFileExist

         ! Check that the wind files exist.
      INQUIRE( file=InputFileData%HAWC_FileName_u, exist=TmpFileExist )
      IF ( .NOT. TmpFileExist ) THEN
         CALL SetErrStat( ErrID_Fatal," Cannot find the HAWC u-component wind file: '"//TRIM(InputFileData%HAWC_FileName_u)//"'", &
               ErrStat,ErrMsg,'HAWC_ValidateInput')
      ENDIF

      INQUIRE( file=InputFileData%HAWC_FileName_v, exist=TmpFileExist )
      IF ( .NOT. TmpFileExist ) THEN
         CALL SetErrStat( ErrID_Fatal," Cannot find the HAWC v-component wind file: '"//TRIM(InputFileData%HAWC_FileName_v)//"'", &
               ErrStat,ErrMsg,'HAWC_ValidateInput')
      ENDIF
      INQUIRE( file=InputFileData%HAWC_FileName_w, exist=TmpFileExist )
      IF ( .NOT. TmpFileExist ) THEN
         CALL SetErrStat( ErrID_Fatal," Cannot find the HAWC w-component wind file: '"//TRIM(InputFileData%HAWC_FileName_w)//"'", &
               ErrStat,ErrMsg,'HAWC_ValidateInput')
      ENDIF


         ! Check that the number of grids make some sense
      IF ( InputFileData%HAWC_nx <= 0_IntKi ) THEN
         CALL SetErrStat( ErrID_Fatal,' Number of grids in the x-direction of HAWC wind files (nx) must be greater than zero.',  &
               ErrStat,ErrMsg,'HAWC_ValidateInput')
      ENDIF

      IF ( InputFileData%HAWC_ny <= 0_IntKi ) THEN
         CALL SetErrStat( ErrID_Fatal,' Number of grids in the y-direction of HAWC wind files (ny) must be greater than zero.',  &
               ErrStat,ErrMsg,'HAWC_ValidateInput')
      ENDIF

      IF ( InputFileData%HAWC_nz <= 0_IntKi ) THEN
         CALL SetErrStat( ErrID_Fatal,' Number of grids in the z-direction of HAWC wind files (nz) must be greater than zero.',  &
               ErrStat,ErrMsg,'HAWC_ValidateInput')
      ENDIF


         ! Check that the distance between points is positive
      IF ( InputFileData%HAWC_dx <= 0.0_ReKi ) THEN
         CALL SetErrStat( ErrID_Fatal,' Distance between points in the x-direction of HAWC wind files (dx) must be greater than zero.',  &
               ErrStat,ErrMsg,'HAWC_ValidateInput')
      ENDIF

      IF ( InputFileData%HAWC_dy <= 0.0_ReKi ) THEN
         CALL SetErrStat( ErrID_Fatal,' Distance between points in the y-direction of HAWC wind files (dy) must be greater than zero.',  &
               ErrStat,ErrMsg,'HAWC_ValidateInput')
      ENDIF

      IF ( InputFileData%HAWC_dz <= 0.0_ReKi ) THEN
         CALL SetErrStat( ErrID_Fatal,' Distance between points in the z-direction of HAWC wind files (dz) must be greater than zero.',  &
               ErrStat,ErrMsg,'HAWC_ValidateInput')
      ENDIF


         ! Check that RefHt is positive
      IF ( InputFileData%HAWC_RefHt <= 0.0_ReKi ) THEN
         CALL SetErrStat( ErrID_Fatal,' Reference height (RefHt) for HAWC winds must be greater than zero.',  &
               ErrStat,ErrMsg,'HAWC_ValidateInput')
      ENDIF


         !----------------------
         ! Scaling method info
         !----------------------

      IF ( ( InputFileData%HAWC_ScaleMethod < 0_IntKi ) .OR. ( InputFileData%HAWC_ScaleMethod > 3_IntKi ) ) THEN
         CALL SetErrStat( ErrID_Fatal,' The scaling method (ScaleMethod) for HAWC winds can only be 0, 1, or 2.', &
               ErrStat,ErrMsg,'HAWC_ValidateInput')
      ENDIF

         ! Check the other scaling parameters
      SELECT CASE( InputFileData%HAWC_ScaleMethod )

      CASE ( 1 )

         IF ( InputFileData%HAWC_SFx <= 0.0_ReKi ) THEN
            CALL SetErrStat( ErrID_Fatal,' HAWC wind scaling paramter SFx must be greater than zero.', &
                  ErrStat,ErrMsg,'HAWC_ValidateInput')
         ENDIF

         IF ( InputFileData%HAWC_SFy <= 0.0_ReKi ) THEN
            CALL SetErrStat( ErrID_Fatal,' HAWC wind scaling paramter SFy must be greater than zero.', &
                  ErrStat,ErrMsg,'HAWC_ValidateInput')
         ENDIF

         IF ( InputFileData%HAWC_SFz <= 0.0_ReKi ) THEN
            CALL SetErrStat( ErrID_Fatal,' HAWC wind scaling paramter SFz must be greater than zero.', &
                  ErrStat,ErrMsg,'HAWC_ValidateInput')
         ENDIF

      CASE ( 2 )

         IF ( InputFileData%HAWC_SigmaFx <= 0.0_ReKi ) THEN
            CALL SetErrStat( ErrID_Fatal,' HAWC wind scaling paramter SigmaFx must be greater than zero.', &
                  ErrStat,ErrMsg,'HAWC_ValidateInput')
         ENDIF

         IF ( InputFileData%HAWC_SigmaFy <= 0.0_ReKi ) THEN
            CALL SetErrStat( ErrID_Fatal,' HAWC wind scaling paramter SigmaFy must be greater than zero.', &
                  ErrStat,ErrMsg,'HAWC_ValidateInput')
         ENDIF

         IF ( InputFileData%HAWC_SigmaFz <= 0.0_ReKi ) THEN
            CALL SetErrStat( ErrID_Fatal,' HAWC wind scaling paramter SigmaFz must be greater than zero.', &
                  ErrStat,ErrMsg,'HAWC_ValidateInput')
         ENDIF

      END SELECT


         ! Start and end times of the scaling, but only if ScaleMethod is set.
      IF ( ( InputFileData%HAWC_ScaleMethod == 1_IntKi ) .OR. (InputFileData%HAWC_ScaleMethod == 2_IntKi ) ) THEN
            ! Check that the start time is >= 0.  NOTE: this may be an invalid test.
         IF ( InputFileData%HAWC_TStart < 0.0_ReKi ) THEN
            CALL SetErrStat( ErrID_Fatal,' HAWC wind scaling TStart must be zero or positive.',  &
                  ErrStat,ErrMsg,'HAWC_ValidateInput')
         ENDIF

         IF ( InputFileData%HAWC_TStart < 0.0_ReKi ) THEN
            CALL SetErrStat( ErrID_Fatal,' HAWC wind scaling TStart must be zero or positive.',  &
                  ErrStat,ErrMsg,'HAWC_ValidateInput')
         ENDIF

         IF ( InputFileData%HAWC_TStart > InputFileData%HAWC_TEnd ) THEN
            CALL SetErrStat( ErrID_Fatal,' HAWC wind scaling start time must occur before the end time.',   &
                  ErrStat,ErrMsg,'HAWC_ValidateInput')
         ENDIF

!FIXME:  How do we want to handle having the start and end times both being exactly zero?  Is that a do not apply, or apply for all time?
!FIXME:  What about TStart == TEnd ?
         IF ( EqualRealNos( InputFileData%HAWC_TStart, InputFileData%HAWC_TEnd ) ) THEN
            CALL SetErrStat( ErrID_Severe,' Start and end time for HAWC wind scaling are identical.  No time elapses.', &
                  ErrStat,ErrMsg,'HAWC_ValidateInput')
         ENDIF

      ENDIF

      RETURN

   END SUBROUTINE HAWC_ValidateInput



   !> This routine is a placeholder for later development by the end user.  It should only be used if additional inputs
   !! for the user defined routines are added to the input file. Otherwise, this routine may be ignored by the user.
   SUBROUTINE User_ValidateInput()
      RETURN
   END SUBROUTINE User_ValidateInput


END SUBROUTINE InflowWind_ValidateInput





!====================================================================================================
!> This private subroutine copies the info from the input file over to the parameters for InflowWind.
SUBROUTINE InflowWind_SetParameters( InputFileData, ParamData, ErrStat, ErrMsg )


      ! Passed variables

   TYPE(InflowWind_InputFile),         INTENT(INOUT)  :: InputFileData        !< The data for initialization
   TYPE(InflowWind_ParameterType),     INTENT(INOUT)  :: ParamData            !< The parameters for InflowWind
   INTEGER(IntKi),                     INTENT(  OUT)  :: ErrStat              !< Error status  from this subroutine
   CHARACTER(*),                       INTENT(  OUT)  :: ErrMsg               !< Error message from this subroutine


      ! Temporary variables
   INTEGER(IntKi)                                     :: TmpErrStat           !< Temporary error status  for subroutine and function calls
   CHARACTER(LEN(ErrMsg))                             :: TmpErrMsg            !< Temporary error message for subroutine and function calls

      ! Local variables



      ! Initialize ErrStat

   ErrStat = ErrID_None
   ErrMsg  = ""


   !-----------------------------------------------------------------
   ! Copy over the general information that applies to everything
   !-----------------------------------------------------------------

      ! Copy the WindType over.

   ParamData%WindType   =  InputFileData%WindType


      ! Convert the PropogationDir to radians and store this.  For simplicity, we will shift it to be between -pi and pi

   ParamData%PropogationDir   = D2R * InputFileData%PropogationDir
   CALL MPi2Pi( ParamData%PropogationDir )         ! Shift if necessary so that the value is between -pi and pi


      ! Copy over the list of wind coordinates.  Move the arrays to the new one.

   ParamData%NWindVel   =  InputFileData%NWindVel
   CALL MOVE_ALLOC( InputFileData%WindVxiList, ParamData%WindVxiList )
   CALL MOVE_ALLOC( InputFileData%WindVyiList, ParamData%WindVyiList )
   CALL MOVE_ALLOC( InputFileData%WindVziList, ParamData%WindVziList )



   SELECT CASE ( ParamData%WindType )


      CASE ( Steady_WindNumber )
         CALL Steady_SetParameters()

      CASE ( Uniform_WindNumber )
         CALL Uniform_SetParameters()

      CASE ( TSFF_WindNumber )
         CALL TSFF_SetParameters()

      CASE ( BladedFF_WindNumber )
         CALL BladedFF_SetParameters()

      CASE ( HAWC_WindNumber )
         CALL HAWC_SetParameters()

      CASE ( User_WindNumber )
         CALL User_SetParameters()

      CASE DEFAULT  ! keep this check to make sure that all new wind types have been accounted for
         CALL SetErrStat(ErrID_Fatal,' Undefined wind type.',ErrStat,ErrMsg,'InflowWind_SetParameters')

   END SELECT


   IF ( InputFileData%CTTS_CoherentTurb ) THEN
      CALL CTTS_SetParameters()
   ENDIF


   CALL SetErrStat(ErrID_Fatal,' This subroutine has not been written yet.',ErrStat,ErrMsg,'InflowWind_SetParameters')


CONTAINS
   SUBROUTINE Steady_SetParameters()
      CALL SetErrStat(ErrID_Warn,' This subroutine has not been written yet.',ErrStat,ErrMsg,'Steady_SetParameters')
   END SUBROUTINE Steady_SetParameters

   SUBROUTINE Uniform_SetParameters()
      CALL SetErrStat(ErrID_Warn,' This subroutine has not been written yet.',ErrStat,ErrMsg,'Uniform_SetParameters')
   END SUBROUTINE Uniform_SetParameters

   SUBROUTINE TSFF_SetParameters()
      CALL SetErrStat(ErrID_Warn,' This subroutine has not been written yet.',ErrStat,ErrMsg,'TSFF_SetParameters')
   END SUBROUTINE TSFF_SetParameters

   SUBROUTINE BladedFF_SetParameters()
!Check the tower file status here.
      CALL SetErrStat(ErrID_Warn,' This subroutine has not been written yet.',ErrStat,ErrMsg,'BladedFF_SetParameters')
   END SUBROUTINE BladedFF_SetParameters

   SUBROUTINE HAWC_SetParameters()
      CALL SetErrStat(ErrID_Warn,' This subroutine has not been written yet.',ErrStat,ErrMsg,'HAWC_SetParameters')
   END SUBROUTINE HAWC_SetParameters

   SUBROUTINE User_SetParameters()
      CALL SetErrStat(ErrID_Warn,' This subroutine has not been written yet.',ErrStat,ErrMsg,'User_SetParameters')
   END SUBROUTINE User_SetParameters

   SUBROUTINE CTTS_SetParameters()
      CALL SetErrStat(ErrID_Warn,' This subroutine has not been written yet.',ErrStat,ErrMsg,'CTTS_SetParameters')
   END SUBROUTINE CTTS_SetParameters

END SUBROUTINE InflowWind_SetParameters




!====================================================================================================
!> The routine prints out warning messages if the user has requested invalid output channel names
!! The errstat is set to ErrID_Warning if any element in foundMask is .FALSE.
!FIXME: revamp this routine.
SUBROUTINE PrintBadChannelWarning(NUserOutputs, UserOutputs , foundMask, ErrStat, ErrMsg )
!----------------------------------------------------------------------------------------------------
   INTEGER(IntKi),                     INTENT(IN   )  :: NUserOutputs         !< Number of user-specified output channels
   CHARACTER(10),                      INTENT(IN   )  :: UserOutputs(:)       !< An array holding the names of the requested output channels.
   LOGICAL,                            INTENT(IN   )  :: foundMask(:)         !< A mask indicating whether a user requested channel belongs to a module's output channels.
   INTEGER(IntKi),                     INTENT(  OUT)  :: ErrStat              !< returns a non-zero value when an error occurs
   CHARACTER(*),                       INTENT(  OUT)  :: ErrMsg               !< Error message if ErrStat /= ErrID_None


  INTEGER(IntKi)                                      :: I                    !< Generic loop counter

   ErrStat = ErrID_None
   ErrMsg  = ''

   DO I = 1, NUserOutputs
      IF (.NOT. foundMask(I)) THEN
         ErrMsg  = ' A requested output channel is invalid'
         CALL ProgWarn( 'The requested output channel is invalid: ' // UserOutputs(I) )
         ErrStat = ErrID_Warn
      END IF
   END DO



END SUBROUTINE PrintBadChannelWarning






!====================================================================================================
END MODULE InflowWind
