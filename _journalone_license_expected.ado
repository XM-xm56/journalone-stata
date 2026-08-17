*! version 0.2.1 16aug2026 JournalOne license digest allowlist
capture program drop _journalone_license_expected
program define _journalone_license_expected, rclass
    version 16.0
    * Generated from the publisher's private key registry.  This file
    * contains digests only; plaintext keys must never be uploaded.
    return local digests "3409934968-3230556948-0431293840-1770331405|1002459027-2232825020-3304140756-1439744211|1464330253-3144673838-0935909047-3439241008|3187255041-2397984506-0442010107-3061385113|1639065325-2172574177-2393610442-0063717301|3130485774-2632077459-0740600567-2720906315|3861376202-0626714582-3718050271-2276847671"
    return local digest "3409934968-3230556948-0431293840-1770331405"
    return scalar count = 7
end
