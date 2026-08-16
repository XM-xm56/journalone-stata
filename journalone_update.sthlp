{smcl}
{* *! version 0.1.0 16aug2026}{...}
{title:Title}

{phang}
{bf:journalone_update} {hline 2} update JournalOne from its original installation source

{title:Syntax}

{p 8 12 2}{cmd:. journalone_update}{p_end}
{p 8 12 2}{cmd:. journalone_update, from("}{it:directory_or_url}{cmd:")}{p_end}

{title:Description}

{pstd}
{cmd:journalone_update} reads the source recorded by the most recent
{cmd:net install journalone}, downloads the current public package, and
replaces the installed files. It does not require JournalOne activation and
does not modify the dataset in memory. The current dialog should be closed and
reopened after a successful update. No manual {cmd:net install} command is
required.{p_end}

{pstd}
The optional {cmd:from()} setting overrides the recorded source. Publishers
should keep the same HTTPS package address across releases so the one-click
button continues to work. The private Excel key registry is never downloaded
by this command.{p_end}

{title:Examples}

{p 8 12 2}{cmd:. journalone_update}{p_end}
{p 8 12 2}{cmd:. journalone_update, from("https://example.com/stata/journalone")}{p_end}

{title:Security}

{pstd}
An update can only be as trustworthy as its source. Use an HTTPS address under
the publisher's control. JournalOne updates replace public package files only;
the publisher must not upload {cmd:journalone_private_keys.xlsx}.{p_end}
