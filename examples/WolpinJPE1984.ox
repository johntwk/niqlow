#include "WolpinJPE1984.h"
/* This file is part of niqlow. Copyright (C) 2011-2015 Christopher Ferrall */

/**Run the  replication.
**/
Fertility::Replicate()	{
	Initialize(new Fertility());
	SetClock(NormalAging,T+tau);
	decl t,PD,expbirths, EMax, tab, row, prow,Yrow, cur;
	SetDelta(delt);
	Actions(n = new ActionVariable("birth",2));
	ExogenousStates(psi = new Zvariable("psi",Ndraws));
	EndogenousStates(M = new RandomUpDown("M",Mmax,Fertility::Mortality) );
	CreateSpaces(LogitKernel,1.5);
	EMax = new ValueIteration(0);
	for (tab=0;tab<2;++tab)
		for (row=0;row<1;++row)	{ //columns(aa0)
			prow = tab ? 0 : row;
			Yrow = tab ? row : 0;
			p = exp(ab0[prow]+ab1[prow]*range(1,T))';
			p ./= 1+p;
			p |= zeros(tau,1);
			Y = exp(aa0[Yrow]+aa1[Yrow]*range(1,T+tau))';
			EMax -> Solve(0,0);
			println("------------- ",tab," ",row);
			DPDebug::outV(TRUE,0);
			PD = new PanelPrediction(0);
            PD -> Tracking(NotInData,n,M);
			PD -> TSet(20);
			PD -> Predict(Two);
//            PD -> Histogram(Two);
			println("%c",{"f"}|PD.tlabels,PD.flat);
			}
	}

/** Returns current time-specific transition probabilities. **/
Fertility::Mortality(FeasA)	{
	decl d= FeasA[][n.pos], pt= d*p[I::t],
	b =	0 ~ (1-pt) ~ pt ;
	return b;
	}

/** Return A(&theta;).
Fertility is not a feasible choice for t&gt;T-1
**/
Fertility::FeasibleActions() { return 1|(I::t<T) ; }

/** Utility. **/
Fertility::Utility() {
	decl t=I::t+1, Mv = M.v,
	     X = Y[t-1]-(b+c[1]*(t==1)+c[2]*(t==2)+(1~t~sqr(t))*c[3])*Alpha::CV(n),
		 u = AV(psi)*Mv + (Mv~sqr(Mv))*alph + (X~sqr(X))*bet + Mv*(X~Sbar)*gam;
	return u;
	}
