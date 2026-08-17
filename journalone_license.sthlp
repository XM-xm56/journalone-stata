{smcl}
{* *! version 0.2.1 16aug2026}{...}
{title:Title}

{phang}
{bf:journalone_license} {hline 2} activate and inspect a local JournalOne authorization

{title:Syntax}

{p 8 12 2}{cmd:. journalone_license}{p_end}
{p 8 12 2}{cmd:. journalone_license, status}{p_end}
{p 8 12 2}{cmd:. journalone_license, activate("}{it:key}{cmd:")}{p_end}
{p 8 12 2}{cmd:. journalone_license, deactivate}{p_end}

{title:Description}

{pstd}
{cmd:journalone_license} reports whether this Stata installation has a valid
JournalOne authorization.  {cmd:activate()} validates the supplied key
against the publisher's private-key allowlist and writes a small local
license file in {cmd:c(sysdir_personal)}.  The plaintext key is not written
to that file and is not included in {cmd:journalone.pkg}.  The publisher can
issue different keys to different users.  Documentation uses the deliberately
invalid placeholders {cmd:DEMO-NOT-A-KEY-A} and {cmd:DEMO-NOT-A-KEY-B}; each
real key is checked independently.{p_end}

{pstd}
Without a valid activation, the public commands {cmd:journalone},
{cmd:journalone_prep}, {cmd:journalone_signif}, and the public output helpers
stop before running an analysis.  The three graphical pages remain available,
but every analysis, variable-selection, and data-processing control is disabled.
Only the masked {bf:密钥} field, {bf:激活并解锁}, help, and update functions remain
available.  Loading or changing a dataset never unlocks the interface.  A valid
key immediately enables the controls; the page clears the field after the check
and never writes the plaintext key into analysis outputs.{p_end}

{title:Examples}

{p 8 12 2}{cmd:. journalone_license, activate("key supplied by the author")}{p_end}
{p 8 12 2}{cmd:. journalone_license, status}{p_end}
{p 8 12 2}{cmd:. journalone}{p_end}

{title:Publisher workflow}

{pstd}
The publisher may issue multiple custom keys. Never place a real key in public
documentation or source code. Keep the keys in the private Excel workbook
{cmd:journalone_private_keys.xlsx} outside the package. The worksheet
{cmd:License Keys} uses the columns
{cmd:key,user_id,status,issued_on,note}; then run the publisher-only
{cmd:build_license_allowlist.do} helper. Only active rows are authorized.
Only digest values are written into the public package. In offline mode a
changed registry requires rebuilding and republishing the package; use long,
random keys for real users rather than short or predictable examples.{p_end}

{title:Security scope}

{pstd}
This is a local access gate for ordinary distribution.  Stata ado files are
plain text; a technically determined recipient can edit local ado code and
bypass any fully offline check.  Strong enforcement requires a compiled
component or an online license service controlled by the author.  In offline
mode, adding a new key requires rebuilding the digest allowlist and publishing
the updated package; use long random keys and keep every real key out of public
documentation, examples, logs, and generated output.{p_end}
