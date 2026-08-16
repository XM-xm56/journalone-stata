*! version 0.2.0 16aug2026 JournalOne license digest allowlist
capture program drop _journalone_license_expected
program define _journalone_license_expected, rclass
    version 16.0
    * Generated from the publisher's private key registry.  This file
    * contains digests only; plaintext keys must never be uploaded.
    return local digests "3409934968-3230556948-0431293840-1770331405|4080344385-0076711003-1138718902-4171225479|3494369123-0945089503-1382323652-2389116183"
    return local digest "3409934968-3230556948-0431293840-1770331405"
    return scalar count = 3
end
