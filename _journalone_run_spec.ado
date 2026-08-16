*! version 0.4.0 14aug2026

capture program drop _journalone_run_spec
program define _journalone_run_spec, rclass
    version 16.0
    syntax , HANDLE(name) RUNID(string) SPEC(string) MODEL(string)       ///
        DEPVAR(string) [ INDEPVARS(string) CONTROLS(string)           ///
        PANEL(string) TIME(string) ABSORB(string) TIMEFE               ///
        VCETYPE(string) CLUSTER(string) TREAT(string) POSTVAR(string)  ///
        ENDOG(string) INSTRUMENTS(string) IFCOND(string)               ///
        LEVEL(real 95) ]

    local timefeopt ""
    if "`timefe'" != "" local timefeopt "timefe"
    capture noisily _journalone_fit, model("`model'") depvar("`depvar'") ///
        indepvars(`"`indepvars'"') controls(`"`controls'"')            ///
        panel("`panel'") time("`time'") absorb(`"`absorb'"')          ///
        vcetype("`vcetype'") cluster("`cluster'")                     ///
        treat("`treat'") postvar("`postvar'") endog(`"`endog'"')     ///
        instruments(`"`instruments'"') ifcond(`"`ifcond'"') `timefeopt'
    local rc = _rc
    if `rc' {
        noisily display as error "规格 `spec' 失败，返回码 `rc'"
        return scalar rc = `rc'
        exit
    }
    _journalone_post_current, handle(`handle') runid("`runid'") ///
        spec("`spec'") outcome("`depvar'") level(`level')
    return scalar rc = 0
end
