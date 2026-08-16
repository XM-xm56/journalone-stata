*! version 0.8.0 15aug2026

capture program drop _journalone_post_current
program define _journalone_post_current
    version 16.0
    syntax , HANDLE(name) RUNID(string) SPEC(string) OUTCOME(string) [LEVEL(real 95)]

    tempname bmat vmat
    matrix `bmat' = e(b)
    matrix `vmat' = e(V)
    local terms : colfullnames `bmat'
    local columns = colsof(`bmat')

    scalar __jo_n = e(N)
    scalar __jo_df = .
    capture scalar __jo_df = e(df_r)
    scalar __jo_r2 = .
    capture scalar __jo_r2 = e(r2)
    if missing(__jo_r2) capture scalar __jo_r2 = e(r2_w)
    scalar __jo_r2_a = .
    capture scalar __jo_r2_a = e(r2_a)
    if missing(__jo_r2_a) capture scalar __jo_r2_a = e(r2_a_within)
    scalar __jo_tail = (100-`level')/200

    forvalues column = 1/`columns' {
        local term : word `column' of `terms'
        scalar __jo_beta = `bmat'[1,`column']
        scalar __jo_se = sqrt(`vmat'[`column',`column'])
        scalar __jo_stat = cond(__jo_se>0, __jo_beta/__jo_se, .)
        if missing(__jo_df) {
            scalar __jo_p = 2*normal(-abs(__jo_stat))
            scalar __jo_crit = invnormal(1-__jo_tail)
        }
        else {
            scalar __jo_p = 2*ttail(__jo_df, abs(__jo_stat))
            scalar __jo_crit = invttail(__jo_df, __jo_tail)
        }
        scalar __jo_low = __jo_beta - __jo_crit*__jo_se
        scalar __jo_high = __jo_beta + __jo_crit*__jo_se
        post `handle' ("`runid'") ("`spec'") ("`outcome'") (`column') ("`term'") ///
            (__jo_beta) (__jo_se) (__jo_p) (__jo_low) (__jo_high) (__jo_n) (__jo_r2) (__jo_r2_a)
    }
end
