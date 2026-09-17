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
  ==
::  what the grub holds: a version head, so a later shape is told apart
::  by the reader instead of clamming by luck
::
+$  stored-reg  [%1 =reg]
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
::  ==  time
::
++  unix-secs
  |=  d=@da
  ^-  @ud
  ?:  (lth d ~1970.1.1)  0
  (div (sub d ~1970.1.1) ~s1)
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
    %waiver      ?=(?(%payment %assistance %cancelled) to)
    %payment     ?=(?(%complete %cancelled) to)
    %assistance  ?=(?(%complete %payment %cancelled) to)
    %complete    ?=(%cancelled to)
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
::  +new-reg: a registration from a form, as a draft
::
++  new-reg
  |=  [id=@ta token=@t source=@tas in=input now=@da]
  ^-  reg
  :*  id  %draft  track.in  source  now  now
      contact.in  org.in  why.in  assistance.in  together.in  people.in
      [%none 0 0 ~ '' | '']
      [%none '' %none ~]
      token  0  ''  ~
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
  |=  [r=reg fees=@ud]
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
      ['position' (en-num position.r)]
      ['fees' (en-num fees)]
      ['notes' s+notes.r]
      ['history' a+(turn history.r en-step)]
  ==
::  +en-reg-pilgrim: the same without the organizers' notes and history
::
++  en-reg-pilgrim
  |=  [r=reg fees=@ud]
  ^-  json
  =/  j=json  (en-reg r fees)
  ?.  ?=([%o *] j)  j
  [%o (~(del by (~(del by p.j) 'notes')) 'history')]
::  +read-reg: the shape ladder. Newest first; anything else is ~.
::
++  read-reg
  |=  n=*
  ^-  (unit reg)
  =/  v1=(unit stored-reg)  (mole |.(;;(stored-reg n)))
  ?^  v1  `reg.u.v1
  ~
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
::  caps, the fees, the window and the mode
::
++  status-json
  |=  [s=settings sj=json cj=json c=counts now=@da]
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
      ['form.together' s+'Everyone in my party is doing the same things']
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
--
