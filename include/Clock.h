#import "StateVariable"

/** Base class for members of a `Clock` block.**/
struct TimeVariable : Coevolving {	
	TimeVariable(L,N);
	}

/** Base class for timing in DP models.
@comment The user often does not need to create this variable directly.  Instead, use the `DP::SetClock` routine.  Some methods do require the user to create a clock variable and send it
to SetClock.
**/
struct Clock : StateBlock {
	const decl
		/** <var>t</var>, current `TimeVariable`  **/						t,
		/** <var>t'</var>, next period `TimeVariable` used during
			V iteration to track possible clock values next period. **/		tprime,
		/** Store Ergodic Distribution. **/ 								IsErgodic;
		/* decl ts, Nsub, MainT */
	Clock(Nt,Ntprime);
	/* SubPeriods(Nsub) ;*/
	}

/**Timing in a stationary environment.
<dd class="example"><pre>

</pre></dd>
**/
struct Stationary : Clock	{
	Stationary(IsErgodic);
	Transit(FeasA);
	virtual Last();
	}
	
struct NonStationary : Clock {
	virtual Last();
	}
	
/**Timing in an ordinary finite horizon environment.

**/
struct Aging : NonStationary	{
	Aging(T);
	Transit(FeasA);
	virtual Last();
	}

/**A static one-shot program.
**/
struct StaticP : Aging {
	StaticP();
	}
	
/** Time increments randomly, with probability equal to inverse of bracket length.
@example Represent a lifecycle as a sequence of 10 periods that last on average 5 years:
<pre>AgeBrackets(constant(5,1,10));</pre>
Model decisions each year for last five years before retirement, every five years for 15 years, then every 10 years for 30 years:
<pre>AgeBrackets(<[3]10,[3]5,[5]1>);</pre>
</dd>
**/
struct AgeBrackets : NonStationary	{
	/**Vector of period lengths for each age **/	const	decl Brackets;
	/**Transition matrix based on Brackets   **/ 			decl TransMatrix;
	AgeBrackets(Brackets);
	Transit(FeasA);
	virtual Last();
	}

/** Deterministic aging with random early death.
**/
struct Mortality : NonStationary {
	/**static mortality prob. function **/	const	decl 	MortProb;
	/** EV at t=T-1, value of death **/				decl 	DeathV;		
	Mortality(T,MortProb);
	Transit(FeasA);
	}

/** Random mortality and uncertain lifetime.
This combines a special case of `AgeBrackets` and a variation on  `Mortality` where value of death is 0 but
the probability of death is not zero at T.
**/
struct Longevity : NonStationary {
	/**static mortality prob. function **/	const	decl 	MortProb;
	/** EV at t=T-1, value of death **/				decl 	DeathV;		
	Longevity(T,MortProb);
	Transit(FeasA);
	}
	
/** A sequence of treatment phases with fixed maximum durations.

**/
struct PhasedTreatment : Clock 	{
	const decl
	/** Vector of positive integers that are the
		length of each of the phases. **/ 		Rmaxes,
	/** The last treatment phase
	(0 if no treatment) **/ 					MaxF,
	/** The index into the vector of the state
	    variable that are the first period
		of each phase          **/ 				R0,
												LastPhase,
    /**vector of times in phases  **/  			ftime,
	/**vector of phases           **/   		phase,
	/**indicates time=Rmax in phase**/			final;
	
	PhasedTreatment(Rmaxes,IsErgodic);
	virtual Transit(FeasA);
	}
