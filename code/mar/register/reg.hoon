::  mar/register/reg: one registration, at /regs/<rid>.
::
::    Stored as [%1 reg] (see +stored-reg in lib/register). A noun
::    passthrough: the shape ladder lives in +read-reg, so a later
::    shape never booms a stored grub.
::
|_  n=*
++  grad  %noun
++  grow
  |%
  ++  noun  n
  --
++  grab
  |%
  ++  noun  *
  --
--
