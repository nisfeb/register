::  register: the model, pure. See docs/superpowers/specs/2026-09-17-register-design.md.
::
::    Import-free on purpose: the same file builds in the clay desk's
::    /lib, where -test reaches it, and in the app's code namespace,
::    where the nexus wraps it. Nothing here touches a ship: no bowl,
::    no roads, no vases.
::
|%
::  ==  the shapes
::
+$  days     [fri=? sat=? sun=?]
+$  checkin  [at=@da by=@t]
+$  person
  $:  first=@t
      last=@t
      child=?
      =days
      sun-ten=?                                 ::  full track sunday: 10 miles, else 2.5
      social-fri=?
      social-sat=?
      mass-fri=?
      holy-hour=?
      bus=?
      first-bsc=?
      knight-dame=?
      volunteer=?
      checkins=(map @tas checkin)               ::  %fri %sat %sun
  ==
+$  contact  [email=@t phone=@t street=@t city=@t state=@t zip=@t]
+$  payment
  $:  method=@tas                               ::  %none %stripe %check %cash %assistance %stub %other
      amount=@ud                                ::  cents, the fees
      gift=@ud                                  ::  cents, above the fees
      at=(unit @da)
      ref=@t                                    ::  the stripe session, a check number
      refunded=?
      note=@t
  ==
+$  waiver
  $:  method=@tas                               ::  %none %docusign %paper %stub
      envelope=@t
      status=@tas                               ::  %none %sent %completed %declined
      at=(unit @da)
  ==
+$  step   [at=@da by=@t what=@t]
::  what a form carries: everything a pilgrim may set
+$  input  [track=@tas =contact org=@t why=@t assistance=? together=? people=(list person)]
+$  reg
  $:  id=@ta
      status=@tas                               ::  see +transition-ok
      track=@tas                                ::  %full %bambino
      source=@tas                               ::  %web %admin
      created=@da
      updated=@da
      =contact
      org=@t
      why=@t
      assistance=?
      together=?
      people=(list person)
      =payment
      =waiver
      token=@t
      position=@ud                              ::  on the wait list, else 0
      notes=@t
      history=(list step)
      exempt=?                                  ::  an organizer's mark: outside the track caps
      prior=@tas                                ::  the status a cancel left, for reinstate
  ==
::  +$reg-1: the shape before exempt and prior. +read-reg lifts it.
::
+$  reg-1
  $:  id=@ta
      status=@tas
      track=@tas
      source=@tas
      created=@da
      updated=@da
      =contact
      org=@t
      why=@t
      assistance=?
      together=?
      people=(list person)
      =payment
      =waiver
      token=@t
      position=@ud
      notes=@t
      history=(list step)
  ==
::  what the grub holds: a version head, so a later shape is told apart
::  by the reader instead of clamming by luck
::
+$  stored-reg    [%2 =reg]
+$  stored-reg-1  [%1 old=reg-1]
::  +$bundle: a whole backup. Every registration entire, with its token,
::  and the three documents as they stand.
::
+$  bundle  [%1 regs=(list reg) settings=json copy=json counts=json]
::  the settings the code reads. Everything else in settings.json (the
::  organizations, the provider credentials) stays JSON.
::
+$  settings
  $:  fees=[full=@ud bambino=@ud]
      caps=[full=@ud bambino=@ud social-fri=@ud social-sat=@ud late=@ud]
      hold=@dr
      open=(unit @da)
      close=(unit @da)
      cutoff=(unit @da)
      mode=@tas                                 ::  %live or %stub
  ==
+$  counts  [full=@ud bambino=@ud social-fri=@ud social-sat=@ud late=@ud waitlist=@ud]
::  ==  caps, the spec's
::
++  max-email    200
++  max-phone    40
++  max-street   200
++  max-city     100
++  max-state    40
++  max-zip      20
++  max-org      120
++  max-why      2.000
++  max-name     80
++  max-notes    2.000
++  max-by       64
++  max-party    12
++  max-history  200
++  max-log      2.000
++  max-copy     4.000
::  ==  time
::
::  +de-iso: "2026-09-16T22:05:00Z" (a fraction is allowed and dropped,
::  Z only) to a @da, or ~. A day the month does not have is refused.
::
++  de-iso
  |=  t=@t
  ^-  (unit @da)
  =/  two   (bass 10 (stun [2 2] dit))
  =/  four  (bass 10 (stun [4 4] dit))
  =/  rule
    ;~  plug
      four
      ;~(pfix hep two)
      ;~(pfix hep two)
      ;~(pfix (just 'T') two)
      ;~(pfix col two)
      ;~(pfix col two)
      (punt ;~(pfix dot (plus dit)))
      (cold ~ (just 'Z'))
    ==
  =/  got  (rush t rule)
  ?~  got  ~
  =/  [y=@ud mo=@ud d=@ud h=@ud mi=@ud s=@ud *]  u.got
  ?.  ?&  (gte mo 1)   (lte mo 12)
          (gte d 1)    (lte d 31)
          (lth h 24)   (lth mi 60)  (lth s 60)
      ==
    ~
  =/  when=@da  (year [[& y] mo d h mi s ~])
  ?.  =((end [3 10] (en-iso when)) (end [3 10] t))  ~
  `when
::  +en-iso: a @da to "2026-09-16T22:05:00Z", whole seconds
::
++  en-iso
  |=  when=@da
  ^-  @t
  =/  [[* y=@ud] mo=@ud [d=@ud h=@ud mi=@ud s=@ud *]]  (yore when)
  =/  yy=tape  ((d-co:co 4) y)
  =/  mm=tape  ((d-co:co 2) mo)
  =/  dd=tape  ((d-co:co 2) d)
  =/  hh=tape  ((d-co:co 2) h)
  =/  ii=tape  ((d-co:co 2) mi)
  =/  ss=tape  ((d-co:co 2) s)
  (crip "{yy}-{mm}-{dd}T{hh}:{ii}:{ss}Z")
::  ==  ids, from entropy the caller fetched
::
::  +hex-of: len lowercase hex digits of the low bits of n
::
++  hex-of
  |=  [n=@ len=@ud]
  ^-  @t
  (crip ((x-co:co len) (end [0 (mul 4 len)] n)))
++  rid-from    |=(eny=@ ^-(@ta `@ta`(hex-of eny 10)))
++  token-from  |=(eny=@ ^-(@t (hex-of (rsh [0 64] eny) 32)))
::  +ok-rid: ten lowercase hex digits
::
++  ok-rid
  |=  t=@t
  ^-  ?
  =/  tap=tape  (trip t)
  ?.  =(10 (lent tap))  |
  %+  levy  `tape`tap
  |=(c=@ |(&((gte c '0') (lte c '9')) &((gte c 'a') (lte c 'f'))))
::  +one-of: is this string one of the ones we allow
::
++  one-of  |=([t=@t opts=(list @t)] ^-(? (lien opts |=(o=@t =(o t)))))
::  +statuses: every status a registration may hold
::
++  statuses
  ^-  (list @t)
  ~['draft' 'waitlist' 'waiver' 'payment' 'assistance' 'complete' 'cancelled']
::  ==  json, read without crashing
::
++  gj                                          ::  a key's value, or null
  |=  [jon=json k=@t]
  ^-  json
  ?.  ?=([%o *] jon)  ~
  (fall (~(get by p.jon) k) ~)
++  has-key
  |=  [jon=json k=@t]
  ^-  ?
  ?.  ?=([%o *] jon)  |
  (~(has by p.jon) k)
++  gs                                          ::  a string, or ''
  |=  [jon=json k=@t]
  ^-  @t
  =/  v=json  (gj jon k)
  ?:(?=([%s *] v) p.v '')
++  gn                                          ::  a whole number
  |=  [jon=json k=@t]
  ^-  (unit @ud)
  =/  v=json  (gj jon k)
  ?.  ?=([%n *] v)  ~
  (rush p.v dem)
++  gb                                          ::  a boolean, false when absent
  |=  [jon=json k=@t]
  ^-  ?
  =/  v=json  (gj jon k)
  ?:(?=([%b *] v) p.v |)
++  ga                                          ::  an array's items, or ~
  |=  [jon=json k=@t]
  ^-  (list json)
  =/  v=json  (gj jon k)
  ?:(?=([%a *] v) p.v ~)
++  gt                                          ::  an ISO time
  |=  [jon=json k=@t]
  ^-  (unit @da)
  =/  s=@t  (gs jon k)
  ?:(=('' s) ~ (de-iso s))
++  strings                                     ::  the strings in an array
  |=  l=(list json)
  ^-  (list @t)
  (murn l |=(j=json ?:(?=([%s *] j) `p.j ~)))
++  en-time        |=(d=@da ^-(json s+(en-iso d)))
++  en-maybe-time  |=(d=(unit @da) ^-(json ?~(d ~ (en-time u.d))))
++  en-num         |=(n=@ud ^-(json (numb:enjs:format n)))
::  ==  decoders: a request's JSON to a shape, or the field that failed
::
::  +over-cap: a string longer than max bytes
::
++  over-cap  |=([t=@t max=@ud] ^-(? (gth (met 3 t) max)))
::  +str-field: read a string, refusing one over its cap; strict refuses
::  an empty one too
::
++  str-field
  |=  [jon=json k=@t max=@ud strict=? label=@t]
  ^-  (each @t @t)
  =/  v=@t  (gs jon k)
  ?:  (over-cap v max)  [%| (rap 3 label ': over ' (crip (a-co:co max)) ' bytes' ~)]
  ?:  &(strict =('' v))  [%| (rap 3 label ': required' ~)]
  [%& v]
::  +is-email: something@something.something, loosely
::
++  is-email
  |=  t=@t
  ^-  ?
  =/  tap=tape  (trip t)
  =/  at=(unit @ud)  (find "@" tap)
  ?~  at  |
  ?:  =(0 u.at)  |
  =/  dom=tape  (slag +(u.at) tap)
  =/  dot=(unit @ud)  (find "." dom)
  ?~  dot  |
  &((gth u.dot 0) (lth +(u.dot) (lent dom)))
::  +de-contact: strict is a submit (every field, a real email); a draft
::  needs only an email or a phone
::
++  de-contact
  |=  [jon=json strict=?]
  ^-  (each contact @t)
  =/  em  (str-field jon 'email' max-email strict 'email')
  ?:  ?=(%| -.em)  [%| p.em]
  ?:  &(strict !(is-email p.em))  [%| 'email: not an email address']
  =/  ph  (str-field jon 'phone' max-phone strict 'phone')
  ?:  ?=(%| -.ph)  [%| p.ph]
  =/  sr  (str-field jon 'street' max-street strict 'street')
  ?:  ?=(%| -.sr)  [%| p.sr]
  =/  ci  (str-field jon 'city' max-city strict 'city')
  ?:  ?=(%| -.ci)  [%| p.ci]
  =/  sa  (str-field jon 'state' max-state strict 'state')
  ?:  ?=(%| -.sa)  [%| p.sa]
  =/  zi  (str-field jon 'zip' max-zip strict 'zip')
  ?:  ?=(%| -.zi)  [%| p.zi]
  ?:  &(!strict =('' p.em) =('' p.ph))
    [%| 'contact: an email or a phone number is required']
  [%& [p.em p.ph p.sr p.ci p.sa p.zi]]
::  +de-person: one person, at index i for the error's name. Check-ins
::  are never read from input; the caller keeps the stored ones.
::
++  de-person
  |=  [jon=json strict=? i=@ud]
  ^-  (each person @t)
  =/  pre=@t  (rap 3 'people.' (crip (a-co:co i)) '.' ~)
  =/  fi  (str-field jon 'first' max-name strict (cat 3 pre 'first'))
  ?:  ?=(%| -.fi)  [%| p.fi]
  =/  la  (str-field jon 'last' max-name strict (cat 3 pre 'last'))
  ?:  ?=(%| -.la)  [%| p.la]
  =/  dj=json  (gj jon 'days')
  :-  %&
  :*  p.fi
      p.la
      (gb jon 'child')
      [(gb dj 'fri') (gb dj 'sat') (gb dj 'sun')]
      (gb jon 'sun_ten')
      (gb jon 'social_fri')
      (gb jon 'social_sat')
      (gb jon 'mass_fri')
      (gb jon 'holy_hour')
      (gb jon 'bus')
      (gb jon 'first_bsc')
      (gb jon 'knight_dame')
      (gb jon 'volunteer')
      ~
  ==
::  +de-people: every person, or the first that failed
::
++  de-people
  |=  [raw=(list json) strict=? i=@ud acc=(list person)]
  ^-  (each (list person) @t)
  ?~  raw  [%& (flop acc)]
  =/  got  (de-person i.raw strict i)
  ?:  ?=(%| -.got)  [%| p.got]
  (de-people t.raw strict +(i) [p.got acc])
::  +together: everyone after the first takes the first's choices. Names,
::  child, first camino, knight or dame and volunteer stay their own.
::
++  together
  |=  people=(list person)
  ^-  (list person)
  ?~  people  ~
  =/  lead=person  i.people
  :-  lead
  %+  turn  t.people
  |=  p=person
  %_  p
    days        days.lead
    sun-ten     sun-ten.lead
    social-fri  social-fri.lead
    social-sat  social-sat.lead
    mass-fri    mass-fri.lead
    holy-hour   holy-hour.lead
    bus         bus.lead
  ==
::  +de-input: the form. strict is a submit or an edit; a draft is not.
::
++  de-input
  |=  [jon=json strict=?]
  ^-  (each input @t)
  ?.  ?=([%o *] jon)  [%| 'a JSON object is required']
  =/  track=@t  (gs jon 'track')
  ?.  ?=(?(%full %bambino) track)  [%| 'track: full or bambino']
  =/  ct  (de-contact (gj jon 'contact') strict)
  ?:  ?=(%| -.ct)  [%| p.ct]
  =/  org  (str-field jon 'org' max-org | 'org')
  ?:  ?=(%| -.org)  [%| p.org]
  =/  why  (str-field jon 'why' max-why | 'why')
  ?:  ?=(%| -.why)  [%| p.why]
  =/  raw=(list json)  (ga jon 'people')
  ?:  &(strict ?=(~ raw))  [%| 'people: at least one person']
  ?:  (gth (lent raw) max-party)  [%| (rap 3 'people: over ' (crip (a-co:co max-party)) ~)]
  =/  ps  (de-people raw strict 0 ~)
  ?:  ?=(%| -.ps)  [%| p.ps]
  =/  tog=?  (gb jon 'together')
  =/  people=(list person)  ?:(tog (together p.ps) p.ps)
  [%& [track p.ct p.org p.why (gb jon 'assistance') tog people]]
::  +keep-checkins: an edit replaces the people but keeps each position's
::  check-ins, so a name fix on the beach does not lose a day
::
++  keep-checkins
  |=  [old=(list person) new=(list person)]
  ^-  (list person)
  ?~  new  ~
  ?~  old  new
  [i.new(checkins checkins.i.old) $(old t.old, new t.new)]
::  ==  settings
::
++  de-settings
  |=  jon=json
  ^-  settings
  =/  fj=json  (gj jon 'fees')
  =/  cj=json  (gj jon 'caps')
  =/  wj=json  (gj jon 'window')
  =/  hours=@ud  (fall (gn jon 'hold_hours') 48)
  =/  mode=@t  (gs (gj jon 'providers') 'mode')
  :*  :*  (fall (gn fj 'full') 7.500)
          (fall (gn fj 'bambino') 2.500)
      ==
      :*  (fall (gn cj 'full') 325)
          (fall (gn cj 'bambino') 25)
          (fall (gn cj 'social_fri') 300)
          (fall (gn cj 'social_sat') 200)
          (fall (gn cj 'late_adds') 50)
      ==
      (mul hours ~h1)
      (gt wj 'open')
      (gt wj 'close')
      (gt wj 'change_cutoff')
      ?:(=('live' mode) %live %stub)
  ==
++  window-open
  |=  [s=settings now=@da]
  ^-  ?
  ?&  ?~(open.s & (gte now u.open.s))
      ?~(close.s & (lth now u.close.s))
  ==
++  changes-open
  |=  [s=settings now=@da]
  ^-  ?
  ?~(cutoff.s & (lth now u.cutoff.s))
::  ==  fees
::
::  +walks: a person who needs a spot on the track
::
++  walks
  |=  [track=@tas p=person]
  ^-  ?
  ?:  =(%bambino track)  sun.days.p
  |(fri.days.p sat.days.p sun.days.p)
++  walkers
  |=  [track=@tas people=(list person)]
  ^-  @ud
  (lent (skim people |=(p=person (walks track p))))
::  +fee: the track fee, walker or not. A non-walker registers, pays and
::  attends the socials like anyone; only the cap ignores them.
::
++  fee
  |=  [s=settings track=@tas p=person]
  ^-  @ud
  ?:(=(%bambino track) bambino.fees.s full.fees.s)
++  fees-total
  |=  [s=settings r=reg]
  ^-  @ud
  (roll (turn people.r |=(p=person (fee s track.r p))) add)
::  ==  the cap fold
::
::  +counted: does this registration hold spots right now? Complete and
::  assistance always; a waiver or payment hold only within the hold
::  window, unless an organizer made it.
::
++  counted
  |=  [s=settings r=reg now=@da]
  ^-  ?
  ?+  status.r  |
    ?(%complete %assistance)  &
    ?(%waiver %payment)  |(=(%admin source.r) (lth now (add updated.r hold.s)))
  ==
++  tally
  |=  [s=settings regs=(list reg) now=@da]
  ^-  counts
  =|  c=counts
  |-  ^-  counts
  ?~  regs  c
  =/  r=reg  i.regs
  ?:  =(%waitlist status.r)  $(regs t.regs, c c(waitlist +(waitlist.c)))
  ?.  (counted s r now)  $(regs t.regs)
  =/  w=@ud  (walkers track.r people.r)
  =/  sf=@ud  (lent (skim people.r |=(p=person social-fri.p)))
  =/  ss=@ud  (lent (skim people.r |=(p=person social-sat.p)))
  =/  c2=counts  c(social-fri (add social-fri.c sf), social-sat (add social-sat.c ss))
  ::  an exempt party attends the socials and counts against no track cap
  ?:  exempt.r  $(regs t.regs, c c2)
  ?:  =(%admin source.r)  $(regs t.regs, c c2(late (add late.c2 w)))
  ?:  =(%bambino track.r)  $(regs t.regs, c c2(bambino (add bambino.c2 w)))
  $(regs t.regs, c c2(full (add full.c2 w)))
::  +decide-submit: a spot or the wait list
::
++  decide-submit
  |=  [s=settings c=counts track=@tas people=(list person)]
  ^-  ?(%waiver %waitlist)
  =/  w=@ud  (walkers track people)
  ?:  =(0 w)  %waiver
  ?:  =(%bambino track)
    ?:((lte (add bambino.c w) bambino.caps.s) %waiver %waitlist)
  ?:((lte (add full.c w) full.caps.s) %waiver %waitlist)
::  +room-for: does this registration have a spot right now? A counted
::  hold has it by definition. A lapsed one is decided again against
::  the tree without itself, exactly like a fresh submit.
::
++  room-for
  |=  [s=settings regs=(list reg) r=reg now=@da]
  ^-  ?
  ?:  (counted s r now)  &
  =/  others=(list reg)  (skip regs |=(o=reg =(id.r id.o)))
  =(%waiver (decide-submit s (tally s others now) track.r people.r))
::  +position-of: where a wait listed registration stands, oldest
::  first, ties broken by id. 0 when it is not on the wait list.
::
++  position-of
  |=  [regs=(list reg) r=reg]
  ^-  @ud
  ?.  =(%waitlist status.r)  0
  %+  add  1
  %-  lent
  %+  skim  regs
  |=  o=reg
  ?.  =(%waitlist status.o)  |
  ?:  (lth created.o created.r)  &
  &(=(created.o created.r) (lth id.o id.r))
::  +socials-ok: ~, or the social that is sold out
::
++  socials-ok
  |=  [s=settings c=counts people=(list person)]
  ^-  (unit @t)
  =/  sf=@ud  (lent (skim people |=(p=person social-fri.p)))
  =/  ss=@ud  (lent (skim people |=(p=person social-sat.p)))
  ?:  (gth (add social-fri.c sf) social-fri.caps.s)  `'social_fri: sold out'
  ?:  (gth (add social-sat.c ss) social-sat.caps.s)  `'social_sat: sold out'
  ~
::  ==  the status machine
::
++  transition-ok
  |=  [from=@tas to=@tas]
  ^-  ?
  ?+  from  |
    %draft       ?=(?(%waitlist %waiver) to)
    %waitlist    ?=(?(%waiver %cancelled) to)
    %waiver      ?=(?(%payment %assistance %waitlist %cancelled) to)
    %payment     ?=(?(%complete %waitlist %cancelled) to)
    %assistance  ?=(?(%complete %payment %cancelled) to)
    %complete    ?=(%cancelled to)
    %cancelled   ?=(?(%waitlist %waiver %payment %assistance %complete) to)
  ==
++  after-waiver  |=(r=reg ^-(@tas ?:(assistance.r %assistance %payment)))
++  active        |=(r=reg ^-(? !?=(?(%draft %cancelled) status.r)))
++  note-hist
  |=  [r=reg by=@t what=@t now=@da]
  ^-  reg
  =/  h=(list step)  (snoc history.r [now by what])
  =/  n=@ud  (lent h)
  r(updated now, history ?:((gth n max-history) (slag (sub n max-history) h) h))
++  set-status
  |=  [r=reg to=@tas by=@t what=@t now=@da]
  ^-  reg
  (note-hist r(status to) by what now)
::  +reinstate: a cancelled registration back to the status the cancel
::  left. ~ when it was never cancelled, or when no prior was kept.
::
++  reinstate
  |=  [r=reg by=@t now=@da]
  ^-  (unit reg)
  ?.  =(%cancelled status.r)  ~
  ?:  =(%$ prior.r)  ~
  ?.  (transition-ok %cancelled prior.r)  ~
  `(set-status r prior.r by 'reinstated' now)
::  +new-reg: a registration from a form, as a draft
::
++  new-reg
  |=  [id=@ta token=@t source=@tas in=input now=@da]
  ^-  reg
  :*  id  %draft  track.in  source  now  now
      contact.in  org.in  why.in  assistance.in  together.in  people.in
      [%none 0 0 ~ '' | '']
      [%none '' %none ~]
      token  0  ''  ~  |  %$
  ==
::  +with-input: an edit onto an existing registration
::
++  with-input
  |=  [r=reg in=input]
  ^-  reg
  %_  r
    track       track.in
    contact     contact.in
    org         org.in
    why         why.in
    assistance  assistance.in
    together    together.in
    people      (keep-checkins people.r people.in)
  ==
::  ==  encoders
::
++  en-person
  |=  p=person
  ^-  json
  %-  pairs:enjs:format
  :~  ['first' s+first.p]
      ['last' s+last.p]
      ['child' b+child.p]
      ['days' (pairs:enjs:format ~[['fri' b+fri.days.p] ['sat' b+sat.days.p] ['sun' b+sun.days.p]])]
      ['sun_ten' b+sun-ten.p]
      ['social_fri' b+social-fri.p]
      ['social_sat' b+social-sat.p]
      ['mass_fri' b+mass-fri.p]
      ['holy_hour' b+holy-hour.p]
      ['bus' b+bus.p]
      ['first_bsc' b+first-bsc.p]
      ['knight_dame' b+knight-dame.p]
      ['volunteer' b+volunteer.p]
      :-  'checkins'
      %-  pairs:enjs:format
      %+  turn  ~(tap by checkins.p)
      |=([d=@tas c=checkin] [d (pairs:enjs:format ~[['at' (en-time at.c)] ['by' s+by.c]])])
  ==
++  en-contact
  |=  c=contact
  ^-  json
  %-  pairs:enjs:format
  :~  ['email' s+email.c]  ['phone' s+phone.c]  ['street' s+street.c]
      ['city' s+city.c]  ['state' s+state.c]  ['zip' s+zip.c]
  ==
++  en-payment
  |=  p=payment
  ^-  json
  %-  pairs:enjs:format
  :~  ['method' s+method.p]  ['amount' (en-num amount.p)]  ['gift' (en-num gift.p)]
      ['at' (en-maybe-time at.p)]  ['ref' s+ref.p]  ['refunded' b+refunded.p]  ['note' s+note.p]
  ==
++  en-waiver
  |=  w=waiver
  ^-  json
  %-  pairs:enjs:format
  :~  ['method' s+method.w]  ['envelope' s+envelope.w]  ['status' s+status.w]  ['at' (en-maybe-time at.w)]
  ==
++  en-step
  |=  s=step
  ^-  json
  (pairs:enjs:format ~[['at' (en-time at.s)] ['by' s+by.s] ['what' s+what.s]])
::  +en-reg: the organizer's view. The token never leaves in a view.
::
++  en-reg
  |=  [r=reg fees=@ud position=@ud]
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+id.r]
      ['status' s+status.r]
      ['track' s+track.r]
      ['source' s+source.r]
      ['created' (en-time created.r)]
      ['updated' (en-time updated.r)]
      ['contact' (en-contact contact.r)]
      ['org' s+org.r]
      ['why' s+why.r]
      ['assistance' b+assistance.r]
      ['together' b+together.r]
      ['people' a+(turn people.r en-person)]
      ['payment' (en-payment payment.r)]
      ['waiver' (en-waiver waiver.r)]
      ['position' (en-num position)]
      ['fees' (en-num fees)]
      ['notes' s+notes.r]
      ['exempt' b+exempt.r]
      ['prior' s+prior.r]
      ['history' a+(turn history.r en-step)]
  ==
::  +en-reg-pilgrim: the same without the organizers' own fields
::
++  en-reg-pilgrim
  |=  [r=reg fees=@ud position=@ud]
  ^-  json
  =/  j=json  (en-reg r fees position)
  ?.  ?=([%o *] j)  j
  =/  m=(map @t json)  p.j
  =.  m  (~(del by m) 'notes')
  =.  m  (~(del by m) 'history')
  =.  m  (~(del by m) 'exempt')
  =.  m  (~(del by m) 'prior')
  [%o m]
::  +en-reg-full: every field, the token too. A backup must round-trip,
::  so this encoder hides nothing and computes nothing.
::
++  en-reg-full
  |=  r=reg
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+id.r]
      ['status' s+status.r]
      ['track' s+track.r]
      ['source' s+source.r]
      ['created' (en-time created.r)]
      ['updated' (en-time updated.r)]
      ['contact' (en-contact contact.r)]
      ['org' s+org.r]
      ['why' s+why.r]
      ['assistance' b+assistance.r]
      ['together' b+together.r]
      ['people' a+(turn people.r en-person)]
      ['payment' (en-payment payment.r)]
      ['waiver' (en-waiver waiver.r)]
      ['token' s+token.r]
      ['position' (en-num position.r)]
      ['notes' s+notes.r]
      ['history' a+(turn history.r en-step)]
      ['exempt' b+exempt.r]
      ['prior' s+prior.r]
  ==
::  +en-row: one roster row. Flat, so the backoffice filters and sorts
::  the whole roster in the browser without reading each registration.
::
++  en-row
  |=  [r=reg fees=@ud position=@ud]
  ^-  json
  =/  names=(list @t)  (turn people.r |=(p=person (rap 3 last.p ', ' first.p ~)))
  =/  w=@ud  (walkers track.r people.r)
  %-  pairs:enjs:format
  :~  ['id' s+id.r]
      ['status' s+status.r]
      ['track' s+track.r]
      ['source' s+source.r]
      ['created' (en-time created.r)]
      ['updated' (en-time updated.r)]
      ['email' s+email.contact.r]
      ['phone' s+phone.contact.r]
      ['state' s+state.contact.r]
      ['org' s+org.r]
      ['names' a+(turn names |=(n=@t ^-(json s+n)))]
      ['people' (en-num (lent people.r))]
      ['walkers' (en-num w)]
      ['position' (en-num position)]
      ['fees' (en-num fees)]
      ['paid' s+method.payment.r]
      ['amount' (en-num amount.payment.r)]
      ['gift' (en-num gift.payment.r)]
      ['refunded' b+refunded.payment.r]
      ['waiver' s+status.waiver.r]
      ['exempt' b+exempt.r]
      ['assistance' b+assistance.r]
      ['knight_dame' b+(lien people.r |=(p=person knight-dame.p))]
      ['volunteer' b+(lien people.r |=(p=person volunteer.p))]
      ['nonwalker' [%b =(0 w)]]
      ['plan' (en-plan people.r)]
      ['checked' (en-checked people.r)]
  ==
::  +en-checked: how many of the party are checked in, per day, so the
::  backoffice roster shows a tick without reading each registration
::
++  en-checked
  |=  people=(list person)
  ^-  json
  =/  many
    |=  day=@tas
    ^-  json
    (en-num (lent (skim people |=(p=person (~(has by checkins.p) day)))))
  (pairs:enjs:format ~[['fri' (many %fri)] ['sat' (many %sat)] ['sun' (many %sun)]])
::  +en-plan: how many of the party plan each day and each activity, so
::  the reports add up without reading every registration whole
::
++  en-plan
  |=  people=(list person)
  ^-  json
  =/  many  |=(f=$-(person ?) ^-(json (en-num (lent (skim people f)))))
  %-  pairs:enjs:format
  :~  ['fri' (many |=(p=person fri.days.p))]
      ['sat' (many |=(p=person sat.days.p))]
      ['sun' (many |=(p=person sun.days.p))]
      ['sun_ten' (many |=(p=person &(sun.days.p sun-ten.p)))]
      ['social_fri' (many |=(p=person social-fri.p))]
      ['social_sat' (many |=(p=person social-sat.p))]
      ['mass_fri' (many |=(p=person mass-fri.p))]
      ['holy_hour' (many |=(p=person holy-hour.p))]
      ['bus' (many |=(p=person bus.p))]
      ['first_bsc' (many |=(p=person first-bsc.p))]
      ['children' (many |=(p=person child.p))]
      ['knight_dame' (many |=(p=person knight-dame.p))]
      ['volunteer' (many |=(p=person volunteer.p))]
  ==
::  ==  the check-in
::
::  +checkin-day: the day a check-in names, or ~
::
++  checkin-day
  |=  t=@t
  ^-  (unit @tas)
  ?:  =('fri' t)  `%fri
  ?:  =('sat' t)  `%sat
  ?:  =('sun' t)  `%sun
  ~
::  +on-day: is this person here that day?
::
++  on-day
  |=  [day=@tas p=person]
  ^-  ?
  ?+  day  |
    %fri  fri.days.p
    %sat  sat.days.p
    %sun  sun.days.p
  ==
::  +social-day: the social that day. Sunday has none.
::
++  social-day
  |=  [day=@tas p=person]
  ^-  ?
  ?+  day  |
    %fri  social-fri.p
    %sat  social-sat.p
  ==
::  +put-nth: the party with the person at i replaced
::
++  put-nth
  |=  [i=@ud people=(list person) p=person]
  ^-  (list person)
  ?~  people  ~
  ?:  =(0 i)  [p t.people]
  [i.people $(i (dec i), people t.people)]
::  +with-checkin: one person checked in for a day, or the check-in
::  removed. ~ when the party has no person at i. Idempotent both ways:
::  a check-in that is already there keeps its first at and adds no
::  history line, and removing one that is not there changes nothing.
::
::    The sample names the volunteer `by`, which shadows the map door of
::    that name, so every map call here reaches past it with ^by.
::
++  with-checkin
  |=  [r=reg i=@ud day=@tas by=@t now=@da undo=?]
  ^-  (unit reg)
  ?.  (lth i (lent people.r))  ~
  =/  p=person  (snag i people.r)
  =/  had=(unit checkin)  (~(get ^by checkins.p) day)
  =/  who=@t  (rap 3 first.p ' ' last.p ' ' day ~)
  ?:  undo
    ?~  had  `r
    =/  p2=person  p(checkins (~(del ^by checkins.p) day))
    =/  what=@t  (cat 3 'undid check-in ' who)
    `(note-hist r(people (put-nth i people.r p2)) by what now)
  ?^  had  `r
  =/  p2=person  p(checkins (~(put ^by checkins.p) day [now by]))
  =/  what=@t  (cat 3 'checked in ' who)
  `(note-hist r(people (put-nth i people.r p2)) by what now)
::  +wristband: the answer the volunteer's tap gives. Green when the
::  party is complete and its waiver is in, on paper or by signature.
::  Red carries the reason, which stays on the record.
::
++  wristband
  |=  r=reg
  ^-  (each ~ @t)
  =/  signed=?  |(=(%completed status.waiver.r) =(%paper method.waiver.r))
  ?:  &(=(%complete status.r) signed)  [%& ~]
  ?+  status.r  [%| 'not registered']
    %complete    [%| 'waiver not signed']
    %payment     [%| 'unpaid']
    %assistance  [%| 'awaiting assistance decision']
    %waiver      [%| 'waiver not signed']
    %waitlist    [%| 'on the wait list']
    %cancelled   [%| 'cancelled']
    %draft       [%| 'draft']
  ==
::  +en-roster-person: one person as the check-in app reads them. Every
::  day flag is already narrowed to the day asked for, so the page shows
::  a tag without knowing the day's rules.
::
++  en-roster-person
  |=  [p=person day=@tas i=@ud]
  ^-  json
  =/  c=(unit checkin)  (~(get by checkins.p) day)
  %-  pairs:enjs:format
  :~  ['i' (en-num i)]
      ['first' s+first.p]
      ['last' s+last.p]
      ['child' b+child.p]
      ['walks' [%b (on-day day p)]]
      ['bus' b+bus.p]
      ['mass_fri' [%b &(=(%fri day) mass-fri.p)]]
      ['holy_hour' [%b &(=(%fri day) holy-hour.p)]]
      ['social' [%b (social-day day p)]]
      ['sun_ten' [%b &(=(%sun day) sun.days.p sun-ten.p)]]
      ['checked' [%b ?=(^ c)]]
      ['at' ?~(c ~ (en-time at.u.c))]
      ['by' ?~(c s+'' s+by.u.c)]
  ==
::  +en-roster-people: the party in order, each with its index
::
++  en-roster-people
  |=  [people=(list person) day=@tas i=@ud]
  ^-  (list json)
  ?~  people  ~
  [(en-roster-person i.people day i) $(people t.people, i +(i))]
::  +en-roster-row: one party as the check-in app reads it. The email is
::  here because a volunteer searches by it; the page never draws it,
::  and the rest of the contact stays off the phone.
::
++  en-roster-row
  |=  [r=reg day=@tas]
  ^-  json
  =/  band=(each ~ @t)  (wristband r)
  =/  why=@t  ?:(?=(%| -.band) p.band '')
  %-  pairs:enjs:format
  :~  ['rid' s+id.r]
      ['email' s+email.contact.r]
      ['status' s+status.r]
      ['track' s+track.r]
      ['exempt' b+exempt.r]
      :-  'wristband'
      (pairs:enjs:format ~[['ok' [%b ?=(%& -.band)]] ['why' s+why]])
      ['people' a+(en-roster-people people.r day 0)]
  ==
::  +planned: the day's planned counts. Only a party that will be there
::  plans anything: a wait listed or cancelled one plans nothing. The
::  checked figure counts every person checked in that day, whatever
::  their party's status, because the volunteer saw them.
::
++  planned
  |=  [regs=(list reg) day=@tas]
  ^-  json
  =/  live=(list reg)
    (skim regs |=(r=reg ?=(?(%complete %waiver %payment %assistance) status.r)))
  =/  folk=(list person)  (zing (turn live |=(r=reg people.r)))
  =/  all=(list person)  (zing (turn regs |=(r=reg people.r)))
  =/  many  |=(f=$-(person ?) ^-(json (en-num (lent (skim folk f)))))
  %-  pairs:enjs:format
  :~  ['walk' (many |=(p=person (on-day day p)))]
      ['mass' (many |=(p=person &(=(%fri day) mass-fri.p)))]
      ['holy_hour' (many |=(p=person &(=(%fri day) holy-hour.p)))]
      ['social' (many |=(p=person (social-day day p)))]
      ['bus' (many |=(p=person bus.p))]
      ['sun_ten' (many |=(p=person &(=(%sun day) sun.days.p sun-ten.p)))]
      ['sun_short' (many |=(p=person &(=(%sun day) sun.days.p !sun-ten.p)))]
      ['checked' (en-num (lent (skim all |=(p=person (~(has by checkins.p) day)))))]
  ==
::  +read-reg: the shape ladder. Newest first; anything else is ~.
::
++  read-reg
  |=  n=*
  ^-  (unit reg)
  =/  v2=(unit stored-reg)  (mole |.(;;(stored-reg n)))
  ?^  v2  `reg.u.v2
  =/  v1=(unit stored-reg-1)  (mole |.(;;(stored-reg-1 n)))
  ?^  v1
    =/  o=reg-1  old.u.v1
    :-  ~
    :*  id.o  status.o  track.o  source.o  created.o  updated.o
        contact.o  org.o  why.o  assistance.o  together.o  people.o
        payment.o  waiver.o  token.o  position.o  notes.o  history.o
        |  %$
    ==
  ~
::  ==  decoders for a backup: the inverse of +en-reg-full
::
++  de-checkins
  |=  jon=json
  ^-  (each (map @tas checkin) @t)
  ?.  ?=([%o *] jon)  [%& ~]
  (de-checkin-list ~(tap by p.jon) ~)
::  +de-checkin-list: one pair at a time. A stamp that will not read
::  refuses the registration instead of being dropped.
::
++  de-checkin-list
  |=  [raw=(list [k=@t v=json]) acc=(list [@tas checkin])]
  ^-  (each (map @tas checkin) @t)
  ?~  raw  [%& (malt acc)]
  =/  at=(unit @da)  (gt v.i.raw 'at')
  ?~  at  [%| (rap 3 'check-in ' k.i.raw ' has a stamp that will not read' ~)]
  =/  one=[@tas checkin]  [`@tas`k.i.raw [u.at (gs v.i.raw 'by')]]
  (de-checkin-list t.raw [one acc])
++  de-person-full
  |=  jon=json
  ^-  (each person @t)
  =/  ck=(each (map @tas checkin) @t)  (de-checkins (gj jon 'checkins'))
  ?:  ?=(%| -.ck)  [%| p.ck]
  =/  dj=json  (gj jon 'days')
  :-  %&
  :*  (gs jon 'first')
      (gs jon 'last')
      (gb jon 'child')
      [(gb dj 'fri') (gb dj 'sat') (gb dj 'sun')]
      (gb jon 'sun_ten')
      (gb jon 'social_fri')
      (gb jon 'social_sat')
      (gb jon 'mass_fri')
      (gb jon 'holy_hour')
      (gb jon 'bus')
      (gb jon 'first_bsc')
      (gb jon 'knight_dame')
      (gb jon 'volunteer')
      p.ck
  ==
++  de-people-full
  |=  [raw=(list json) acc=(list person)]
  ^-  (each (list person) @t)
  ?~  raw  [%& (flop acc)]
  =/  got=(each person @t)  (de-person-full i.raw)
  ?:  ?=(%| -.got)  [%| p.got]
  (de-people-full t.raw [p.got acc])
++  de-payment
  |=  jon=json
  ^-  (each payment @t)
  =/  meth=@t  (gs jon 'method')
  ?.  (one-of meth ~['none' 'stripe' 'check' 'cash' 'assistance' 'stub' 'other'])
    [%| (rap 3 'payment method ' meth ' is not one the ship writes' ~)]
  :-  %&
  :*  `@tas`meth
      (fall (gn jon 'amount') 0)
      (fall (gn jon 'gift') 0)
      (gt jon 'at')
      (gs jon 'ref')
      (gb jon 'refunded')
      (gs jon 'note')
  ==
++  de-waiver
  |=  jon=json
  ^-  (each waiver @t)
  =/  meth=@t  (gs jon 'method')
  ?.  (one-of meth ~['none' 'docusign' 'paper' 'stub'])
    [%| (rap 3 'waiver method ' meth ' is not one the ship writes' ~)]
  =/  st=@t  (gs jon 'status')
  ?.  (one-of st ~['none' 'sent' 'completed' 'declined'])
    [%| (rap 3 'waiver status ' st ' is not one the ship writes' ~)]
  [%& [`@tas`meth (gs jon 'envelope') `@tas`st (gt jon 'at')]]
++  de-history
  |=  [raw=(list json) acc=(list step)]
  ^-  (each (list step) @t)
  ?~  raw  [%& (flop acc)]
  =/  at=(unit @da)  (gt i.raw 'at')
  ?~  at  [%| 'a history stamp will not read']
  =/  one=step  [u.at (gs i.raw 'by') (gs i.raw 'what')]
  (de-history t.raw [one acc])
::  +de-reg-full: a registration out of a JSON bundle. It names the id
::  and the field when a value is not one the ship writes, so a broken
::  row refuses the import instead of landing half read.
::
++  de-reg-full
  |=  jon=json
  ^-  (each reg @t)
  ?.  ?=([%o *] jon)  [%| 'a registration must be a JSON object']
  =/  id=@t  (gs jon 'id')
  ?.  (ok-rid id)
    [%| (rap 3 id ': id is not ten lowercase hex digits' ~)]
  =/  st=@t  (gs jon 'status')
  ?.  (one-of st statuses)
    [%| (rap 3 id ': status ' st ' is not a status' ~)]
  =/  tr=@t  (gs jon 'track')
  ?.  (one-of tr ~['full' 'bambino'])
    [%| (rap 3 id ': track ' tr ' is not a track' ~)]
  =/  sr=@t  (gs jon 'source')
  ?.  (one-of sr ~['web' 'admin'])
    [%| (rap 3 id ': source ' sr ' is not a source' ~)]
  =/  pr=@t  (gs jon 'prior')
  ?.  |(=('' pr) (one-of pr statuses))
    [%| (rap 3 id ': prior ' pr ' is not a status' ~)]
  =/  cr=(unit @da)  (gt jon 'created')
  ?~  cr  [%| (rap 3 id ': created will not read' ~)]
  =/  up=(unit @da)  (gt jon 'updated')
  ?~  up  [%| (rap 3 id ': updated will not read' ~)]
  =/  ppl=(each (list person) @t)  (de-people-full (ga jon 'people') ~)
  ?:  ?=(%| -.ppl)  [%| (rap 3 id ': ' p.ppl ~)]
  =/  pay=(each payment @t)  (de-payment (gj jon 'payment'))
  ?:  ?=(%| -.pay)  [%| (rap 3 id ': ' p.pay ~)]
  =/  wv=(each waiver @t)  (de-waiver (gj jon 'waiver'))
  ?:  ?=(%| -.wv)  [%| (rap 3 id ': ' p.wv ~)]
  =/  hist=(each (list step) @t)  (de-history (ga jon 'history') ~)
  ?:  ?=(%| -.hist)  [%| (rap 3 id ': ' p.hist ~)]
  =/  cj=json  (gj jon 'contact')
  :-  %&
  :*  `@ta`id
      `@tas`st
      `@tas`tr
      `@tas`sr
      u.cr
      u.up
      :*  (gs cj 'email')  (gs cj 'phone')  (gs cj 'street')
          (gs cj 'city')  (gs cj 'state')  (gs cj 'zip')
      ==
      (gs jon 'org')
      (gs jon 'why')
      (gb jon 'assistance')
      (gb jon 'together')
      p.ppl
      p.pay
      p.wv
      (gs jon 'token')
      (fall (gn jon 'position') 0)
      (gs jon 'notes')
      p.hist
      (gb jon 'exempt')
      `@tas`pr
  ==
::  ==  csv, for the spreadsheet exports
::
::  +csv-cell: a cell is quoted when it holds a comma, a quote or a
::  newline, and a quote inside it is doubled
::
++  csv-cell
  |=  t=@t
  ^-  @t
  =/  tap=tape  (trip t)
  =/  bad=?  (lien `tape`tap |=(c=@ ?|(=(c ',') =(c '"') =(c 10) =(c 13))))
  ?.  bad  t
  =/  body=tape  (zing (turn `tape`tap |=(c=@ ^-(tape ?:(=(c '"') ~['"' '"'] ~[c])))))
  =/  out=tape  (weld ~['"'] (weld body ~['"']))
  (crip out)
++  csv-row
  |=  cells=(list @t)
  ^-  @t
  ?~  cells  ''
  =/  out=@t  (csv-cell i.cells)
  =/  rest=(list @t)  t.cells
  |-  ^-  @t
  ?~  rest  out
  $(rest t.rest, out (rap 3 out ',' (csv-cell i.rest) ~))
++  csv-doc
  |=  rows=(list @t)
  ^-  @t
  (rap 3 (turn rows |=(r=@t (cat 3 r '\0a'))))
++  yn       |=(b=? ^-(@t ?:(b 'yes' 'no')))
++  num      |=(n=@ud ^-(@t (crip (a-co:co n))))
++  opt-iso  |=(d=(unit @da) ^-(@t ?~(d '' (en-iso u.d))))
::  +dollars: cents as a spreadsheet reads money
::
++  dollars
  |=  cents=@ud
  ^-  @t
  =/  whole=tape  (a-co:co (div cents 100))
  =/  frac=tape   ((d-co:co 2) (mod cents 100))
  (crip "{whole}.{frac}")
++  party-header
  ^-  (list @t)
  :~  'rid'  'status'  'track'  'source'  'created'  'updated'
      'email'  'phone'  'street'  'city'  'state'  'zip'
      'org'  'why'  'assistance'  'exempt'  'position'  'fees'
      'payment_method'  'payment_amount'  'payment_gift'  'payment_at'
      'payment_ref'  'refunded'  'waiver_method'  'waiver_status'
      'waiver_at'  'notes'
  ==
++  person-header
  ^-  (list @t)
  :~  'first'  'last'  'child'  'fri'  'sat'  'sun'  'sun_ten'
      'social_fri'  'social_sat'  'mass_fri'  'holy_hour'  'bus'
      'first_bsc'  'knight_dame'  'volunteer'
      'checkin_fri'  'checkin_sat'  'checkin_sun'
  ==
++  csv-people-header  ^-((list @t) (weld party-header person-header))
++  csv-regs-header
  ^-  (list @t)
  (weld party-header `(list @t)`~['people' 'walkers' 'history'])
++  party-cells
  |=  [r=reg fees=@ud]
  ^-  (list @t)
  :~  id.r  status.r  track.r  source.r  (en-iso created.r)  (en-iso updated.r)
      email.contact.r  phone.contact.r  street.contact.r  city.contact.r
      state.contact.r  zip.contact.r  org.r  why.r  (yn assistance.r)
      (yn exempt.r)  (num position.r)  (dollars fees)
      method.payment.r  (dollars amount.payment.r)  (dollars gift.payment.r)
      (opt-iso at.payment.r)  ref.payment.r  (yn refunded.payment.r)
      method.waiver.r  status.waiver.r  (opt-iso at.waiver.r)  notes.r
  ==
++  checkin-cell
  |=  [p=person day=@tas]
  ^-  @t
  =/  got=(unit checkin)  (~(get by checkins.p) day)
  ?~  got  ''
  (en-iso at.u.got)
++  person-cells
  |=  p=person
  ^-  (list @t)
  :~  first.p  last.p  (yn child.p)  (yn fri.days.p)  (yn sat.days.p)
      (yn sun.days.p)  (yn sun-ten.p)  (yn social-fri.p)  (yn social-sat.p)
      (yn mass-fri.p)  (yn holy-hour.p)  (yn bus.p)  (yn first-bsc.p)
      (yn knight-dame.p)  (yn volunteer.p)
      (checkin-cell p %fri)  (checkin-cell p %sat)  (checkin-cell p %sun)
  ==
::  +hist-cell: the whole history in one cell, each step as at by what
::
++  hist-cell
  |=  h=(list step)
  ^-  @t
  =/  parts=(list @t)  (turn h |=(s=step (rap 3 (en-iso at.s) ' ' by.s ' ' what.s ~)))
  ?~  parts  ''
  =/  out=@t  i.parts
  =/  rest=(list @t)  t.parts
  |-  ^-  @t
  ?~  rest  out
  $(rest t.rest, out (rap 3 out '; ' i.rest ~))
::  +csv-people: one row per person, the party's fields repeated
::
++  csv-people
  |=  [regs=(list reg) s=settings]
  ^-  @t
  =/  rows=(list @t)
    %-  zing
    %+  turn  regs
    |=  r=reg
    ^-  (list @t)
    =/  base=(list @t)  (party-cells r (fees-total s r))
    %+  turn  people.r
    |=  p=person
    ^-  @t
    (csv-row (weld base (person-cells p)))
  (csv-doc [(csv-row csv-people-header) rows])
::  +csv-regs: one row per registration, with the party counts and the
::  whole history
::
++  csv-regs
  |=  [regs=(list reg) s=settings]
  ^-  @t
  =/  rows=(list @t)
    %+  turn  regs
    |=  r=reg
    ^-  @t
    %-  csv-row
    %+  weld  (party-cells r (fees-total s r))
    ^-  (list @t)
    :~  (num (lent people.r))
        (num (walkers track.r people.r))
        (hist-cell history.r)
    ==
  (csv-doc [(csv-row csv-regs-header) rows])
::  ==  the bundle: the whole data set, readable or jammed
::
++  en-bundle
  |=  b=bundle
  ^-  json
  %-  pairs:enjs:format
  :~  ['version' (en-num 1)]
      ['regs' a+(turn regs.b en-reg-full)]
      ['settings' settings.b]
      ['copy' copy.b]
      ['counts' counts.b]
  ==
++  de-regs-full
  |=  [raw=(list json) acc=(list reg)]
  ^-  (each (list reg) @t)
  ?~  raw  [%& (flop acc)]
  =/  got=(each reg @t)  (de-reg-full i.raw)
  ?:  ?=(%| -.got)  [%| (rap 3 'regs: ' p.got ~)]
  (de-regs-full t.raw [p.got acc])
::  +doc-ok: a bundle's document is either absent or an object. A
::  present one of any other shape is refused, because writing it
::  would put a JSON null where a document belongs.
::
++  doc-ok
  |=  [jon=json k=@t]
  ^-  ?
  ?.  (has-key jon k)  &
  =/  v=json  (gj jon k)
  ?=([%o *] v)
::  +de-bundle-why: a bundle out of JSON, or what was wrong with it
::
++  de-bundle-why
  |=  jon=json
  ^-  (each bundle @t)
  ?.  ?=([%o *] jon)  [%| 'bundle: a JSON object is required']
  ?.  (has-key jon 'regs')  [%| 'bundle: regs is missing']
  ?.  (doc-ok jon 'settings')  [%| 'bundle: settings is not an object']
  ?.  (doc-ok jon 'copy')  [%| 'bundle: copy is not an object']
  ?.  (doc-ok jon 'counts')  [%| 'bundle: counts is not an object']
  =/  got  (de-regs-full (ga jon 'regs') ~)
  ?:  ?=(%| -.got)  [%| p.got]
  [%& [%1 p.got (gj jon 'settings') (gj jon 'copy') (gj jon 'counts')]]
++  de-bundle
  |=  jon=json
  ^-  (unit bundle)
  =/  got  (de-bundle-why jon)
  ?:(?=(%| -.got) ~ `p.got)
++  jam-bundle  |=(b=bundle ^-(@ (jam b)))
::  +cue-bundle: a jam from a file. A truncated or foreign atom answers
::  ~ instead of crashing the fiber that read it.
::
++  cue-bundle  |=(a=@ ^-((unit bundle) (mole |.(;;(bundle (cue a))))))
::  ==  helpers
::
::  +ring: append to a JSON array and keep the last max entries
::
++  ring
  |=  [log=json entry=json max=@ud]
  ^-  json
  =/  cur=(list json)  ?:(?=([%a *] log) p.log ~)
  =/  all=(list json)  (snoc cur entry)
  =/  n=@ud  (lent all)
  [%a ?:((gth n max) (slag (sub n max) all) all)]
::  +replace: every pat in hay becomes rep
::
++  replace
  |=  [hay=tape pat=tape rep=tape]
  ^-  tape
  ?~  pat  hay
  |-  ^-  tape
  =/  at=(unit @ud)  (find pat hay)
  ?~  at  hay
  %+  weld  (scag u.at hay)
  %+  weld  rep
  $(hay (slag (add u.at (lent pat)) hay))
::  +fill: a template's {{key}} placeholders, filled
::
++  fill
  |=  [tpl=@t vars=(list [k=@t v=@t])]
  ^-  @t
  =/  out=tape  (trip tpl)
  |-  ^-  @t
  ?~  vars  (crip out)
  =/  key=tape  (weld (trip '{{') (weld (trip k.i.vars) (trip '}}')))
  $(vars t.vars, out (replace out key (trip v.i.vars)))
::  +secret-key: a settings key whose value is a secret
::
::  phase 2 note: the DocuSign tokens are stored as access_token and
::  refresh_token, and neither name ends in _key, so this arm must
::  name them too before those tokens are ever written.
::
++  secret-key
  |=  k=@t
  ^-  ?
  ?:  =('secret' k)  &
  =/  tap=tape  (trip k)
  =/  n=@ud  (lent tap)
  &((gte n 4) =("_key" (slag (sub n 4) tap)))
::  +mask: every secret string in a settings document becomes ****,
::  an empty one stays empty so the page can tell unset from set
::
++  mask
  |=  jon=json
  ^-  json
  ?.  ?=([%o *] jon)  jon
  :-  %o
  %-  ~(urn by p.jon)
  |=  [k=@t v=json]
  ^-  json
  ?:  &((secret-key k) ?=([%s *] v))  ?:(=('' p.v) v s+'****')
  (mask v)
::  +unmask: a masked value coming back on a PUT keeps the stored one
::
++  unmask
  |=  [new=json old=json]
  ^-  json
  ?.  ?=([%o *] new)  new
  :-  %o
  %-  ~(urn by p.new)
  |=  [k=@t v=json]
  ^-  json
  =/  was=json  (gj old k)
  ?:  ?=([%s *] v)  ?:(=('****' p.v) was v)
  (unmask v was)
::  +status-json: what the public page reads: the copy, the counts, the
::  caps, the fees, the window and the mode. `owner` is true only for
::  the ship's owner, so the page knows whether to offer edit mode.
::
++  status-json
  |=  [s=settings sj=json cj=json c=counts now=@da owner=?]
  ^-  json
  %-  pairs:enjs:format
  :~  ['copy' cj]
      :-  'counts'
      %-  pairs:enjs:format
      :~  ['full' (en-num full.c)]  ['bambino' (en-num bambino.c)]
          ['social_fri' (en-num social-fri.c)]  ['social_sat' (en-num social-sat.c)]
          ['late' (en-num late.c)]  ['waitlist' (en-num waitlist.c)]
      ==
      :-  'caps'
      %-  pairs:enjs:format
      :~  ['full' (en-num full.caps.s)]  ['bambino' (en-num bambino.caps.s)]
          ['social_fri' (en-num social-fri.caps.s)]  ['social_sat' (en-num social-sat.caps.s)]
          ['late_adds' (en-num late.caps.s)]  ['party' (en-num max-party)]
      ==
      :-  'fees'
      %-  pairs:enjs:format
      :~  ['full' (en-num full.fees.s)]  ['bambino' (en-num bambino.fees.s)]
      ==
      ['open' b+(window-open s now)]
      ['changes_open' b+(changes-open s now)]
      ['window' (gj sj 'window')]
      ['event' (gj sj 'event')]
      ['orgs' (gj sj 'orgs')]
      ['mode' s+mode.s]
      ['now' (en-time now)]
      ['owner' b+owner]
  ==
::  ==  the starter documents
::
++  starter-settings
  ^-  json
  %-  pairs:enjs:format
  :~  :-  'event'
      %-  pairs:enjs:format
      :~  ['name' s+'Baby Steps Camino 2026']
          ['days' a+~[s+'2026-12-04' s+'2026-12-05' s+'2026-12-06']]
      ==
      ['fees' (pairs:enjs:format ~[['full' (en-num 7.500)] ['bambino' (en-num 2.500)]])]
      :-  'caps'
      %-  pairs:enjs:format
      :~  ['full' (en-num 325)]  ['bambino' (en-num 25)]  ['social_fri' (en-num 300)]
          ['social_sat' (en-num 200)]  ['late_adds' (en-num 50)]
      ==
      ['hold_hours' (en-num 48)]
      :-  'window'
      %-  pairs:enjs:format
      :~  ['open' s+'2026-10-01T04:00:00Z']
          ['close' s+'2026-12-03T05:00:00Z']
          ['change_cutoff' s+'2026-12-04T05:00:00Z']
      ==
      ['orgs' a+~[s+'Order of Malta']]
      ['public_url' s+'https://register.babystepscamino.com']
      ['mail' (pairs:enjs:format ~[['from' s+'Baby Steps Camino <register@babystepscamino.com>'] ['resend_key' s+'']])]
      ['stripe' (pairs:enjs:format ~[['secret_key' s+'']])]
      :-  'docusign'
      %-  pairs:enjs:format
      :~  ['integration_key' s+'']  ['secret' s+'']  ['account_id' s+'']
          ['base_uri' s+'https://demo.docusign.net']  ['auth_host' s+'https://account-d.docusign.com']
          ['template_id' s+'']
      ==
      ['providers' (pairs:enjs:format ~[['mode' s+'stub']])]
  ==
++  starter-copy
  ^-  json
  %-  pairs:enjs:format
  :~  ['landing.title' s+'Register for the Baby Steps Camino']
      ['landing.intro' s+'Three days of beach walking, prayer and fellowship from Jacksonville Beach to the Shrine of Our Lady of La Leche in St. Augustine, December 4 to 6, 2026.']
      ['landing.meter' s+'{{percent}}% full']
      ['landing.full.title' s+'The full Camino']
      ['landing.full.blurb' s+'Walk all three days, or any of them. $75 per person, adults and children alike.']
      ['landing.full.button' s+'Register for the full Camino']
      ['landing.bambino.title' s+'The Bambino Camino']
      ['landing.bambino.blurb' s+'The last 2.5 miles on Sunday, ending at the Shrine. $25 per person.']
      ['landing.bambino.button' s+'Register for the Bambino Camino']
      ['landing.soldout' s+'This track is full. You can join the wait list and we will email you if a spot opens.']
      ['landing.waitlist.button' s+'Join the wait list']
      ['landing.closed' s+'Registration is closed. Contact us at register@babystepscamino.com with any questions.']
      ['form.title' s+'Your registration']
      ['form.contact.title' s+'Contact']
      ['form.email' s+'Email']
      ['form.phone' s+'Phone']
      ['form.street' s+'Street address']
      ['form.city' s+'City']
      ['form.state' s+'State']
      ['form.zip' s+'ZIP']
      ['form.org' s+'Organization or parish (optional)']
      ['form.why' s+'Why are you walking this pilgrimage?']
      ['form.assistance' s+'I would like to be considered for financial assistance.']
      ['form.assistance.help' s+'Not all requests can be accepted. You are not registered until payment is made or assistance is approved.']
      ['form.together' s+'Everyone in my party is doing the same things as {{name}}']
      ['form.same_as' s+'Same as {{name}}']
      ['form.people.title' s+'Who is coming']
      ['form.person' s+'Person {{n}}']
      ['form.first' s+'First name']
      ['form.last' s+'Last name']
      ['form.child' s+'This is a child']
      ['form.days' s+'Walking days']
      ['form.fri' s+'Friday, December 4']
      ['form.sat' s+'Saturday, December 5']
      ['form.sun' s+'Sunday, December 6']
      ['form.sun_ten' s+'On Sunday I will walk the full 10 miles (otherwise the last 2.5)']
      ['form.social_fri' s+'Friday social at Ajua']
      ['form.social_sat' s+'Saturday social at Pussers']
      ['form.social_soldout' s+'sold out']
      ['form.mass_fri' s+'Friday 8am Mass']
      ['form.holy_hour' s+'Holy Hour']
      ['form.bus' s+'I need bus transportation']
      ['form.first_bsc' s+'This is my first Baby Steps Camino']
      ['form.knight_dame' s+'Knight or Dame of the Order of Malta']
      ['form.volunteer' s+'I am volunteering']
      ['form.add_person' s+'Add a person']
      ['form.remove_person' s+'Remove']
      ['form.fees.title' s+'Registration fees']
      ['form.fees.line' s+'{{n}} x {{each}}']
      ['form.fees.total' s+'Total']
      ['form.fees.nonrefundable' s+'The registration fee is non-refundable.']
      ['form.submit' s+'Continue to the waiver']
      ['form.saving' s+'Saved']
      ['form.error.duplicate' s+'There is already a registration under this email. Use the link in your confirmation email to change it, or request the link again below.']
      ['form.resend' s+'Email me my registration link']
      ['form.resend.done' s+'If that address has a registration, the link is on its way.']
      ['next.waiver.title' s+'Sign the waiver']
      ['next.waiver.body' s+'Every pilgrim signs a waiver. You sign once, for yourself and for everyone in your party.']
      ['next.waiver.button' s+'Sign the waiver']
      ['next.payment.title' s+'Pay the registration fee']
      ['next.payment.body' s+'Your spots are held. Payment completes your registration.']
      ['next.payment.button' s+'Pay {{total}}']
      ['next.assistance.title' s+'Thank you']
      ['next.assistance.body' s+'Your waiver is signed and your request for assistance is with the organizers. We will email you when it is decided.']
      ['next.lapsed' s+'Your spots were held for 48 hours and that time has passed. You can still continue; if the track filled in the meantime you will be offered the wait list.']
      ['next.waitlist.title' s+'You are on the wait list']
      ['next.waitlist.body' s+'You are number {{position}} on the wait list. We will email you if a spot opens.']
      ['next.complete.title' s+'You are registered']
      ['next.complete.body' s+'See you on the beach. A confirmation is on its way to {{email}} with a link to change or cancel your registration.']
      ['next.cancelled.title' s+'This registration was cancelled']
      ['next.cancelled.body' s+'If that was a mistake, register again from the start.']
      ['manage.title' s+'Your registration']
      ['manage.save' s+'Save changes']
      ['manage.cancel' s+'Cancel my registration']
      ['manage.cancel.confirm' s+'Cancel this registration for everyone in the party? This cannot be undone.']
      ['manage.closed' s+'Changes are closed. Contact us at register@babystepscamino.com.']
      ['manage.pay_more' s+'Your changes raise the fee by {{diff}}. Pay the difference to keep them.']
      ['stub.banner' s+'Rehearsal mode: signing and payment complete themselves and no email is sent.']
      ['email.confirmation.subject' s+'You are registered for the Baby Steps Camino']
      ['email.confirmation.body' s+'{{first}}, you are registered. Change or cancel your registration any time before the event at {{link}}']
      ['email.manage.subject' s+'Your Baby Steps Camino registration link']
      ['email.manage.body' s+'{{first}}, here is the link to view, change or cancel your registration: {{link}}']
      ['email.waitlist.subject' s+'You are on the Baby Steps Camino wait list']
      ['email.waitlist.body' s+'{{first}}, the track you chose is full. You are number {{position}} on the wait list and we will email you if a spot opens.']
      ['email.promoted.subject' s+'A spot opened for you on the Baby Steps Camino']
      ['email.promoted.body' s+'{{first}}, a spot opened. Sign the waiver and pay within 48 hours to keep it: {{link}}']
      ['email.assistance_approved.subject' s+'Your Baby Steps Camino registration is complete']
      ['email.assistance_approved.body' s+'{{first}}, your request for assistance was approved and you are registered. Your registration: {{link}}']
      ['email.assistance_declined.subject' s+'About your Baby Steps Camino registration']
      ['email.assistance_declined.body' s+'{{first}}, we could not approve assistance this time. Pay the registration fee to complete your registration: {{link}}']
      ['email.reminder.subject' s+'Finish your Baby Steps Camino registration']
      ['email.reminder.body' s+'{{first}}, your registration is not finished yet. Pick up where you left off: {{link}}']
      ['email.cancelled.subject' s+'Your Baby Steps Camino registration was cancelled']
      ['email.cancelled.body' s+'{{first}}, your registration was cancelled. If that was a mistake, register again at {{site}}']
  ==
::  +with-starter: a stored copy document with the strings a release
::  added filled in from the starter.
::
::  The document is laid down once, on the first load, and never laid
::  again, so a ship that has run an older release keeps its own copy for
::  ever. A string a release adds would be missing there, and the page
::  draws a missing string as its own key. A string somebody edited is
::  never touched: the stored value always wins.
::
++  with-starter
  |=  cur=json
  ^-  json
  =/  base=json  starter-copy
  ?.  ?=([%o *] base)  cur
  ?.  ?=([%o *] cur)  base
  [%o (~(uni by p.base) p.cur)]
--
