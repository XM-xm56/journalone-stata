{smcl}
{* *! version 0.2.0 16aug2026}{...}
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
issue different keys to different users (for example, {cmd:xmsz000} and
{cmd:xmsz001}); each key is checked independently.{p_end}

{pstd}
Without a valid activation, the public commands {cmd:journalone},
{cmd:journalone_prep}, {cmd:journalone_signif}, and the public output helpers
stop before running an analysis.  The three graphical pages remain available
so the user can enter the author-supplied key in their masked {bf:密钥} field.
The page validates the key through a hidden command, clears the field after a
successful check, and never writes the plaintext key into analysis outputs.{p_end}

{title:Examples}

{p 8 12 2}{cmd:. journalone_license, activate("key supplied by the author")}{p_end}
{p 8 12 2}{cmd:. journalone_license, status}{p_end}
{p 8 12 2}{cmd:. journalone}{p_end}

{title:Publisher workflow}

{pstd}
The publisher may issue multiple custom keys, such as {cmd:xmsz000} and
{cmd:xmsz001}. Keep the keys in the private Excel workbook
{cmd:journalone_private_keys.xlsx} outside the package. The worksheet
{cmd:License Keys} uses the columns
{cmd:key,user_id,status,issued_on,note}; then run the publisher-only
{cmd:build_license_allowlist.do} helper. Only active rows are authorized.
Only digest values are written into the public package. In offline mode a
changed registry requires rebuilding and republishing the package; use long,
random keys for real users rather than the short examples above.{p_end}

{title:Security scope}

{pstd}
This is a local access gate for ordinary distribution.  Stata ado files are
plain text; a technically determined recipient can edit local ado code and
bypass any fully offline check.  Strong enforcement requires a compiled
component or an online license service controlled by the author.  In offline
mode, adding a new key requires rebuilding the digest allowlist and publishing
the updated package; use long random keys rather than easy-to-guess examples
such as {cmd:xmsz000}.{p_end}
