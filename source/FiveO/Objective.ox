#include "Objective.h"
/* This file is part of niqlow. Copyright (C) 2011-2016 Christopher Ferrall */

/** Checks the version number you send with the current version of niqlow.
@param v integer [default=200]
**/
Objective::SetVersion(v) {
    MyVersion = v;
    if (MyVersion<Version::version)
        oxwarning("FiveO Warning ??. You are running your Objective on a newer niqlow version "+sprint(Version::version)+".\n");
    if (MyVersion>Version::version)
        oxwarning("FiveO Warning ??. You are running your Objective on an older niqlow version.  You should consider installing a newer release.\n");
    }


/** Create a new objective.
@param L string, label for the objective.
@internal
**/
Objective::Objective(L)	{	
    decl i;
 	Version::Check();
	this.L = L;
	fname = classname(this)+"."+strtrim(L);
	do {
	   i=strfind(fname,' ');
	   if (i>=0) fname[i] = '_';
	   } while (i>=0);
	Psi = {};
	PsiL={};
	PsiType = {};
	Blocks = {};
	Volume = QUIET;
    RunSafe = TRUE;
    lognm = replace(Version::logdir+"Obj-"+classname(this)+"-"+L+Version::tmstmp," ","")+".log";
    logf = fopen(lognm,"aV");
    fprintln(logf,"Created");
	cur = new Point();
	hold = maxpt = NvfuncTerms  = UnInitialized;
	FinX = <>;
	p2p = once = FALSE;
	nstruct = 0;
	if (Parameter::DoNotConstrain) {
		Parameter::DoNotConstrain = FALSE;
		oxwarning("FiveO Warning 04.\n Each new objective resets Parameter::DoNotConstrain to FALSE.\n User must reset it after adding additional objectives.\n");
		}
	}

/** Reset the value of the current and maximum objective. **/
Objective::ResetMax() {
    cur.v = maxpt.v = -.Inf;
    }

/** Load or save state of the problem to a file.
@param f file object
@param saving  TRUE: save status to the file<br>FALSE: load from the file and close it, call `Objective::Encode`
**/
Objective::CheckPoint(f,saving) {
	if (saving) {
		decl fl = vararray(PsiL);
		fprintln(f,"%v",cur.X,"\n-------Human Readable Parameter Summary-------");
        decl i,j,fp;
        j=0;
        for(i=0;i<sizeof(cur.X);++i) {
            fp = (j<sizeof(FinX)) ? FinX[j]==i : 0;
            fprintln(f,"%03u",i,"\t",fp,"\t","%10.6f",cur.X[i],"\t\"","%-15s",PsiL[i],"\"\t\"","%-15s",PsiType[i],"\"\t",fp ? FinX[j] : -1,"\t",fp ? cur.F[j] : .NaN);
            j += fp;
            }
		fprintln(f,"\n------------\n","%c",PsiL[FinX],"%r",{"  Gradient  "},cur.G,"\nHessian ","%r",PsiL[FinX],"%c",PsiL[FinX],cur.H);
		}
	else {
		decl inX;
		fscan(f,"%v",&inX);
		fclose(f);
		Encode(inX);  //typo found Sept. 2014
		}
	}

Objective::Menu() {
    // Get Stage from program arguments
    // switch(Stage) {
    // case ?? :
    if (CGI::Initialize("Objective:"+L)) {
        fprintln(CGI::out,"<h2>Objective</h2><fieldset><legend>",L,"</legend>");
        fprint(CGI::out,"Run Safe? ");
        CGI::CheckBox(L+"runsafe",1,RunSafe);
        CGI::VolumeCtrl(L,Volume);
        CGI::CreateForm(Psi);
        fprintln(CGI::out,"</fieldset>");
//        }
    // case ?? :
        CGI::ReadForm(Psi);
        Encode();
        fobj(0);
    }
   }

/** Store current state (checkpoint to disk).
@param fname string, name of file<br>0 [default] use `Objective::fname`
@see Objective::Load, Objective::EXT
**/
Objective::Save(fname)	{
	decl f;
	if (isint(fname)) fname = this.fname;
	format(500);
	f = fopen(fname+"."+EXT,"w");
	if (!isfile(f)) println("File name:",fname+"."+EXT);
	fprint(f,"%v",classname(this),"\n","%v",L,"\n","%v",cur.v,"\n");
	this->CheckPoint(f,TRUE);
	fprint(f,"\n--------------------\nCreated by Objective::Save(). "+date()+". "+time());
	fclose(f);
	}
	
/** Load state of the problem.
@param fname string, name of file<br>0 [default], use the default name, the label with spaces removed<br>-1, do nothing and return FALSE.
@comment FinX is read in to set <code>DONOTVARY<code> for each parameter. The value of F is ignored by Load.  `Objective::Encode`() called by Load.
@returns TRUE if parameter values were loaded from file<br> FALSE otherwise.
@see Objective::Save, Objective::L
**/
Objective::Load(fname)	{
	decl f,n,inL,inO,inX,inFX,k,m,inPsiL,otype,mml;
	if (!sizeof(Psi)) oxrunerror("FiveO Error 29. Cannot call Load before Parameter List is created.");
	if (isint(fname)) {if (fname==UnInitialized) return FALSE; fname = this.fname;}
	f = fopen(fname+"."+EXT);
	if (!isfile(f))	{
		oxwarning("FiveO Warning 06.\n File "+fname+"."+EXT+" not found.  Load is doing nothing.\n");
		return FALSE;
		}
	if (Volume>SILENT) println(" Attempting to load from ",fname);
	n = fscan(f,"%v",&otype,"%v",&inL,"%v",&inO);
	if (otype!=classname(this)) oxwarning("FiveO Warning 07.\n Object stored in "+fname+" is of class "+otype+".  Current object is "+classname(this)+"\n");
	if (inL!=L) oxwarning("FiveO Warning 08.\n Object Label in "+fname+" is "+inL+", which is not the same as "+L+"\n");
	maxpt.v = cur.v = inO;
    this->CheckPoint(f,FALSE);
	if (Volume>SILENT) {
        println("Initial objective: ",cur.v);
        fprintln(logf,"Parameters loaded from ",fname,". # of values read: ",n,". Initial objective: ",cur.v);
		fprint(logf,"%r",PsiL,cur.X);
        }
	return TRUE;
	}

Objective::	SetAggregation(AggType) {
	hold.AggType = cur.AggType = AggType;
	}	
	
/** Store current state of a Constrained Objective (checkpoint to disk).
@param f
@param saving
@comments the value of `Objective::cur`.F is written to the file but ignored by Load().
**/
Constrained::CheckPoint(f,saving)	{
	if (saving) {
		decl fl = vararray(PsiL);
		fprint(f,"%v",cur.X,"\n","%v",fl,"\n","%v",FinX,"\n","%v",cur.F);
		fprint(f,"------------\n","%r",PsiL,cur.X,"%v",PsiType,
		"\n","%r",cur.ineq.L,"%c",{" Inequalities "},cur.ineq.v,
		"%r",cur.eq.L,"%c",{"  Equalities  "},cur.eq.v);
		}
	else {
		decl inX,inPsiL,inFX,k,m;
		fscan(f,"%v",&inX,"%v",&inPsiL,"%v",&inFX);
		fclose(f);
		if (sizer(inX)!=sizeof(Psi)) {
			oxwarning("FiveO Warning 09.\n X in "+fname+"."+EXT+" not the same length as Psi.\n Load is doing nothing.\n ");
			return FALSE;
			}
		inPsiL = varlist(inPsiL);
		if (!sizer(inFX)) inFX = <-1>;
		for (k=0,m=0;k<sizeof(Psi);m+=inFX[m]==k,++k) Psi[k].DONOTVARY= (inFX[m]!=k);			
		Encode(inX);  //typo found Sept. 2014
		}
	}
	
/** If <code>cur.v &gt; maxpt.v</code> call `Objective::Save` and update <code>maxpt</code>.
@return TRUE if maxval was updated<br>FALSE otherwise.
**/
Objective::CheckMax(fn)	{
    newmax = cur.v>maxpt.v;
    if (Volume>QUIET) {
        fprint(logf,cur.v,newmax ? "*" : " \n");
		 if (Volume>LOUD) { print(" ","%15.8f",cur.v); if (isfile(fn)) fprint(fn," ","%15.8f",cur.v); }
        }
	if (newmax)	{
		this->Save(0);
		maxpt -> Copy(cur);
		if (Volume>QUIET) {
			if (Volume<=LOUD) print(" ","%18.12f",maxpt.v);
			println("*"); if (isfile(fn)) fprintln(fn,"*");
			}
		}
	return newmax;
	}

	
/** Prints a message and details about the objective.
@param orig string, origin of the print call
@param fn integer, no print to file.<br>file, prints to file as well as screen
@param toscreen TRUE: print to screen as well
**/
Objective::Print(orig,fn,toscreen){
	decl b =sprint("\n\nReport of ",orig," on ",L,"\n",
		"%r",{"   Obj="},"%cf",{"%#18.12g"},matrix(cur.v),
		"Free Parameters",
		"%r",Flabels,"%c",{"   index  ","     free      "},"%cf",{"%6.0f","%#18.12g"},
		FinX~cur.F,
		"Actual Parameters",
		"%c",{           "     Value "},"%r",PsiL,"%cf",{"%#18.12g"},cur.X);
    if (isfile(fn)) {fprintln(fn,b); fflush(logf);}
    if (toscreen) println(b);
	}

UnConstrained::UnConstrained(L) {
	Objective(L);
	}

Constrained::Constrained(L,ELorN,IELorN) {
	Objective(L);
    delete cur;
	cur = new CPoint(ELorN,IELorN);
	hold = new CPoint(ELorN,IELorN);
	maxpt = new CPoint(ELorN,IELorN);
	maxpt.v = -.Inf;
	}

/** Create a new system of equations object.
@param L label for the system.
@param LorN  The size of the system indicated in 1 of 3 ways:<br>
integer [default = 1], N the size of the system<br>
array of length N, where each element is a string, the label for the equation.<br>
string with N space-separate labels, the labels
of the equations parsed by `varlist`.

@example
Three ways to define a <code>3x3</code> system of equations:
<pre>
 mysys = new System(3);
 mysys = new System({"A","B","C"});
 mysys = new System("Eq0 Eq2 Eq2");
</pre></dd>
@see Objective::NvfuncTerms, Equations
**/	
System::System(L,LorN) {
	Objective(L);
    cur = new SysPoint();
	hold = new SysPoint();
	maxpt = clone(hold);
	maxpt.v = -.Inf;
	eqn = new Equality(LorN);
	NvfuncTerms = eqn.N;
	}

/** Default system of equations: `Objective::vfunc`().

**/
System::equations() { 	return cur.V[] = vfunc();	}
		
/** Toggle the value of `Parameter::DoNotConstrain`.
If DoNotConstrain then all parameters except `Determined` parameters are free and unscaled.
This can improve convergence near the top of the objective.  It also means that the Hessian values are in terms
of the economic parameters not the free-to-vary optimization parameters.
**/
Objective::ToggleParameterConstraint()	{
	Parameter::DoNotConstrain = !Parameter::DoNotConstrain;
    this->Recode(FALSE);
	}

/** @internal **/ Objective::dFiniteDiff0(x) {   return maxr( (fabs(x) + SQRT_EPS) * DIFF_EPS  ~ SQRT_EPS);  }
/** @internal **/ Objective::dFiniteDiff1(x) {   return maxr( (fabs(x) + SQRT_EPS) * DIFF_EPS1 ~ SQRT_EPS); }
/** @internal **/ Objective::dFiniteDiff2(x) {   return maxr( (fabs(x) + SQRT_EPS) * DIFF_EPS2 ~ SQRT_EPS); }


/** Decode a vector of free variables.
Converts an optimized parameter vector into the structural parameter vector.  Ensure that each parameter and
each parameter block current value is updated.
@param F, nfree x 1 vector of optimized parameters.<br>0 [default], use this.F for decode
@return X, the structural parameter vector.
**/
Objective::Decode(F)	{
	decl k,m;
	 if (!isint(F))	{
		if (sizer(F)!=nfree) oxrunerror("FiveO Error 30. Cannot change length of free vector during optimization.");
	  	cur.F = F;
		}
	for (k=0;k<sizeof(Blocks);++k) Blocks[k].v = <>;
	for (m=0,k=0,cur.X=<>;k<sizeof(Psi);++k)   {
		cur.X |= (m<nfree && FinX[m]==k)
					? Psi[k]->Decode(cur.F[m++][0])
					: Psi[k]->Decode(0);
		if (!isint(Psi[k].block)) Psi[k].block.v |= cur.X[k];
		}
//	return cur.X;
	}

/** Toggle DoNotVary for one or more parameters.
@param a `Parameter` or array of parameters
@param ... more parameters or array of parameters.
**/
Objective::ToggleParams(a,...) {
    decl v, va = va_arglist()|a;
	foreach (v in va) {
        if (isarray(v)) ToggleParams(v);
        else
            v->ToggleDoNotVary();
        }
    this->Recode(FALSE);
    }

/**Reset the free parameter vector and the complete structural parameter vector.
@param HardCode  TRUE=hard-coded parameter values used.<br/>FALSE [default] Start vector used
Must be called anytime a change in constraints is made.  So it is called by `Objective::Encode`()
and `Objective::Reinitialize`()
**/
Objective::Recode(HardCode) {
	decl k,f;
    for (k=0;k<sizeof(Blocks);++k) Blocks[k].v = <>;
	for (k=0,cur.X=<>,cur.F=<>,FinX=<>,nfree=0;k<nstruct;++k) {
		Psi[k].start = Start[k];
		f = HardCode ? Psi[k]->ReInitialize() : Psi[k]->Encode();
		if (!isnan(f)) {cur.F |= f;  FinX |= k; if (nfree++) Flabels|= PsiL[k]; else Flabels = {PsiL[k]}; }
		cur.X |= Psi[k].v;
		if (!isint(Psi[k].block)) Psi[k].block.v |= Psi[k].v;
		}
    }

/** Encode vector of structural parameters.
@param inX 0 [default] get new starting values from the parameters<br>a vector, new starting values.

@comments
    <DT> if X is a vector</DT>
    <DD>then a value of .NaN means that parameter should be held fixed at the current value during this
		   cycle of optimization.</DD>
    <DT>If X=0 then the starting values are retrieved as follows:</DT>
           <DD> If this is the first call of Encode() the initial values passed to the parameters when they were created.</DD>
           <DD>If this.X already has elements then this is not the first call to <code>Encode()</code> and starting values will be retrieved from the current values of
		   parameters.</DD>

@see Objective::Recode, Objective::nfree, Objective::nstruct, Objective::FinX
**/
Objective::Encode(inX)  {
   	if (!once) {
		nstruct=sizeof(Psi); once = TRUE;
		if (NvfuncTerms==UnInitialized) {
			oxwarning("FiveO Warning 10.\n "+L+" NvfuncTerms, length of return vfunc(), not initialized. Set to 1.\n");
			NvfuncTerms = 1;
			}
		cur.V = constant(.NaN,NvfuncTerms,1);
		}
	Start = isint(inX) ? cur.X : inX;
	if (sizer(Start)!=nstruct) {
        println("In vector as ",sizer(Start)," rows.  Psi has ",nstruct);
        println("%r",PsiL,"%c",{"Read Values"},Start);
        oxrunerror("FiveO Error 31. Start vector not same length as Psi");
        }
    this->Recode(FALSE);
	}

/** Revert all parameters to their hard-coded initial values.
This routine can only be called after `Objective::Encode`() has been called.

All parameters are reset to their hard-coded initial values, stored as `Parameter::ival`.

This also sets the values of the `Objective::cur` vector, including the structural parameters
`Point::X` and free parameters `Point::F`

`Objective::ResetMax`() is called

The result is as if no optimization has occurred and `Objective::Encode`(0) has just been executed
for the first time.

**/
Objective::ReInitialize() {
   	if (!once) oxrunerror("FiveO Error 32. Cannot ReInitialize() objective parameters before calling Encode() at least once.");
    this->Recode(TRUE);
	Start = cur.X;
    ResetMax();
    Save();
    }
	
/** Compute the objective at multiple points.
@param Fmat, N<sub>f</sub>&times;J matrix of column vectors to evaluate at
@param aFvec, address of a ?&times;J matrix to return <var>f()</var> in.
@param afvec, 0 or address to return aggregated values in (as a 1 &times; J ROW vector)
@param abest, 0 or address to return index of best vector

The maximum value is also computed and checked.

@returns J, the number of function evaluations
**/
Objective::funclist(Fmat,aFvec,afvec,abest)	{
	decl j,J=columns(Fmat),best, f=zeros(J,1), fj;
	if (Volume>SILENT) fprintln(logf,"funclist ",columns(Fmat));
	if (isclass(p2p))  {          //CFMPI has been initialized
		p2p.client->ToDoList(0,Fmat,aFvec,NvfuncTerms,MultiParamVectors);
		for(j=0;j<J;++j) {
			cur.V = aFvec[0][][j];
			cur -> aggregate();
			f[j] = cur.v;
			}
		}
	else{
//Leak	foreach (fj in Fmat[][j]) {
  for (j=0;j<columns(Fmat);++j) { fj = Fmat[][j];  //Leak
			vobj(fj);
			aFvec[0][][j] = cur.V;
			cur -> aggregate();
			f[j] = cur.v;
			}
        }
    best = int(maxcindex(f));
    if (best<0) best = int(mincindex(f));  //added Oct. 2016 so that -.Inf is not treated as .NaN
	if (Volume>SILENT) fprintln(logf,"funclist finshed ",best, best>=0 ? f[best] : .NaN);
	if ( ( best < 0) ) {
        println("**** Matrix of Parameters ",Fmat,"Objective Value: ",f',"\n****");
        if (RunSafe) oxrunerror("FiveO Error 33. undefined max over function evaluation list");
        oxwarning("FiveO Warning ??. undefined max over function evaluation list");
	    best = 0;
       }
	 cur.v = f[best];
	 Decode(Fmat[][best]);
     if (!isint(abest)) abest[0]=best;
	 this->CheckMax();
     if (afvec) afvec[0] = f';
	return J;
	}

/** Compute the objective and constraints at multiple points.
@param Fmat, N<sub>f</sub>&times;J matrix of column vectors to evaluate at
@returns J, the number of function evaluations
**/
Constrained::funclist(Fmat,jake) {
	decl j,J=columns(Fmat);
	if (isclass(p2p))  {          //CFMPI has been initialized for this objective
		decl nn = NvfuncTerms~cur.ineq.N~cur.eq.N,
			 sumN = sumr(nn),
			 tmp = new matrix[sumN][J];
		p2p.client->ToDoList(0,Fmat,&tmp,NvfuncTerms,MultiParamVectors);
		jake.V[] =   tmp[0][:nn[0]-1][];
		jake.ineq.v[][] = tmp[0][nn[0]:(nn[0]+nn[1]-1)][];
		jake.eq.v[][] =   tmp[0][nn[0]+nn[1]:][];
		}
	else
		for (j=0;j<J;++j) {
			Lagrangian(Fmat[][j]);
			jake.V[][j] = cur.V;
			jake.ineq.v[][j] = cur.ineq.v;
			jake.eq.v[][j] = cur.eq.v;
			}
	return J;
	}
	
/** Decode the input, compute the objective, check the maximum.
@param F vector of free parameters.
**/
Objective::fobj(F)	{
	this->vobj(F);
	cur->aggregate();
    if (Volume>SILENT) {
        fprint(logf,"fobj = ",cur.v);
        if (Volume>QUIET) println("fobj = ",cur.v);
        }
	}

Objective::Combine(outmat) {
    oxwarning("FiveO Warning: Running default Objective in parallel mode SubProblems. ");
    return vfunc();
    }

/** Decode the input, return the whole vector.
@param F vector of free parameters.
**/
Objective::vobj(F)	{
	Decode(F);
    if (Volume>QUIET) Print("vobj",logf,Volume>LOUD);
    if (isclass(p2p)&& p2p.client.NSubProblems)
        cur.V[] = this->Combine( p2p.client->Distribute(F) );
    else
	    cur.V[] =  vfunc();
    if (Volume>QUIET) {
        fprint(logf,"vobj = ",cur.V);
        if (Volume>LOUD)  println("vobj = ",cur.V);
        }
	}

/* Decode the input, compute the objective, check the maximum.
@param F vector of free parameters.
System::fobj(F)	{
	vobj(F);
	cur->aggregate();
    if (Volume>SILENT) {
        fprint(logf,"fobj = ",cur.v);
        if (Volume>QUIET) println("fobj = ",cur.v);
        }
//	this->CheckMax();
	}
*/

/** Decode the input, return the whole vector, inequality and equality constraints, if any.
@param F vector of free parameters.
@return Array, {&fnof;,g,h};
**/
Constrained::Lagrangian(F) {
	Decode(F);
	cur.V[] = -vfunc();   // Negate objective so that SQP minimization is right
//	println("NN ",F'|cur.X',"%15.12f",cur.V);
	cur.ineq.v[] = inequality();
	cur.eq.v[] = equality();
	}

Constrained::Merit(F) {
	Lagrangian(F);
	cur->aggregate();
	cur.L = cur.v - cur.ineq->penalty() - cur.eq->norm();
	this->CheckMax();
	}

/** Compute the Jg(), vector version of the objective's Jacobian at the current vector.
@return <var>Jg(&psi;)</var> in cur.J
**/
Objective::Jacobian() {
    decl h, GradMat, ptmatrix,gg;
	Decode(0);					
	hold -> Copy(cur);	
	h = dFiniteDiff1(cur.F);
	ptmatrix = ( (cur.F+diag(h))~(cur.F-diag(h)) );
	GradMat = zeros(NvfuncTerms,2*nfree);
	Objective::funclist(ptmatrix,&GradMat,&gg);
	cur -> Copy(hold);
	Decode(0);
	cur.J = (GradMat[][:nfree-1] - GradMat[][nfree:])./(2*h');
	if (Volume>LOUD) fprintln(logf,"Gradient/Jacobian Calculation ",nfree," ",NvfuncTerms,"%15.10f","%c",{"h","fore","back","diff"},"%r",PsiL[FinX],h~(GradMat[][:nfree-1]'~(GradMat[][nfree:]')),"Jacob",cur.J');
	}
	
/** Compute the &nabla;f(), objective's gradient at the current vector.

<DT>Compute</DT>
<pre><var>&nabla; f(&psi;)</var></pre>

Stored in <code>cur.G</code>
**/
Objective::Gradient() {
	this->Jacobian();
	cur.G = sumc(cur.J);
    if (Volume>QUIET) fprintln(logf,"%r",{"Gradient: "},"%c",PsiL[FinX],cur.G);
	}

/** Compute the &nabla;f(), objective's gradient at the current vector.

<DT>Compute</DT>
<pre><var>&nabla; f(&psi;)</var></pre>

Stored in <code>cur.G</code>
**/
UnConstrained::Gradient() {
    Objective::Gradient();
	}

/** Compute the &nabla;f(), objective's gradient at the current vector.
**/
Constrained::Gradient() {
    //	this->Jacobian();
    //	cur.G = sumc(cur.J);
    Objective::Gradient();
	}

/** Compute the Hf(), Hessian of objective at the current vector.
@return <var>Hg(&psi;)</var> in cur.H
**/
Objective::Hessian() {
    decl h, GradMat, ptmatrix,gg,i,j,and,ind,jnd,b;
	Decode(0);					
	hold -> Copy(cur);	
	h = dFiniteDiff1(cur.F);
	ptmatrix = ( cur.F~(cur.F+2*diag(h))~(cur.F-2*diag(h)) );
    and = range(0,nfree-1,1)';
    for (i=0;i<nfree-1;++i) {
            ind = h.*(and.==i);
            jnd = h.*(and.==and[i+1:]');
            ptmatrix ~= cur.F + ind   + jnd
                       ~cur.F - ind   + jnd
                       ~cur.F + ind   - jnd
                       ~cur.F - ind   - jnd ;
            }
	GradMat = zeros(NvfuncTerms,columns(ptmatrix));
	Objective::funclist(ptmatrix,&GradMat,&gg);
	cur -> Copy(hold);
	Decode(0);
	cur.H = diag( (gg[1:nfree] - 2*gg[0] + gg[nfree+1:2*nfree])./(4*sqr(h')) );
    b = 2*nfree+1;
    for (i=0;i<nfree-1;++i) {
            cur.H[i][i+1:] = cur.H[i+1:][i] = (gg[b]-gg[b+1]-gg[b+2]+gg[b+3])./(4*h[i]*h[i+1:]);
            b += 4*(nfree-i-1);
            }
	}

/** Compute the Jg(), vector version of the Lagrangian's Jacobian at the current vector.
**/
Constrained::Jacobian() {
    decl h, ptmatrix, nf2 = 2*nfree;
    oxwarning("shouldn't be here!");
	Decode(0);					// F should already be set
	hold -> Copy(cur);
	h = dFiniteDiff1(cur.F)';
	ptmatrix = ( (cur.F+diag(h))~(cur.F-diag(h)) );
	h *= 2;
	decl jake = new CPoint(0,0);
	jake->Copy(cur);  //	clone(cur);
	jake.V = zeros(NvfuncTerms,nf2);
	jake.ineq.v = zeros(cur.ineq.N,nf2);
	jake.eq.v = zeros(cur.eq.N,nf2);
	funclist(ptmatrix,jake);
	cur.J =     (jake.V[][:nfree-1] -  jake.V[][nfree:])./h;
	cur.ineq.J = (jake.ineq.v[][:nfree-1] -jake.ineq.v[][nfree:])./h;
	cur.eq.J =     (jake.eq.v[][:nfree-1] -  jake.eq.v[][nfree:])./h;
	cur->Copy(hold);
	delete jake;
	Decode(0);
	}


/** Add `Parameter`s to the parameter list to be optimized over.
@param psi1 the first or next (and possibly only) parameter to add to the objective<br>
array: any argument can send an array which contains only parameters and blocks	
@param ... additional parameters and blocks to add
@see Parameter,  Objective::Psi
**/
Objective::Parameters(psi1, ... ) {
	if (once) oxrunerror("FiveO Error 33. Cannot add parameters after calling Objective::Encode()");
 	decl a, b, nxt, i, args =  isarray(psi1) ? psi1 : {psi1};
	args |= va_arglist();
    if (!sizeof(args)) oxwarning("FiveO Warning??.  Parameters called with an empty list");
	for(a=0;a<sizeof(args);++a) {
		nxt = isarray(args[a]) ? args[a] : {args[a]};
		for(i=0;i<sizeof(nxt);++i) {
			if (isclass(nxt[i],"ParameterBlock")) {
				nxt[i].pos = sizeof(Blocks);
				Blocks |= nxt[i];
				for (b=0;b<sizeof(nxt[i].Psi);++b) {
					Parameters(nxt[i].Psi[b]);
					nxt[i].Psi[b].block = nxt[i];
//					nxt[i].Psi[b]=0;  //avoid ping-pong referencing between psi's and block
					}
				}
			else if (isclass(nxt[i],"Parameter")) {
				if(nxt[i].pos!=UnInitialized) oxrunerror("FiveO Error 34. Parameter "+nxt[i].L+" already added to objective.");
				nxt[i].pos = sizeof(Psi);
				Psi |= nxt[i];
				if (sizeof(PsiL))
					{ PsiL |= nxt[i].L; PsiType |= classname(nxt[i]);}
				else
					{PsiL = {nxt[i].L}; PsiType = {classname(nxt[i])};}
				cur.X |= nxt[i].v;
				}
			else
				oxrunerror("FiveO Error 34. Argument not of Parameter Class");
			}
		}
	}

/** Built in objective, f(&psi;).
Prints a warning once and then returns 0.
**/
Objective::vfunc(subp) {
	if (!Warned) {
        Warned=TRUE; oxwarning("FiveO Warning 11.\n Using default objective which equals 0.0.\n  Your derived objective should provide a replacement for vfunc().\n ");
        }
	return <0>;	
	}

/** Default Equality Constraints.
@return empty vector
**/
Constrained::equality() 	{ return <>; }

/** Default InEquality Constraints.
@return empty vector
**/
Constrained::inequality() 	{ return <>; }

CPoint::Vec() {	return vec(V)|vec(ineq.v)|vec(eq.v);	}

/** Graph the level curves of the objective in two parameters.
@param Npts  integer [default=100], number of points to evaluate in each dimensions
@param Xpar `Parameter` for the x axis
@param Ypar `Parameter` for the y axis
@param lims 2&times;2 matrix of upper and lower bounds for axes
@
**/
Objective::contour(Npts,Xpar,Ypar,lims) {
    decl xv,yv,
    df = lims[][hi]-lims[][lo],
    ptsx = lims[xax][lo] + df[xax].*(range(0,Npts-1)'/(Npts-1)),
    ptsy = lims[yax][lo] + df[yax].*(range(0,Npts-1)'/(Npts-1)),
    grid = <>,
    myF = cur.F;
    foreach(xv in ptsx)
        foreach(yv in ptsy) {
            myF[Xpar.v] = xv;
            myF[Ypar.v] = yv;
            fobj(myF);
            grid |= xv~yv~cur.v;
            }
    grid[][zax] -= minc(grid[][zax]);  // paths are plotted on same plane as level curves

    //plotting the surface, 1 is the 3d mesh , 2 is the contour plot
    DrawXYZ(0,grid[][xax],grid[][yax],grid[][zax],1);
    DrawXYZ(0,grid[][xax],grid[][yax],grid[][zax],2);
    DrawAdjust(ADJ_AREA_Z,0,0,maxc(grid[][zax]));
    }

/*
Objective::contour(Npts,lims) {
    decl xv,yv,
    df = lims[][hi]-lims[][lo],
    ptsx = lims[xax][lo] + df[xax].*(range(0,Npts-1)'/(Npts-1)),
    ptsy = lims[yax][lo] + df[yax].*(range(0,Npts-1)'/(Npts-1)),
    grid = <>;
    foreach(xv in ptsx)
        foreach(yv in ptsy) {
            grid |= xv~yv~vobj(xv|yv);
            }
    grid[][zax] -= minc(grid[][zax]);  // paths are plotted on same plane as level curves

    //plotting the surface, 1 is the 3d mesh , 2 is the contour plot
    DrawXYZ(0,grid[][xax],grid[][yax],grid[][zax],1);
    DrawXYZ(0,grid[][xax],grid[][yax],grid[][zax],2);
    DrawAdjust(ADJ_AREA_Z,0,0,maxc(grid[][zax]));
    }
*/
