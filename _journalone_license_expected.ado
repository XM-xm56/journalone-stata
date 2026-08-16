*! version 0.2.1 16aug2026 JournalOne license digest allowlist
capture program drop _journalone_license_expected
program define _journalone_license_expected, rclass
    version 16.0
    * Generated from the publisher's private key registry.  This file
    * contains digests only; plaintext keys must never be uploaded.
    return local digests "3409934968-3230556948-0431293840-1770331405|3620021521-2902073957-0885942095-3569399085|1002459027-2232825020-3304140756-1439744211"
    return local digest "3409934968-3230556948-0431293840-1770331405"
    return scalar count = 3
end
