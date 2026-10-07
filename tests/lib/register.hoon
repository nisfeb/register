::  Unit tests for /lib/register: the codecs, the fees, the cap fold, the
::  status machine, the templates and the masking.
::
/+  *test, reg=register
|%
++  jo  |=(t=@t ^-(json (need (de:json:html t))))
++  t0  ~2026.10.1..12.00.00
++  t1  ~2026.12.4..13.05.00
++  t2  ~2026.12.4..13.06.00
::  +at-n: the item at i in a JSON array, or null
++  at-n
  |=  [l=(list json) i=@ud]
  ^-  json
  ?~  l  ~
  ?:  =(0 i)  i.l
  $(l t.l, i (dec i))
::  a full-track adult who walks every day and takes both socials
++  pj
  %-  jo
  '''
  {"first": "Ana", "last": "Silva", "child": false,
   "days": {"fri": true, "sat": true, "sun": true}, "sun_ten": true,
   "social_fri": true, "social_sat": true, "mass_fri": true, "holy_hour": false,
   "bus": true, "first_bsc": true, "knight_dame": false, "volunteer": false}
  '''
++  cj
  %-  jo
  '''
  {"email": "ana@example.com", "phone": "904-555-0100", "street": "1 Beach Rd",
   "city": "Jacksonville Beach", "state": "FL", "zip": "32250"}
  '''
++  ij
  |=  extra=(list [@t json])
  ^-  json
  %-  pairs:enjs:format
  %+  weld
    ^-  (list [@t json])
    :~  ['track' s+'full']
        ['contact' cj]
        ['org' s+'Order of Malta']
        ['why' s+'prayer']
        ['assistance' b+|]
        ['together' b+|]
        ['people' a+~[pj]]
    ==
  extra
++  st  (de-settings:reg starter-settings:reg)
::  +old-reg: the shape a %1 grub holds, built out of the new one
::  +first-of: the first person of a party, for a test that reads a field
::  of it. A bare i.people.r will not compile: the list's type is a fork
::  until something proves it is not empty.
++  first-of
  |=  people=(list person:reg)
  ^-  person:reg
  ?>  ?=(^ people)
  i.people
::  +drop-person: a person as the older grubs hold one, without Mass on
::  Saturday and Sunday and without the trolley
++  drop-person
  |=  p=person:reg
  ^-  person-2:reg
  :*  first.p  last.p  child.p  days.p  sun-ten.p
      social-fri.p  social-sat.p  mass-fri.p  holy-hour.p  bus.p
      first-bsc.p  knight-dame.p  volunteer.p  checkins.p
  ==
++  old-reg
  ^-  reg-1:reg
  =/  r=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  :*  id.r  status.r  track.r  source.r  created.r  updated.r
      contact.r  org.r  why.r  assistance.r  together.r
      (turn people.r drop-person)
      payment.r  waiver.r  token.r  position.r  notes.r  history.r
  ==
::  +old-reg-2: the shape before the person grew
++  old-reg-2
  ^-  reg-2:reg
  =/  r=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  :*  id.r  status.r  track.r  source.r  created.r  updated.r
      contact.r  org.r  why.r  assistance.r  together.r
      (turn people.r drop-person)
      payment.r  waiver.r  token.r  position.r  notes.r  history.r
      &  %payment
  ==
++  count-commas
  |=  t=@t
  ^-  @ud
  (lent (skim `tape`(trip t) |=(c=@ =(c ','))))
::  +split-nl: a document into its lines, the trailing newline dropped
++  split-nl
  |=  t=@t
  ^-  (list @t)
  =/  tap=tape  (trip t)
  =|  cur=tape
  =|  out=(list @t)
  |-  ^-  (list @t)
  ?~  tap  (flop ?~(cur out [(crip (flop cur)) out]))
  ?:  =(10 i.tap)  $(tap t.tap, cur ~, out [(crip (flop cur)) out])
  $(tap t.tap, cur [i.tap cur])
::  +put-key: one key of a JSON object replaced, for the broken fixtures
++  put-key
  |=  [jon=json k=@t v=json]
  ^-  json
  ?.  ?=([%o *] jon)  jon
  [%o (~(put by p.jon) k v)]
::  +why-of: the message a refusal carries, or '' when it read
++  why-of
  |=  got=(each bundle:reg @t)
  ^-  @t
  ?:(?=(%| -.got) p.got '')
::  +reads: did a bundle decode
++  reads
  |=  got=(each bundle:reg @t)
  ^-  ?
  ?=(%& -.got)
::  +one-bundle: a bundle holding this one registration's JSON
++  one-bundle
  |=  j=json
  ^-  json
  (pairs:enjs:format ~[['regs' a+~[j]]])
++  some-person
  ^-  person:reg
  =/  got  (de-person:reg pj & 0)
  ?>  ?=(%& -.got)
  p.got
++  some-reg
  |=  [id=@ta status=@tas track=@tas n=@ud at=@da]
  ^-  reg:reg
  =/  p=person:reg  some-person
  =/  people=(list person:reg)  (reap n p)
  =/  r=reg:reg  (new-reg:reg id 'tok' %web [track [id 'p' 's' 'c' 'FL' 'z'] '' '' | | people] at)
  r(status status, updated at)
::  ==  ids and time
::
++  test-ids
  =/  eny=@  0xdead.beef.cafe.f00d.1234.5678.9abc.def0.1111.2222.3333.4444.5555.6666.7777.8888
  ;:  weld
    (expect-eq !>(10) !>((met 3 (rid-from:reg eny))))
    (expect-eq !>(32) !>((met 3 (token-from:reg eny))))
    (expect !>(!=((rid-from:reg eny) (rid-from:reg (add eny 1)))))
    ::  +ok-rid moved out of the nexus, so the lib owns the shape
    (expect !>((ok-rid:reg (rid-from:reg eny))))
    (expect !>((ok-rid:reg '0123456789')))
    (expect !>(!(ok-rid:reg 'abc123')))
    (expect !>(!(ok-rid:reg '0123456789a')))
    (expect !>(!(ok-rid:reg 'ABCDEF0123')))
    (expect !>(!(ok-rid:reg '')))
  ==
++  test-iso
  ;:  weld
    (expect-eq !>(`(unit @da)`[~ t0]) !>((de-iso:reg '2026-10-01T12:00:00Z')))
    (expect-eq !>('2026-10-01T12:00:00Z') !>((en-iso:reg t0)))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:reg '2026-02-30T00:00:00Z')))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:reg 'yesterday')))
  ==
::  +test-iso-bounds: each end of every field the parser checks, the
::  last good value and the first bad one. Without the good end a
::  mutant can tighten the bound and no test notices.
++  test-iso-bounds
  =/  ok   |=(t=@t ^-(? ?=(^ (de-iso:reg t))))
  =/  bad  |=(t=@t ^-(? ?=(~ (de-iso:reg t))))
  ;:  weld
    ::  the month
    (expect !>((ok '2026-01-15T00:00:00Z')))
    (expect !>((ok '2026-12-15T00:00:00Z')))
    (expect !>((bad '2026-00-15T00:00:00Z')))
    (expect !>((bad '2026-13-15T00:00:00Z')))
    ::  the day
    (expect !>((ok '2026-01-01T00:00:00Z')))
    (expect !>((ok '2026-01-31T00:00:00Z')))
    (expect !>((bad '2026-01-00T00:00:00Z')))
    (expect !>((bad '2026-01-32T00:00:00Z')))
    ::  the clock
    (expect !>((ok '2026-01-01T23:59:59Z')))
    (expect !>((bad '2026-01-01T24:00:00Z')))
    (expect !>((bad '2026-01-01T00:60:00Z')))
    (expect !>((bad '2026-01-01T00:00:60Z')))
  ==
::  +test-bambino-only-sunday: the Bambino Camino is Sunday and the short
::  walk. Anything a page might send from the rest of the weekend is
::  cleared on the way in, because the roster, the day counts and both
::  spreadsheets read the stored person: a Friday Mass left set would put
::  a Bambino pilgrim on Friday's list for a day they never signed up
::  for. The motorcoach is not a day's event and is left alone.
::
++  test-bambino-only-sunday
  =/  everything=json
    %-  jo
    '''
    {"track":"bambino","together":false,"assistance":false,"org":"","why":"",
     "contact":{"email":"b@c.org","phone":"904-555-0100","street":"1 Beach Rd",
       "city":"JB","state":"FL","zip":"32250"},
     "people":[{"first":"Bea","last":"Bino","child":false,
       "days":{"fri":true,"sat":true,"sun":true},"sun_ten":true,
       "social_fri":true,"social_sat":true,"mass_fri":true,"mass_sat":true,
       "mass_sun":true,"holy_hour":true,"bus":true,"trolley":true,
       "first_bsc":false,"knight_dame":false,"volunteer":false}]}
    '''
  =/  got  (de-input:reg everything &)
  ?:  ?=(%| -.got)  (expect-eq !>('read') !>(p.got))
  =/  p=person:reg  (first-of people.p.got)
  ;:  weld
    (expect !>(!fri.days.p))
    (expect !>(!sat.days.p))
    (expect !>(sun.days.p))
    (expect !>(!sun-ten.p))
    (expect !>(!mass-fri.p))
    (expect !>(!mass-sat.p))
    (expect !>(!holy-hour.p))
    (expect !>(!social-fri.p))
    (expect !>(!social-sat.p))
    ::  Sunday's own, and the ride, are theirs to keep
    (expect !>(mass-sun.p))
    (expect !>(trolley.p))
    (expect !>(bus.p))
  ==
::  +test-full-keeps-its-weekend: the same document on the full track is
::  left exactly as it came, so the rule is the Bambino track's alone
::
++  test-full-keeps-its-weekend
  =/  everything=json
    %-  jo
    '''
    {"track":"full","together":false,"assistance":false,"org":"","why":"",
     "contact":{"email":"f@c.org","phone":"904-555-0100","street":"1 Beach Rd",
       "city":"JB","state":"FL","zip":"32250"},
     "people":[{"first":"Fay","last":"Full","child":false,
       "days":{"fri":true,"sat":true,"sun":true},"sun_ten":true,
       "social_fri":true,"social_sat":true,"mass_fri":true,"mass_sat":true,
       "mass_sun":true,"holy_hour":true,"bus":true,"trolley":true,
       "first_bsc":false,"knight_dame":false,"volunteer":false}]}
    '''
  =/  got  (de-input:reg everything &)
  ?:  ?=(%| -.got)  (expect-eq !>('read') !>(p.got))
  =/  p=person:reg  (first-of people.p.got)
  ;:  weld
    (expect !>(fri.days.p))
    (expect !>(sat.days.p))
    (expect !>(sun-ten.p))
    (expect !>(mass-fri.p))
    (expect !>(social-sat.p))
    (expect !>(holy-hour.p))
  ==
::  ==  decoders
::
++  test-de-person
  ;:  weld
    (expect !>(?=([%& *] (de-person:reg pj & 0))))
    (expect-eq !>(`(each person:reg @t)`[%| 'people.0.first: required']) !>((de-person:reg (jo '{"last": "x"}') & 0)))
    ::  a draft may leave the names empty
    (expect !>(?=([%& *] (de-person:reg (jo '{"last": "x"}') | 0))))
    (expect-eq !>(`(each person:reg @t)`[%| 'people.1.last: over 80 bytes']) !>((de-person:reg (jo (cat 3 '{"first": "a", "last": "' (cat 3 (crip (reap 81 'x')) '"}'))) & 1)))
  ==
++  test-de-contact
  ;:  weld
    (expect !>(?=([%& *] (de-contact:reg cj &))))
    (expect-eq !>(`(each contact:reg @t)`[%| 'email: not an email address']) !>((de-contact:reg (jo '{"email": "nope", "phone": "1"}') &)))
    (expect-eq !>(`(each contact:reg @t)`[%| 'zip: required']) !>((de-contact:reg (jo '{"email": "a@b.co", "phone": "1", "street": "s", "city": "c", "state": "FL"}') &)))
    ::  a draft needs an email or a phone, nothing else
    (expect !>(?=([%& *] (de-contact:reg (jo '{"phone": "904"}') |))))
    (expect-eq !>(`(each contact:reg @t)`[%| 'contact: an email or a phone number is required']) !>((de-contact:reg (jo '{"street": "s"}') |)))
  ==
++  test-de-input
  ;:  weld
    (expect !>(?=([%& *] (de-input:reg (ij ~) &))))
    (expect-eq !>(`(each input:reg @t)`[%| 'track: full or bambino']) !>((de-input:reg (ij ~[['track' s+'both']]) &)))
    (expect-eq !>(`(each input:reg @t)`[%| 'people: at least one person']) !>((de-input:reg (ij ~[['people' a+~]]) &)))
    (expect-eq !>(`(each input:reg @t)`[%| 'people: over 12']) !>((de-input:reg (ij ~[['people' a+(reap 13 pj)]]) &)))
    (expect-eq !>(`(each input:reg @t)`[%| 'why: over 2000 bytes']) !>((de-input:reg (ij ~[['why' s+(crip (reap 2.001 'w'))]]) &)))
  ==
++  test-together
  =/  second=json
    %-  jo
    '''
    {"first": "Bo", "last": "Silva", "child": true,
     "days": {"fri": false, "sat": false, "sun": false}, "sun_ten": false,
     "social_fri": false, "social_sat": false, "mass_fri": false, "holy_hour": false,
     "bus": false, "first_bsc": false, "knight_dame": false, "volunteer": false}
    '''
  =/  got  (de-input:reg (ij ~[['together' b+&] ['people' a+~[pj second]]]) &)
  ?>  ?=(%& -.got)
  =/  bo=person:reg  (snag 1 people.p.got)
  ;:  weld
    (expect-eq !>(&) !>(fri.days.bo))
    (expect-eq !>(&) !>(social-sat.bo))
    (expect-eq !>(&) !>(bus.bo))
    ::  identity fields stay the person's own
    (expect-eq !>('Bo') !>(first.bo))
    (expect-eq !>(&) !>(child.bo))
    (expect-eq !>(|) !>(first-bsc.bo))
  ==
::  ==  fees
::
++  test-fees
  =/  p=person:reg  some-person
  =/  none=person:reg  p(days [| | |])
  =/  sun-only=person:reg  p(days [| | &])
  ;:  weld
    (expect-eq !>(7.500) !>((fee:reg st %full p)))
    (expect-eq !>(7.500) !>((fee:reg st %full sun-only)))
    ::  a non-walker pays the track fee too
    (expect-eq !>(7.500) !>((fee:reg st %full none)))
    (expect-eq !>(2.500) !>((fee:reg st %bambino sun-only)))
    (expect-eq !>(2.500) !>((fee:reg st %bambino none)))
    ::  a child pays the same
    (expect-eq !>(7.500) !>((fee:reg st %full p(child &))))
    (expect-eq !>(22.500) !>((fees-total:reg st (some-reg %a %waiver %full 3 t0))))
  ==
::  ==  the cap fold
::
++  test-tally
  =/  now=@da  (add t0 ~h1)
  =/  regs=(list reg:reg)
    :~  (some-reg %a %complete %full 2 t0)
        (some-reg %b %payment %full 1 t0)                    ::  a live hold
        (some-reg %c %waiver %full 5 (sub t0 ~d3))           ::  an aged hold
        (some-reg %d %assistance %full 1 (sub t0 ~d30))      ::  waits as long as it takes
        (some-reg %e %cancelled %full 9 t0)
        (some-reg %f %draft %full 9 t0)
        (some-reg %g %waitlist %full 2 t0)
        (some-reg %h %complete %bambino 3 t0)
        (some-reg %i %complete %full 1 t0)
    ==
  =/  late=reg:reg  =/(r (some-reg %j %waiver %full 4 (sub t0 ~d3)) r(source %admin))
  ::  the hold ends on the tick: now equals updated plus the hold
  =/  edge=reg:reg  (some-reg %k %waiver %full 7 (sub now ~h48))
  =/  c=counts:reg  (tally:reg st (snoc (snoc regs late) edge) now)
  ;:  weld
    (expect-eq !>(5) !>(full.c))
    (expect-eq !>(3) !>(bambino.c))
    (expect-eq !>(4) !>(late.c))
    ::  socials count every counted person, both tracks, late adds too
    (expect-eq !>(12) !>(social-fri.c))
    (expect-eq !>(1) !>(waitlist.c))
  ==
++  test-decide
  =/  c=counts:reg  [320 25 0 0 0 0]
  =/  p=person:reg  some-person
  ;:  weld
    (expect-eq !>(%waiver) !>((decide-submit:reg st c %full (reap 5 p))))
    (expect-eq !>(%waitlist) !>((decide-submit:reg st c %full (reap 6 p))))
    (expect-eq !>(%waitlist) !>((decide-submit:reg st c %bambino (reap 1 p))))
    ::  non-walkers never need a spot
    (expect-eq !>(%waiver) !>((decide-submit:reg st c %full (reap 6 p(days [| | |])))))
    (expect-eq !>(1) !>((walkers:reg %bambino ~[p p(days [| | |]) p(days [& & |])])))
  ==
++  test-socials
  =/  p=person:reg  some-person
  ::  somebody taking neither social, for the over-cap cases
  =/  quiet=person:reg  p(social-fri |, social-sat |)
  ;:  weld
    (expect-eq !>(`(unit @t)`~) !>((socials-ok:reg st [0 0 298 198 0 0] ~[p p] ~)))
    (expect-eq !>(`(unit @t)`[~ 'social_sat: sold out']) !>((socials-ok:reg st [0 0 0 199 0 0] ~[p p] ~)))
    (expect-eq !>(`(unit @t)`[~ 'social_fri: sold out']) !>((socials-ok:reg st [0 0 300 0 0 0] ~[p] ~)))
    ::  a social already over its cap must not freeze a party that is
    ::  taking no seat at it, nor one that is not asking for more than
    ::  it already holds. +do-promote checks no social cap, so going
    ::  over is a real state the ship reaches.
    (expect-eq !>(`(unit @t)`~) !>((socials-ok:reg st [0 0 0 202 0 0] ~[quiet quiet] ~[quiet quiet])))
    (expect-eq !>(`(unit @t)`~) !>((socials-ok:reg st [0 0 0 200 0 0] ~[p p] ~[p p])))
    ::  but one more seat at a full social still is refused
    (expect-eq !>(`(unit @t)`[~ 'social_sat: sold out']) !>((socials-ok:reg st [0 0 0 200 0 0] ~[p p] ~[p])))
    ::  and giving a seat up is always allowed
    (expect-eq !>(`(unit @t)`~) !>((socials-ok:reg st [0 0 0 202 0 0] ~[p] ~[p p])))
  ==
++  test-room-for
  =/  now=@da  (add t0 ~h1)
  =/  p=person:reg  some-person
  =/  nw=person:reg  p(days [| | |])
  ::  a track of two spots, both taken by a complete registration
  =/  s0=settings:reg  st
  =/  sm=settings:reg  s0(full.caps 2)
  =/  taken=reg:reg  (some-reg %c %complete %full 2 now)
  =/  live=reg:reg  (some-reg %a %waiver %full 2 now)
  =/  lapsed=reg:reg  (some-reg %b %waiver %full 2 (sub now ~d3))
  =/  none=reg:reg
    =/  r=reg:reg  (some-reg %e %waiver %full 3 (sub now ~d3))
    r(people (reap 3 nw))
  ;:  weld
    ::  a counted hold keeps its spots even at the cap
    (expect !>((room-for:reg sm ~[live taken] live now)))
    ::  a lapsed hold at a filled track has none
    (expect !>(!(room-for:reg sm ~[lapsed taken] lapsed now)))
    ::  a lapsed hold decided against a tree with room has one
    (expect !>((room-for:reg sm ~[lapsed] lapsed now)))
    ::  a lapsed party of non-walkers never needs a spot
    (expect !>((room-for:reg sm ~[none taken] none now)))
  ==
++  test-position-of
  =/  w1=reg:reg  (some-reg %a %waitlist %full 1 t0)
  =/  w2=reg:reg  (some-reg %b %waitlist %full 1 (add t0 ~m1))
  =/  w3=reg:reg  (some-reg %c %waitlist %full 1 (add t0 ~m2))
  =/  gone=reg:reg  (some-reg %d %cancelled %full 1 t0)
  =/  regs=(list reg:reg)  ~[w1 w2 w3 gone]
  =/  after=(list reg:reg)  ~[w1(status %waiver, position 0) w2 w3 gone]
  ;:  weld
    (expect-eq !>(1) !>((position-of:reg regs w1)))
    (expect-eq !>(2) !>((position-of:reg regs w2)))
    (expect-eq !>(3) !>((position-of:reg regs w3)))
    (expect-eq !>(0) !>((position-of:reg regs gone)))
    ::  promoting the first moves the second up
    (expect-eq !>(1) !>((position-of:reg after w2)))
  ==
::  ==  the status machine
::
++  test-transitions
  ;:  weld
    (expect !>((transition-ok:reg %draft %waiver)))
    (expect !>((transition-ok:reg %draft %waitlist)))
    (expect !>((transition-ok:reg %waitlist %waiver)))
    (expect !>((transition-ok:reg %waiver %payment)))
    (expect !>((transition-ok:reg %waiver %assistance)))
    (expect !>((transition-ok:reg %payment %complete)))
    (expect !>((transition-ok:reg %assistance %complete)))
    (expect !>((transition-ok:reg %assistance %payment)))
    (expect !>((transition-ok:reg %waiver %waitlist)))
    (expect !>((transition-ok:reg %payment %waitlist)))
    (expect !>((transition-ok:reg %complete %cancelled)))
    ::  a cancel is undone by a reinstate, so cancelled has edges now
    (expect !>((transition-ok:reg %cancelled %waiver)))
    (expect !>(!(transition-ok:reg %cancelled %draft)))
    (expect !>(!(transition-ok:reg %draft %complete)))
    (expect !>(!(transition-ok:reg %waiver %complete)))
    (expect-eq !>(%payment) !>((after-waiver:reg (some-reg %a %waiver %full 1 t0))))
    (expect-eq !>(%assistance) !>((after-waiver:reg =/(r (some-reg %a %waiver %full 1 t0) r(assistance &)))))
  ==
++  test-set-status
  =/  r=reg:reg  (some-reg %a %waiver %full 1 t0)
  =/  r2=reg:reg  (set-status:reg r %payment 'pilgrim' 'signed the waiver' (add t0 ~m5))
  =/  many=reg:reg
    =/  i=@ud  0
    |-  ^-  reg:reg
    ?:  =(210 i)  r2
    $(i +(i), r2 (note-hist:reg r2 'admin' 'edit' t0))
  ;:  weld
    (expect-eq !>(%payment) !>(status.r2))
    (expect-eq !>((add t0 ~m5)) !>(updated.r2))
    (expect-eq !>(1) !>((lent history.r2)))
    (expect-eq !>('signed the waiver') !>(what:(rear history.r2)))
    (expect-eq !>(200) !>((lent history.many)))
  ==
::  ==  codecs
::
++  test-roundtrip
  =/  r=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  =/  j=json  (en-reg:reg r 15.000 4)
  ;:  weld
    (expect-eq !>('abc123') !>((gs:reg j 'id')))
    (expect-eq !>(`(unit @ud)`[~ 15.000]) !>((gn:reg j 'fees')))
    ::  the position the caller computed, not the stored one
    (expect-eq !>(`(unit @ud)`[~ 4]) !>((gn:reg j 'position')))
    (expect-eq !>(2) !>((lent (ga:reg j 'people'))))
    ::  the token never leaves in a view
    (expect !>(!(has-key:reg j 'token')))
    (expect !>((has-key:reg j 'history')))
    (expect !>(!(has-key:reg (en-reg-pilgrim:reg r 0 0) 'history')))
    (expect !>(!(has-key:reg (en-reg-pilgrim:reg r 0 0) 'notes')))
  ==
++  test-read-reg
  =/  r=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  ;:  weld
    (expect-eq !>(`(unit reg:reg)`[~ r]) !>((read-reg:reg `stored-reg:reg`[%3 r])))
    (expect-eq !>(`(unit reg:reg)`~) !>((read-reg:reg [%9 'garbage'])))
    (expect-eq !>(`(unit reg:reg)`~) !>((read-reg:reg 42)))
  ==
::  ==  helpers
::
++  test-ring
  =/  log=json  [%a ~[s+'a' s+'b']]
  =/  out=json  (ring:reg log s+'c' 2)
  (expect-eq !>(`json`[%a ~[s+'b' s+'c']]) !>(out))
++  test-fill
  ;:  weld
    (expect-eq !>('Hi Ana, see https://x/y. Bye Ana.') !>((fill:reg 'Hi {{first}}, see {{link}}. Bye {{first}}.' ~[['first' 'Ana'] ['link' 'https://x/y']])))
    (expect-eq !>('no vars') !>((fill:reg 'no vars' ~)))
  ==
++  test-mask
  =/  s=json  (jo '{"mail": {"from": "a@b", "resend_key": "re_123"}, "stripe": {"secret_key": ""}, "docusign": {"secret": "s3", "account_id": "acc"}}')
  =/  m=json  (mask:reg s)
  =/  put=json  (jo '{"mail": {"from": "c@d", "resend_key": "****"}, "stripe": {"secret_key": "sk_new"}, "docusign": {"secret": "****", "account_id": "acc2"}}')
  =/  merged=json  (unmask:reg put s)
  ;:  weld
    (expect-eq !>('****') !>((gs:reg (gj:reg m 'mail') 'resend_key')))
    (expect-eq !>('') !>((gs:reg (gj:reg m 'stripe') 'secret_key')))
    (expect-eq !>('acc') !>((gs:reg (gj:reg m 'docusign') 'account_id')))
    (expect-eq !>('re_123') !>((gs:reg (gj:reg merged 'mail') 'resend_key')))
    (expect-eq !>('c@d') !>((gs:reg (gj:reg merged 'mail') 'from')))
    (expect-eq !>('sk_new') !>((gs:reg (gj:reg merged 'stripe') 'secret_key')))
    (expect-eq !>('s3') !>((gs:reg (gj:reg merged 'docusign') 'secret')))
  ==
++  test-settings
  =/  s=settings:reg  st
  ;:  weld
    (expect-eq !>(7.500) !>(full.fees.s))
    (expect-eq !>(325) !>(full.caps.s))
    (expect-eq !>(~h48) !>(hold.s))
    (expect-eq !>(%stub) !>(mode.s))
    (expect !>((window-open:reg st ~2026.11.1)))
    (expect !>(!(window-open:reg st ~2026.9.1)))
    (expect !>((changes-open:reg st ~2026.12.1)))
    (expect !>(!(changes-open:reg st ~2026.12.5)))
  ==
::  +test-status-owner: the status document says who is asking, so the
::  page offers edit mode to the owner and to nobody else
++  test-status-owner
  =/  st=settings:reg  (de-settings:reg starter-settings:reg)
  =/  c=counts:reg  [0 0 0 0 0 0]
  =/  yes=json  (status-json:reg st starter-settings:reg starter-copy:reg c t0 &)
  =/  no=json  (status-json:reg st starter-settings:reg starter-copy:reg c t0 |)
  ;:  weld
    (expect !>((gb:reg yes 'owner')))
    (expect !>(!(gb:reg no 'owner')))
    (expect !>(!=('' (gs:reg (gj:reg yes 'copy') 'landing.title'))))
  ==
++  test-copy
  =/  c=json  starter-copy:reg
  ;:  weld
    (expect !>(!=('' (gs:reg c 'landing.title'))))
    (expect !>(!=('' (gs:reg c 'email.waitlist.body'))))
    (expect !>(!=('' (gs:reg c 'form.social_soldout'))))
    (expect !>(!=('' (gs:reg c 'next.lapsed'))))
    ::  the strings the redesigned form reads
    (expect !>(!=('' (gs:reg c 'landing.choose'))))
    (expect !>(!=('' (gs:reg c 'landing.full.fee'))))
    (expect !>(!=('' (gs:reg c 'form.people.help'))))
    (expect !>(!=('' (gs:reg c 'form.sun.ten'))))
    (expect !>(!=('' (gs:reg c 'form.sun.short'))))
    (expect !>(!=('' (gs:reg c 'form.sun.bambino'))))
    (expect !>(!=('' (gs:reg c 'form.friday.closed'))))
    ::  the card a visitor reads before opening day names the date
    (expect !>(!=('' (gs:reg c 'landing.notyet'))))
    ::  the check-in link's strings and its email
    (expect !>(!=('' (gs:reg c 'checkin.title'))))
    (expect !>(!=('' (gs:reg c 'checkin.early'))))
    (expect !>(!=('' (gs:reg c 'checkin.over'))))
    (expect !>(!=('' (gs:reg c 'checkin.gone'))))
    (expect !>(!=('' (gs:reg c 'checkin.solo.body'))))
    (expect !>(!=('' (gs:reg c 'checkin.solo.button'))))
    (expect !>(!=('' (gs:reg c 'checkin.group.body'))))
    (expect !>(!=('' (gs:reg c 'checkin.group.button'))))
    (expect !>(!=('' (gs:reg c 'checkin.done'))))
    (expect !>(!=('' (gs:reg c 'checkin.done.some'))))
    (expect !>(!=('' (gs:reg c 'checkin.nobody'))))
    (expect !>(!=('' (gs:reg c 'email.checkin.subject'))))
    (expect !>(!=('' (gs:reg c 'email.checkin.body'))))
    (expect !>(!=('' (gs:reg c 'form.around.title'))))
    (expect !>(!=('' (gs:reg c 'form.fees.child'))))
    (expect !>(!=('' (gs:reg c 'form.submit.waitlist'))))
    (expect !>(!=('' (gs:reg c 'next.draft.body'))))
    (expect !>(!=('' (gs:reg c 'manage.line'))))
    ::  the short venue names the weekend summary reads
    (expect !>(!=('' (gs:reg c 'form.social_fri.short'))))
    (expect !>(!=('' (gs:reg c 'form.social_sat.short'))))
    ::  the two strings the old flat form read are gone
    (expect !>(=('' (gs:reg c 'form.together'))))
    (expect !>(=('' (gs:reg c 'form.sun_ten'))))
  ==
::  +test-copy-fee-line: the fee table prints the money in a column of
::  its own, so the line beside it names the person and what they are
::  paying for and stops there. A {{each}} in the line would print the
::  same number twice on one row.
::
++  test-copy-fee-line
  =/  c=json  starter-copy:reg
  =/  line=@t  (gs:reg c 'form.fees.line')
  ;:  weld
    (expect !>(=(line (fill:reg line ~[['each' '$75']]))))
    (expect !>(!=(line (fill:reg line ~[['name' 'Ana Silva']]))))
    (expect !>(!=(line (fill:reg line ~[['what' 'under 18']]))))
  ==
::  +test-copy-links: a string may carry one [text](url) link, which the
::  page renders as an anchor. The default intro and the two socials
::  carry one, so an organizer has a worked example to copy.
::
++  test-copy-links
  =/  c=json  starter-copy:reg
  =/  intro=tape  (trip (gs:reg c 'landing.intro'))
  =/  soc=tape  (trip (gs:reg c 'form.social_fri'))
  ;:  weld
    (expect !>(?=(^ (find "](https://" intro))))
    (expect !>(?=(^ (find "](https://" soc))))
  ==
::  +test-copy-manage-mail: the backoffice offers a manage resend, so the
::  document carries a subject and a body for it. Without them the resend
::  answers "no copy for email.manage.subject" and the Emails tab is
::  missing a template the organizers can edit.
::
++  test-copy-manage-mail
  =/  c=json  starter-copy:reg
  =/  body=@t  (gs:reg c 'email.manage.body')
  ;:  weld
    (expect !>(!=('' (gs:reg c 'email.manage.subject'))))
    (expect !>(!=('' body)))
    (expect !>(!=(body (fill:reg body ~[['first' 'Ana']]))))
    (expect !>(!=(body (fill:reg body ~[['link' 'http://x']]))))
  ==
::  +test-with-starter: a ship that has run an older release keeps its own
::  copy document for ever, so the strings a release adds are filled in on
::  the way out. What somebody edited is never touched.
::
::  +test-email-vars: every {{word}} in every email template is one the
::  ship knows how to fill.
::
::  The way it is checked is the way the ship fills them: hand +fill the
::  whole list of names, and nothing in double brackets should survive.
::  A template that names {{name}} when the ship only knows {{first}}
::  would otherwise go out to a pilgrim with the brackets still in it.
::
::  This list is +send-mail's, and the legend on the Emails page is the
::  same list again. Adding a variable means touching all three.
::
++  test-email-vars
  =/  known=(list [@t @t])
    :~  ['first' 'x']  ['link' 'x']  ['total' 'x']  ['track' 'x']
        ['people' 'x']  ['position' 'x']  ['day' 'x']  ['email' 'x']
        ['site' 'x']  ['event' 'x']
    ==
  =/  c=json  starter-copy:reg
  ?.  ?=([%o *] c)  (expect-eq !>('an object') !>(c))
  =/  keys=(list @t)  ~(tap in ~(key by p.c))
  |-  ^-  tang
  ?~  keys  ~
  =/  k=@t  i.keys
  ?.  =('email.' (end [3 6] k))  $(keys t.keys)
  =/  filled=@t  (fill:reg (gs:reg c k) known)
  %+  weld
    ::  the key is named in the failure, or a red line says nothing useful
    (expect-eq !>([k '']) !>([k ?:(=(~ (find (trip '{{') (trip filled))) '' filled)]))
  $(keys t.keys)
++  test-with-starter
  =/  old=json  (jo '{"landing.title": "Ours", "form.person": "Walker {{n}}"}')
  =/  got=json  (with-starter:reg old)
  ;:  weld
    (expect !>(=('Ours' (gs:reg got 'landing.title'))))
    (expect !>(=('Walker {{n}}' (gs:reg got 'form.person'))))
    (expect !>(!=('' (gs:reg got 'form.same_weekend'))))
    (expect !>(!=('' (gs:reg got 'email.manage.body'))))
    (expect !>(!=('' (gs:reg got 'email.checkin.body'))))
    (expect !>(=(starter-copy:reg (with-starter:reg [%o ~]))))
    (expect !>(=(starter-copy:reg (with-starter:reg starter-copy:reg))))
  ==
::  +test-with-starter-retires: a key the code no longer uses is dropped
::  on the way out. Nothing renders it, so nobody could reach it to
::  correct it; carrying it would leave a dead string in the document
::  that looks like one that matters. Every live key keeps its value.
::
++  test-with-starter-retires
  =/  old=json
    (jo '{"landing.title": "Ours", "next.waiver.button": "Sign the waiver", "made.up.key": "x"}')
  =/  got=json  (with-starter:reg old)
  ;:  weld
    (expect !>(=('Ours' (gs:reg got 'landing.title'))))
    (expect !>(!(has-key:reg got 'next.waiver.button')))
    (expect !>(!(has-key:reg got 'made.up.key')))
    ::  and the count is the code's list, whatever the ship was holding
    =/  n  |=(j=json ^-(@ud ?.(?=([%o *] j) 0 ~(wyt by p.j))))
    (expect-eq !>((n starter-copy:reg)) !>((n got)))
  ==
::  +test-copy-person-name: the form calls a person by the name typed for
::  them, so every string that names one carries a placeholder for the
::  page to fill. The weekend radio names the first person; the card
::  headings, the remove button and the first-time box name their own.
::
++  test-copy-person-name
  =/  c=json  starter-copy:reg
  =/  same=@t  (gs:reg c 'form.same_weekend')
  =/  week=@t  (gs:reg c 'form.weekend')
  =/  about=@t  (gs:reg c 'form.about')
  =/  gone=@t  (gs:reg c 'form.remove_person')
  =/  once=@t  (gs:reg c 'form.first_bsc')
  ;:  weld
    (expect !>(!=(same (fill:reg same ~[['first' 'Ana Silva']]))))
    (expect !>(!=(week (fill:reg week ~[['name' 'Ana Silva']]))))
    (expect !>(!=(about (fill:reg about ~[['name' 'Ana Silva']]))))
    (expect !>(!=(gone (fill:reg gone ~[['name' 'Ana Silva']]))))
    (expect !>(!=(once (fill:reg once ~[['name' 'Ana Silva']]))))
    (expect !>(!=('' (gs:reg c 'form.person'))))
    (expect !>(!=('' (gs:reg c 'form.you'))))
    (expect !>(!=('' (gs:reg c 'form.weekend.you'))))
    (expect !>(!=('' (gs:reg c 'form.about.you'))))
    (expect !>(!=('' (gs:reg c 'form.first_bsc.you'))))
  ==
::  ==  the shape ladder
::
++  test-read-reg-1
  =/  o=reg-1:reg  old-reg
  =/  got=(unit reg:reg)  (read-reg:reg `stored-reg-1:reg`[%1 o])
  ?>  ?=(^ got)
  =/  r=reg:reg  u.got
  =/  one=person:reg  (first-of people.r)
  ;:  weld
    (expect-eq !>('abc123') !>(id.r))
    (expect-eq !>(%complete) !>(status.r))
    (expect-eq !>(2) !>((lent people.r)))
    ::  a %1 grub reads as the newest shape with every field the later
    ::  versions added at its default
    (expect !>(!exempt.r))
    (expect !>(=(%$ prior.r)))
    (expect !>(!mass-sat.one))
    (expect !>(!mass-sun.one))
    (expect !>(!trolley.one))
    ::  and what it did carry is untouched
    (expect !>(mass-fri.one))
    (expect !>(bus.one))
  ==
::  +test-read-reg-2: the shape before the person grew, lifted
++  test-read-reg-2
  =/  o=reg-2:reg  old-reg-2
  =/  got=(unit reg:reg)  (read-reg:reg `stored-reg-2:reg`[%2 o])
  ?>  ?=(^ got)
  =/  r=reg:reg  u.got
  =/  one=person:reg  (first-of people.r)
  ;:  weld
    (expect-eq !>('abc123') !>(id.r))
    (expect-eq !>(2) !>((lent people.r)))
    ::  what %2 already knew is carried, including the organizer's marks
    (expect !>(exempt.r))
    (expect-eq !>(%payment) !>(prior.r))
    (expect !>(mass-fri.one))
    (expect-eq !>('Ana') !>(first.one))
    ::  and the three the person gained are false
    (expect !>(!mass-sat.one))
    (expect !>(!mass-sun.one))
    (expect !>(!trolley.one))
  ==
::  ==  exempt and reinstate
::
++  test-tally-exempt
  =/  now=@da  (add t0 ~h1)
  =/  plain=reg:reg  (some-reg %a %complete %full 3 t0)
  =/  free=reg:reg  =/(r (some-reg %b %complete %full 2 t0) r(exempt &))
  =/  c=counts:reg  (tally:reg st ~[plain free] now)
  =/  adm=counts:reg  (tally:reg st ~[free(source %admin)] now)
  =/  bam=counts:reg  (tally:reg st ~[free(track %bambino)] now)
  ;:  weld
    ::  only the three non-exempt walkers hold a track spot
    (expect-eq !>(3) !>(full.c))
    ::  the exempt party still takes its socials
    (expect-eq !>(5) !>(social-fri.c))
    (expect-eq !>(5) !>(social-sat.c))
    (expect-eq !>(0) !>(late.c))
    ::  an exempt organizer add takes no late-add spot
    (expect-eq !>(0) !>(late.adm))
    (expect-eq !>(2) !>(social-sat.adm))
    (expect-eq !>(0) !>(bambino.bam))
  ==
::  +test-who-the-caps-count: what holds a track spot, and what does not.
::
::  Only two things take somebody out of the count: they registered to
::  walk on no day at all, or an organizer marked their registration
::  exempt. Being a Knight or Dame of the Order of Malta does NOT, and
::  neither does volunteering; both are recorded on the person and
::  neither is read by +tally. This is pinned because the backoffice
::  puts "Order of Malta and volunteers" next to "exempt" in the same
::  list of segments, which reads like a rule and is not one.
::
++  test-who-the-caps-count
  =/  now=@da  (add t0 ~h1)
  ::  some-person is an arm, so it is bound before it is mutated
  =/  one=person:reg  some-person
  =/  kd=person:reg  one(knight-dame &, volunteer &)
  =/  idle=person:reg  one(days [fri=| sat=| sun=|])
  =/  base=reg:reg  (some-reg %a %complete %full 1 t0)
  =/  knights=reg:reg  base(people ~[kd kd kd])
  =/  nobody=reg:reg  base(people ~[idle idle])
  =/  mixed=reg:reg  base(people ~[kd idle one])
  ;:  weld
    ::  three Knights and Dames are three pilgrims on the beach
    (expect-eq !>(3) !>(full:(tally:reg st ~[knights] now)))
    ::  two people who walk on no day take no spot
    (expect-eq !>(0) !>(full:(tally:reg st ~[nobody] now)))
    ::  and in one party, only the two who walk are counted
    (expect-eq !>(2) !>(full:(tally:reg st ~[mixed] now)))
    ::  the organizer's mark is the only other way out of the count
    (expect-eq !>(0) !>(full:(tally:reg st ~[knights(exempt &)] now)))
  ==
::  +test-roster-row-every-box: what a day's roster says about somebody
::  who ticked every box, and about somebody who ticked none.
::
::  Each of these is either that day's own question or a question asked
::  on one day only, and nothing pinned which. The mutation run said so
::  in as many words: dropping the day gate off the trolley, the Holy
::  Hour, Friday's Mass or the Sunday distance changed nothing any test
::  read. A ticked box that shows on the wrong day is a pilgrim counted
::  for a meal they never asked for; a box that shows when it was never
::  ticked is the same pilgrim counted twice.
::
++  test-roster-row-every-box
  =/  one=person:reg  some-person
  =/  every=person:reg
    %=  one
      days  [fri=& sat=& sun=&]
      sun-ten  &  mass-fri  &  mass-sat  &  mass-sun  &
      holy-hour  &  social-fri  &  social-sat  &  bus  &  trolley  &
    ==
  =/  nought=person:reg
    %=  one
      days  [fri=& sat=& sun=&]
      sun-ten  |  mass-fri  |  mass-sat  |  mass-sun  |
      holy-hour  |  social-fri  |  social-sat  |  bus  |  trolley  |
    ==
  =/  row  |=([p=person:reg day=@tas k=@t] ^-(? (gb:reg (en-roster-person:reg p day 0) k)))
  ::  everything ticked: each field on the days it belongs to, and only those
  =/  all-on=(list [day=@tas k=@t v=?])
    :~  [%fri 'walks' &]   [%fri 'bus' &]       [%fri 'trolley' |]
        [%fri 'mass' &]    [%fri 'mass_fri' &]  [%fri 'holy_hour' &]
        [%fri 'social' &]  [%fri 'sun_ten' |]
        [%sat 'walks' &]   [%sat 'bus' &]       [%sat 'trolley' |]
        [%sat 'mass' &]    [%sat 'mass_fri' |]  [%sat 'holy_hour' |]
        [%sat 'social' &]  [%sat 'sun_ten' |]
        [%sun 'walks' &]   [%sun 'bus' &]       [%sun 'trolley' &]
        [%sun 'mass' &]    [%sun 'mass_fri' |]  [%sun 'holy_hour' |]
        [%sun 'social' |]  [%sun 'sun_ten' &]
    ==
  ::  Somebody who unticked Sunday but whose Sunday answers are still
  ::  stored. The form stops offering a day's events when the day is
  ::  unticked, and does not erase what was already there, so this is an
  ::  ordinary record and not a contrived one.
  ::
  ::  The Sunday distance is gated on actually walking Sunday and so
  ::  falls away. The Sunday Mass and the trolley are NOT: they stand on
  ::  their own, because somebody may come to the Cathedral without
  ::  walking the last stretch. That is a decision rather than an
  ::  accident, and it is pinned here so it stays a decision.
  =/  no-sun=person:reg
    %=  one
      days  [fri=& sat=& sun=|]
      sun-ten  &  mass-sun  &  trolley  &
      mass-fri  |  mass-sat  |  holy-hour  |  social-fri  |  social-sat  |  bus  |
    ==
  =/  off-sun=(list [day=@tas k=@t v=?])
    :~  [%sun 'walks' |]    [%sun 'sun_ten' |]
        [%sun 'mass' &]     [%sun 'trolley' &]
    ==
  ::  nothing ticked: walking, and nothing else, on any day
  =/  all-off=(list [day=@tas k=@t v=?])
    :~
        [%fri 'walks' &]
        [%fri 'bus' |]
        [%fri 'trolley' |]
        [%fri 'mass' |]
        [%fri 'mass_fri' |]
        [%fri 'holy_hour' |]
        [%fri 'social' |]
        [%fri 'sun_ten' |]
        [%sat 'walks' &]
        [%sat 'bus' |]
        [%sat 'trolley' |]
        [%sat 'mass' |]
        [%sat 'mass_fri' |]
        [%sat 'holy_hour' |]
        [%sat 'social' |]
        [%sat 'sun_ten' |]
        [%sun 'walks' &]
        [%sun 'bus' |]
        [%sun 'trolley' |]
        [%sun 'mass' |]
        [%sun 'mass_fri' |]
        [%sun 'holy_hour' |]
        [%sun 'social' |]
        [%sun 'sun_ten' |]
    ==
  %+  weld
    |-  ^-  tang
    ?~  all-on  ~
    %+  weld
      %+  expect-eq  !>([day.i.all-on k.i.all-on v.i.all-on])
      !>  [day.i.all-on k.i.all-on (row every day.i.all-on k.i.all-on)]
    $(all-on t.all-on)
  %+  weld
    |-  ^-  tang
    ?~  all-off  ~
    %+  weld
      %+  expect-eq  !>([day.i.all-off k.i.all-off v.i.all-off])
      !>  [day.i.all-off k.i.all-off (row nought day.i.all-off k.i.all-off)]
    $(all-off t.all-off)
  |-  ^-  tang
  ?~  off-sun  ~
  %+  weld
    %+  expect-eq  !>([day.i.off-sun k.i.off-sun v.i.off-sun])
    !>  [day.i.off-sun k.i.off-sun (row no-sun day.i.off-sun k.i.off-sun)]
  $(off-sun t.off-sun)
::  +test-planned-every-box: the same truth, counted over a party. The
::  Sunday distance splits: the one who chose ten miles and the one who
::  did not are counted apart, and on Friday and Saturday neither is
::  counted at all.
::
++  test-planned-every-box
  =/  one=person:reg  some-person
  =/  every=person:reg
    %=  one
      days  [fri=& sat=& sun=&]
      sun-ten  &  mass-fri  &  mass-sat  &  mass-sun  &
      holy-hour  &  social-fri  &  social-sat  &  bus  &  trolley  &
    ==
  =/  nought=person:reg
    %=  one
      days  [fri=& sat=& sun=&]
      sun-ten  |  mass-fri  |  mass-sat  |  mass-sun  |
      holy-hour  |  social-fri  |  social-sat  |  bus  |  trolley  |
    ==
  =/  r=reg:reg  (some-reg %a %complete %full 1 t0)
  ::  a third who is not walking Sunday, with a stale Sunday distance,
  ::  and a fourth who is not walking Sunday and never chose one. The
  ::  fourth is what keeps the short-walk count honest: without the gate
  ::  on actually walking Sunday they would be counted among the people
  ::  doing the last two and a half miles.
  =/  no-sun=person:reg  every(days [fri=& sat=& sun=|])
  =/  no-sun-plain=person:reg  nought(days [fri=& sat=& sun=|])
  =/  regs=(list reg:reg)  ~[r(people ~[every nought no-sun no-sun-plain])]
  =/  n  |=([day=@tas k=@t] ^-(@ud (fall (gn:reg (planned:reg regs day) k) 999)))
  =/  want=(list [day=@tas k=@t v=@ud])
    :~  [%fri 'walk' 4]  [%fri 'mass' 2]  [%fri 'holy_hour' 2]  [%fri 'social' 2]
        [%fri 'bus' 2]   [%fri 'trolley' 0]  [%fri 'sun_ten' 0]  [%fri 'sun_short' 0]
        [%sat 'walk' 4]  [%sat 'mass' 2]  [%sat 'holy_hour' 0]  [%sat 'social' 2]
        [%sat 'bus' 2]   [%sat 'trolley' 0]  [%sat 'sun_ten' 0]  [%sat 'sun_short' 0]
        ::  two of the four walk on Sunday. The two who do not are still
        ::  counted at Mass and on the trolley, which stand alone, and in
        ::  neither distance, which does not.
        [%sun 'walk' 2]  [%sun 'mass' 2]  [%sun 'holy_hour' 0]  [%sun 'social' 0]
        [%sun 'bus' 2]   [%sun 'trolley' 2]  [%sun 'sun_ten' 1]  [%sun 'sun_short' 1]
    ==
  |-  ^-  tang
  ?~  want  ~
  %+  weld
    (expect-eq !>([day.i.want k.i.want v.i.want]) !>([day.i.want k.i.want (n day.i.want k.i.want)]))
  $(want t.want)
++  test-reinstate
  =/  r=reg:reg  (some-reg %a %complete %full 2 t0)
  =/  gone=reg:reg
    (set-status:reg r(prior %complete) %cancelled 'admin:sue' 'cancelled: gone' (add t0 ~m1))
  =/  back=(unit reg:reg)  (reinstate:reg gone 'admin:sue' (add t0 ~m2))
  ?>  ?=(^ back)
  =/  b=reg:reg  u.back
  ;:  weld
    (expect !>((transition-ok:reg %cancelled %complete)))
    (expect !>((transition-ok:reg %cancelled %waitlist)))
    (expect !>(!(transition-ok:reg %cancelled %draft)))
    ::  a cancel then a reinstate lands on the status the cancel left
    (expect-eq !>(%complete) !>(status.b))
    (expect-eq !>('reinstated') !>(what:(rear history.b)))
    ::  a row that was never cancelled cannot be reinstated
    (expect-eq !>(`(unit reg:reg)`~) !>((reinstate:reg r 'admin:sue' t0)))
    ::  neither can a cancel that kept no prior
    (expect-eq !>(`(unit reg:reg)`~) !>((reinstate:reg gone(prior %$) 'admin:sue' t0)))
  ==
::  ==  csv
::
++  test-csv-cell
  =/  nl=@t  (rap 3 'a' '\0a' 'b' ~)
  ;:  weld
    (expect-eq !>('plain') !>((csv-cell:reg 'plain')))
    ::  a comma quotes the cell
    (expect-eq !>('"a,b"') !>((csv-cell:reg 'a,b')))
    ::  a quote is doubled inside a quoted cell
    (expect-eq !>('"say ""hi"""') !>((csv-cell:reg 'say "hi"')))
    (expect-eq !>('""""') !>((csv-cell:reg '"')))
    ::  a newline quotes the cell too
    (expect-eq !>('"') !>((end [3 1] (csv-cell:reg nl))))
  ==
++  test-csv-columns
  =/  regs=(list reg:reg)
    :~  (some-reg %aaa %complete %full 2 t0)
        =/(r (some-reg %bbb %waitlist %bambino 1 t0) r(notes 'needs a ride'))
    ==
  =/  ppl=(list @t)  (split-nl (csv-people:reg regs st))
  =/  rws=(list @t)  (split-nl (csv-regs:reg regs st))
  ?>  ?=(^ ppl)
  ?>  ?=(^ rws)
  =/  hp=@ud  (count-commas i.ppl)
  =/  hr=@ud  (count-commas i.rws)
  ;:  weld
    ::  the header and one row per person
    (expect-eq !>(4) !>((lent ppl)))
    ::  the width is pinned on purpose: a spreadsheet somebody built on
    ::  last year's export breaks when a column appears. 48 since Mass on
    ::  Saturday and Sunday and the trolley were added.
    (expect-eq !>(48) !>(hp))
    ::  every row carries the header's column count
    (expect !>((levy `(list @t)`t.ppl |=(l=@t =(hp (count-commas l))))))
    ::  the header and one row per registration
    (expect-eq !>(3) !>((lent rws)))
    (expect-eq !>(30) !>(hr))
    (expect !>((levy `(list @t)`t.rws |=(l=@t =(hr (count-commas l))))))
    (expect-eq !>('rid') !>((end [3 3] i.ppl)))
  ==
::  ==  the bundle
::
++  test-bundle-jam
  =/  b=bundle:reg
    [%1 ~[(some-reg %aaa %complete %full 2 t0)] starter-settings:reg starter-copy:reg [%o ~]]
  =/  a=@  (jam-bundle:reg b)
  ;:  weld
    ::  jam then cue is identity
    (expect-eq !>(`(unit bundle:reg)`[~ b]) !>((cue-bundle:reg a)))
    ::  a truncated atom answers ~ instead of crashing
    (expect-eq !>(`(unit bundle:reg)`~) !>((cue-bundle:reg (rsh [0 1] a))))
    (expect-eq !>(`(unit bundle:reg)`~) !>((cue-bundle:reg 42)))
  ==
++  test-bundle-json
  =/  p=person:reg  some-person
  =/  cks=(list [@tas checkin:reg])
    ~[[%fri [t0 'admin:sue']] [%sun [(add t0 ~d2) 'admin:lee']]]
  =/  pc=person:reg  p(checkins (malt cks))
  =/  r0=reg:reg  (some-reg %abc123def0 %complete %full 1 t0)
  =/  r=reg:reg
    %=  r0
      people   ~[pc]
      notes    'a note'
      exempt   &
      prior    %payment
      payment  [%check 15.000 500 `t0 'chk 41' & 'by hand']
      waiver   [%paper '' %completed `t0]
      history  ~[[t0 'pilgrim' 'submitted'] [(add t0 ~m5) 'admin:sue' 'edited']]
    ==
  =/  b=bundle:reg  [%1 ~[r] starter-settings:reg starter-copy:reg [%o ~]]
  =/  j=json  (en-bundle:reg b)
  =/  broke=json
    (pairs:enjs:format ~[['regs' a+~[(pairs:enjs:format ~[['id' s+'oops']])]]])
  =/  back  (de-bundle-why:reg j)
  ::  a stamp under a second: the documented round trip drops the
  ::  fraction, so what comes back is the whole second
  =/  sub=@da  (add t0 ~s0..8000)
  =/  fine=reg:reg  r(created sub, history ~[[sub 'pilgrim' 'submitted']])
  =/  whole=reg:reg  r(history ~[[t0 'pilgrim' 'submitted']])
  =/  bf=bundle:reg  b(regs ~[fine])
  =/  bw=bundle:reg  b(regs ~[whole])
  ;:  weld
    ::  the JSON round trip is identity, history and check-ins included
    (expect-eq !>(`(unit bundle:reg)`[~ b]) !>((de-bundle:reg j)))
    (expect !>(?=(%& -.back)))
    ::  a sub-second stamp is not the same noun, and it rounds to the second
    (expect !>(?!(=(fine whole))))
    (expect-eq !>('2026-10-01T12:00:00Z') !>((en-iso:reg sub)))
    (expect-eq !>(`(unit bundle:reg)`[~ bw]) !>((de-bundle:reg (en-bundle:reg bf))))
    ::  a registration that will not read names itself and its field
    (expect-eq !>('regs: oops: id is not ten lowercase hex digits') !>((why-of (de-bundle-why:reg broke))))
    (expect-eq !>(`(each bundle:reg @t)`[%| 'bundle: regs is missing']) !>((de-bundle-why:reg `json`[%o ~])))
    (expect-eq !>(`(each bundle:reg @t)`[%| 'bundle: a JSON object is required']) !>((de-bundle-why:reg `json`~)))
  ==
::  +test-bundle-docs: a bundle whose settings, copy or counts is not an
::  object must refuse, or the restore writes a JSON null over a document
::
++  test-bundle-docs
  =/  bare=json  (pairs:enjs:format ~[['regs' a+~]])
  =/  got  (de-bundle-why:reg bare)
  =/  want=bundle:reg  [%1 ~ ~ ~ ~]
  =/  nulls=json
    %-  pairs:enjs:format
    :~  ['regs' a+~]  ['settings' ~]  ['copy' ~]  ['counts' ~]
    ==
  ;:  weld
    ::  a regs-only bundle reads, with no document of its own
    (expect !>(?=(%& -.got)))
    (expect-eq !>(`(unit bundle:reg)`[~ want]) !>((de-bundle:reg bare)))
    ::  an explicit JSON null in a document slot is refused, not written
    (expect-eq !>('bundle: settings is not an object') !>((why-of (de-bundle-why:reg nulls))))
    %+  expect-eq  !>('bundle: settings is not an object')
    !>((why-of (de-bundle-why:reg (put-key bare 'settings' n+'7'))))
    %+  expect-eq  !>('bundle: copy is not an object')
    !>((why-of (de-bundle-why:reg (put-key bare 'copy' a+~))))
    %+  expect-eq  !>('bundle: counts is not an object')
    !>((why-of (de-bundle-why:reg (put-key bare 'counts' s+'nope'))))
    ::  a real document still reads
    (expect !>((reads (de-bundle-why:reg (put-key bare 'settings' starter-settings:reg)))))
  ==
::  +test-de-reg-full: every field a backup carries is checked, and the
::  refusal names the registration and the field it choked on
::
++  test-de-reg-full
  =/  r0=reg:reg  (some-reg %abc123def0 %complete %full 1 t0)
  =/  good=json  (en-reg-full:reg r0)
  =/  bad
    |=  [k=@t v=json]
    ^-  @t
    (why-of (de-bundle-why:reg (one-bundle (put-key good k v))))
  =/  stamped=json
    %-  put-key
    :+  good  'history'
    a+~[(pairs:enjs:format ~[['at' s+'yesterday'] ['by' s+'sue'] ['what' s+'edited']])]
  =/  tapped=json
    %-  put-key
    :+  good  'people'
    :-  %a
    :~  %^  put-key  (en-person:reg some-person)  'checkins'
        (pairs:enjs:format ~[['fri' (pairs:enjs:format ~[['at' s+'never'] ['by' s+'sue']])]])
    ==
  ;:  weld
    ::  the good one reads
    (expect !>((reads (de-bundle-why:reg (one-bundle good)))))
    ::  every named field, with the id and the field in the message
    (expect-eq !>('regs: abc123def0: status nope is not a status') !>((bad 'status' s+'nope')))
    (expect-eq !>('regs: abc123def0: track walking is not a track') !>((bad 'track' s+'walking')))
    (expect-eq !>('regs: abc123def0: source phone is not a source') !>((bad 'source' s+'phone')))
    (expect-eq !>('regs: abc123def0: prior nope is not a status') !>((bad 'prior' s+'nope')))
    (expect-eq !>('regs: abc123def0: created will not read') !>((bad 'created' s+'soon')))
    (expect-eq !>('regs: abc123def0: updated will not read') !>((bad 'updated' s+'soon')))
    ::  a blank prior is the registration that was never cancelled
    (expect !>((reads (de-bundle-why:reg (one-bundle (put-key good 'prior' s+''))))))
    (expect !>((reads (de-bundle-why:reg (one-bundle (put-key good 'prior' s+'payment'))))))
    ::  the payment and the waiver name their own field
    %+  expect-eq  !>('regs: abc123def0: payment method venmo is not one the ship writes')
    !>((bad 'payment' (put-key (en-payment:reg payment.r0) 'method' s+'venmo')))
    %+  expect-eq  !>('regs: abc123def0: waiver method fax is not one the ship writes')
    !>((bad 'waiver' (put-key (en-waiver:reg waiver.r0) 'method' s+'fax')))
    %+  expect-eq  !>('regs: abc123def0: waiver status torn is not one the ship writes')
    !>((bad 'waiver' (put-key (en-waiver:reg waiver.r0) 'status' s+'torn')))
    ::  a stamp that will not parse refuses the registration
    %+  expect-eq  !>('regs: abc123def0: a history stamp will not read')
    !>((why-of (de-bundle-why:reg (one-bundle stamped))))
    %+  expect-eq  !>('regs: abc123def0: check-in fri has a stamp that will not read')
    !>((why-of (de-bundle-why:reg (one-bundle tapped))))
  ==
::  ==  the roster row
::
++  test-en-row
  =/  p=person:reg  some-person
  =/  nw=person:reg  p(days [| | |], knight-dame &)
  =/  r0=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  =/  r=reg:reg  r0(people ~[p nw(last 'Bo', first 'Cy')])
  =/  j=json  (en-row:reg r 15.000 0)
  =/  names=(list @t)  (strings:reg (ga:reg j 'names'))
  =/  flat=json  (en-row:reg r0(people ~[nw]) 7.500 0)
  ;:  weld
    (expect-eq !>('abc123') !>((gs:reg j 'id')))
    (expect-eq !>('abc123') !>((gs:reg j 'email')))
    (expect-eq !>('FL') !>((gs:reg j 'state')))
    ::  one "Last, First" per person, in the party's order
    (expect-eq !>(`(list @t)`~['Silva, Ana' 'Bo, Cy']) !>(names))
    (expect-eq !>(`(unit @ud)`[~ 2]) !>((gn:reg j 'people')))
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((gn:reg j 'walkers')))
    (expect-eq !>(`(unit @ud)`[~ 15.000]) !>((gn:reg j 'fees')))
    (expect !>((gb:reg j 'knight_dame')))
    (expect !>(!(gb:reg j 'volunteer')))
    (expect !>(!(gb:reg j 'nonwalker')))
    ::  a party in which nobody walks
    (expect !>((gb:reg flat 'nonwalker')))
    (expect-eq !>('none') !>((gs:reg j 'paid')))
    (expect-eq !>('none') !>((gs:reg j 'waiver')))
    (expect !>(!(has-key:reg j 'token')))
    ::  the plan block counts the party per day and per activity
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((gn:reg (gj:reg j 'plan') 'fri')))
    (expect-eq !>(`(unit @ud)`[~ 2]) !>((gn:reg (gj:reg j 'plan') 'social_sat')))
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((gn:reg (gj:reg j 'plan') 'knight_dame')))
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((gn:reg (gj:reg flat 'plan') 'sun')))
  ==
::  ==  the check-in
::
++  test-checkin-day
  ;:  weld
    (expect-eq !>(`(unit @tas)`[~ %fri]) !>((checkin-day:reg 'fri')))
    (expect-eq !>(`(unit @tas)`[~ %sat]) !>((checkin-day:reg 'sat')))
    (expect-eq !>(`(unit @tas)`[~ %sun]) !>((checkin-day:reg 'sun')))
    (expect-eq !>(`(unit @tas)`~) !>((checkin-day:reg 'mon')))
    (expect-eq !>(`(unit @tas)`~) !>((checkin-day:reg '')))
  ==
::  +test-event-day: the ship's clock is UTC and the event is in
::  Florida, so the day turns over at 05:00 UTC, not at midnight. The
::  three dates are Friday, Saturday and Sunday in order.
++  test-event-day
  =/  days=(list @t)  ~['2026-12-04' '2026-12-05' '2026-12-06']
  =/  off=@sd  -5
  ;:  weld
    (expect-eq !>(`(unit @tas)`~) !>((event-day:reg days off ~2026.12.3..12.00.00)))
    (expect-eq !>(`(unit @tas)`[~ %fri]) !>((event-day:reg days off ~2026.12.4..12.00.00)))
    ::  00:30 UTC on the 5th is 7:30pm Friday in Florida
    (expect-eq !>(`(unit @tas)`[~ %fri]) !>((event-day:reg days off ~2026.12.5..00.30.00)))
    ::  the day turns at 05:00 UTC
    (expect-eq !>(`(unit @tas)`[~ %fri]) !>((event-day:reg days off ~2026.12.5..04.59.59)))
    (expect-eq !>(`(unit @tas)`[~ %sat]) !>((event-day:reg days off ~2026.12.5..05.00.00)))
    (expect-eq !>(`(unit @tas)`[~ %sun]) !>((event-day:reg days off ~2026.12.6..20.00.00)))
    (expect-eq !>(`(unit @tas)`~) !>((event-day:reg days off ~2026.12.7..12.00.00)))
    ::  a positive offset moves the other way
    (expect-eq !>(`(unit @tas)`[~ %sat]) !>((event-day:reg days --7 ~2026.12.4..20.00.00)))
    ::  a shorter list still answers for the days it has
    (expect-eq !>(`(unit @tas)`[~ %sat]) !>((event-day:reg ~['2026-12-04' '2026-12-05'] off ~2026.12.5..12.00.00)))
    (expect-eq !>(`(unit @tas)`~) !>((event-day:reg ~['2026-12-04' '2026-12-05'] off ~2026.12.6..12.00.00)))
    ::  over, and the next date
    (expect !>(!(event-over:reg days off ~2026.12.6..23.00.00)))
    (expect !>((event-over:reg days off ~2026.12.7..12.00.00)))
    (expect !>(!(event-over:reg ~ off ~2026.12.7..12.00.00)))
    (expect-eq !>('2026-12-04') !>((next-event-day:reg days off ~2026.11.1..12.00.00)))
    ::  03:00 UTC on the 5th is 10pm Friday in Florida: Friday is not yet past
    (expect-eq !>('2026-12-04') !>((next-event-day:reg days off ~2026.12.5..03.00.00)))
    ::  a fourth date is never an event day, so it is not read at all
    (expect-eq !>(`(list @t)`~['2026-12-04' '2026-12-05' '2026-12-06']) !>((event-days:reg (jo '{"event": {"days": ["2026-12-04", "2026-12-05", "2026-12-06", "2026-12-07"]}}'))))
    (expect-eq !>('') !>((next-event-day:reg days off ~2026.12.7..12.00.00)))
    ::  the setting reads back, and is -5 when absent
    (expect-eq !>(`@sd`-5) !>(offset:st))
    (expect-eq !>(`@sd`--7) !>(offset:(de-settings:reg (jo '{"event": {"utc_offset_hours": 7}}'))))
    (expect-eq !>(`@sd`-11) !>(offset:(de-settings:reg (jo '{"event": {"utc_offset_hours": -11}}'))))
    (expect-eq !>(`(list @t)`~['2026-12-04' '2026-12-05' '2026-12-06']) !>((event-days:reg starter-settings:reg)))
  ==
::  +test-checkin-counts: the day view's percentage counts only complete
::  parties, and only the people who are there that day
::  +test-mass-and-trolley: Mass belongs to its own day and the trolley
::  to Sunday, for both tracks
++  test-mass-and-trolley
  =/  p=person:reg  some-person
  =/  sunday=person:reg  p(first 'Eve', days [| | &], mass-fri |, mass-sun &, trolley &)
  =/  base=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  =/  r=reg:reg  base(people ~[p(mass-sat &, mass-sun &) sunday])
  =/  fri=json  (planned:reg ~[r] %fri)
  =/  sat=json  (planned:reg ~[r] %sat)
  =/  sun=json  (planned:reg ~[r] %sun)
  =/  n  |=([j=json k=@t] ^-((unit @ud) (gn:reg j k)))
  =/  row=json  (en-roster-row:reg r %sun)
  =/  folk=(list json)  (ga:reg row 'people')
  ;:  weld
    ::  one at Friday Mass, one at Saturday's, both on Sunday
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((n fri 'mass')))
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((n sat 'mass')))
    (expect-eq !>(`(unit @ud)`[~ 2]) !>((n sun 'mass')))
    ::  the trolley is counted on Sunday and on no other day
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((n sun 'trolley')))
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((n fri 'trolley')))
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((n sat 'trolley')))
    ::  +mass-day answers for the day it is asked about
    (expect !>((mass-day:reg %sun sunday)))
    (expect !>(!(mass-day:reg %fri sunday)))
    ::  the volunteers' card carries that day's Mass and the trolley
    (expect !>((gb:reg (at-n folk 1) 'mass')))
    (expect !>((gb:reg (at-n folk 1) 'trolley')))
    (expect !>(!(gb:reg (at-n (ga:reg (en-roster-row:reg r %fri) 'people') 1) 'trolley')))
  ==
::  +test-waiver-text: the terms, their fingerprint, and the room they
::  are allowed. The adoption records the fingerprint, so it has to move
::  when the words move and hold still when they do not.
++  test-waiver-text
  =/  c=json  starter-copy:reg
  =/  text=@t  (gs:reg c 'waiver.text')
  =/  h=@t  (hash-text:reg text)
  ;:  weld
    ::  the organizers' own agreement is there, whole, in paragraphs
    (expect !>(!=('' text)))
    (expect !>((gth (met 3 text) 5.000)))
    (expect !>(!=(~ (find ~[10 10] (trip text)))))
    ::  the parties it releases and the clauses it is made of
    (expect !>(!=(~ (find "Sovereign Military Hospitaller Order" (trip text)))))
    (expect !>(!=(~ (find "Diocese of St. Augustine" (trip text)))))
    (expect !>(!=(~ (find "7. I hereby declare" (trip text)))))
    ::  and the placeholder it replaced is gone
    (expect !>(=(~ (find "REPLACE THIS" (trip text)))))
    ::  it fits the room the waiver key is given, with plenty to spare
    (expect !>(!(over-cap:reg text (copy-cap:reg 'waiver.text'))))
    ::  the same words hash the same, a changed word does not
    (expect-eq !>(h) !>((hash-text:reg text)))
    (expect !>(!=(h (hash-text:reg (cat 3 text ' ')))))
    (expect !>(!=((hash-text:reg 'a') (hash-text:reg 'b'))))
    ::  the terms get room that a one-line string does not
    (expect-eq !>(20.000) !>((copy-cap:reg 'waiver.text')))
    (expect-eq !>(4.000) !>((copy-cap:reg 'landing.title')))
    ::  and the words a pilgrim presses are there
    (expect !>(!=('' (gs:reg c 'waiver.agree'))))
    (expect !>(!=('' (gs:reg c 'waiver.adopt'))))
    (expect !>(!=('' (gs:reg c 'waiver.scroll'))))
    (expect !>(!=('' (gs:reg c 'waiver.stale'))))
    ::  an adopted waiver reads back, and a method nobody knows does not
    (expect !>(?=([%& *] (de-waiver:reg (jo '{"method": "adopt", "envelope": "0x1", "status": "completed"}')))))
    (expect !>(?=([%| *] (de-waiver:reg (jo '{"method": "smoke", "status": "completed"}')))))
  ==
++  test-checkin-counts
  =/  p=person:reg  some-person
  =/  kid=person:reg  p(first 'Bo', child &, days [| | &], sun-ten |, social-fri |, social-sat |, mass-fri |, bus |)
  =/  base=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  =/  full=reg:reg  base(people ~[p p kid], waiver [%stub '' %completed `t0])
  =/  owing=reg:reg  base(id %def456, status %payment, people ~[p])
  =/  done=reg:reg  (need (with-checkin:reg full 0 %fri 'pilgrim' t1 |))
  =/  paid-in=reg:reg  (need (with-checkin:reg owing 0 %fri 'admin:Sue' t1 |))
  =/  regs=(list reg:reg)  ~[done paid-in]
  =/  page=json  (en-checkin-page:reg done `%fri | '')
  =/  people=(list json)  (ga:reg page 'people')
  ::  not an event day: nobody is checked, the date to come back is named
  =/  early=json  (en-checkin-page:reg done ~ | '2026-12-04')
  ;:  weld
    (expect !>((there-that-day:reg done %fri)))
    (expect !>(!(there-that-day:reg base(people ~[kid]) %fri)))
    (expect-eq !>(2) !>((checkin-expected:reg regs %fri)))
    (expect-eq !>(3) !>((checkin-expected:reg regs %sun)))
    (expect-eq !>(1) !>((checkin-done:reg regs %fri)))
    (expect-eq !>(0) !>((checkin-done:reg regs %sat)))
    ::  the page: three people, the first checked, the day named
    (expect-eq !>('fri') !>((gs:reg page 'day')))
    (expect-eq !>('complete') !>((gs:reg page 'status')))
    (expect-eq !>(3) !>((lent people)))
    (expect !>((gb:reg (at-n people 0) 'checked')))
    (expect !>(!(gb:reg (at-n people 1) 'checked')))
    (expect-eq !>('Bo') !>((gs:reg (at-n people 2) 'first')))
    (expect-eq !>('') !>((gs:reg early 'day')))
    (expect-eq !>('2026-12-04') !>((gs:reg early 'opens')))
    (expect !>(!(gb:reg (at-n (ga:reg early 'people') 0) 'checked')))
    (expect !>((gb:reg (en-checkin-page:reg done ~ & '') 'over')))
  ==
++  test-with-checkin
  =/  r=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  =/  one=reg:reg  (need (with-checkin:reg r 0 %fri 'admin:Sue' t1 |))
  =/  again=reg:reg  (need (with-checkin:reg one 0 %fri 'admin:Bob' t2 |))
  =/  gone=reg:reg  (need (with-checkin:reg one 0 %fri 'admin:Sue' t2 &))
  =/  gone2=reg:reg  (need (with-checkin:reg gone 0 %fri 'admin:Sue' t2 &))
  =/  first-p=person:reg  (snag 0 people.one)
  =/  second-p=person:reg  (snag 1 people.one)
  =/  after-p=person:reg  (snag 0 people.gone)
  =/  c=(unit checkin:reg)  (~(get by checkins.first-p) %fri)
  =/  set-line=step:reg  (rear history.one)
  =/  undo-line=step:reg  (rear history.gone)
  ;:  weld
    ::  the check-in carries the time and the volunteer
    (expect-eq !>(`(unit checkin:reg)`[~ [t1 'admin:Sue']]) !>(c))
    ::  nobody else in the party moved
    (expect-eq !>(0) !>(~(wyt by checkins.second-p)))
    (expect-eq !>('checked in Ana Silva fri') !>(what.set-line))
    (expect-eq !>('admin:Sue') !>(by.set-line))
    ::  setting a check-in that is already there changes nothing at all
    (expect !>(=(one again)))
    ::  the undo takes the day off and says so
    (expect-eq !>(0) !>(~(wyt by checkins.after-p)))
    (expect-eq !>('undid check-in Ana Silva fri') !>(what.undo-line))
    ::  undoing twice changes nothing
    (expect !>(=(gone gone2)))
    ::  a party has no person at that index
    (expect-eq !>(`(unit reg:reg)`~) !>((with-checkin:reg r 5 %fri 'admin:Sue' t1 |)))
  ==
++  test-wristband
  =/  done=reg:reg  (some-reg %abc123 %complete %full 1 t0)
  =/  green=reg:reg  done(waiver [%stub '' %completed `t0])
  =/  paper=reg:reg  done(waiver [%paper '' %none ~])
  =/  band  |=(r=reg:reg ^-((each ~ @t) (wristband:reg r)))
  ;:  weld
    (expect-eq !>(`(each ~ @t)`[%& ~]) !>((band green)))
    ::  a waiver signed on paper is signed
    (expect-eq !>(`(each ~ @t)`[%& ~]) !>((band paper)))
    (expect-eq !>(`(each ~ @t)`[%| 'waiver not signed']) !>((band done)))
    (expect-eq !>(`(each ~ @t)`[%| 'unpaid']) !>((band green(status %payment))))
    (expect-eq !>(`(each ~ @t)`[%| 'awaiting assistance decision']) !>((band green(status %assistance))))
    (expect-eq !>(`(each ~ @t)`[%| 'waiver not signed']) !>((band green(status %waiver))))
    (expect-eq !>(`(each ~ @t)`[%| 'on the wait list']) !>((band green(status %waitlist))))
    (expect-eq !>(`(each ~ @t)`[%| 'cancelled']) !>((band green(status %cancelled))))
    (expect-eq !>(`(each ~ @t)`[%| 'draft']) !>((band green(status %draft))))
    (expect-eq !>(`(each ~ @t)`[%| 'not registered']) !>((band green(status %nonsense))))
  ==
++  test-roster-row
  =/  p=person:reg  some-person
  =/  kid=person:reg  p(first 'Bo', last 'Silva', child &, sun-ten |, holy-hour &)
  =/  r0=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  =/  r1=reg:reg  r0(people ~[p kid], waiver [%stub '' %completed `t0])
  =/  r=reg:reg  (need (with-checkin:reg r1 1 %fri 'admin:Sue' t1 |))
  =/  fri=json  (en-roster-row:reg r %fri)
  =/  sun=json  (en-roster-row:reg r %sun)
  =/  folk=(list json)  (ga:reg fri 'people')
  =/  ana=json  (at-n folk 0)
  =/  bo=json  (at-n folk 1)
  =/  sun-ana=json  (at-n (ga:reg sun 'people') 0)
  ;:  weld
    (expect-eq !>('abc123') !>((gs:reg fri 'rid')))
    (expect-eq !>('complete') !>((gs:reg fri 'status')))
    ::  the email rides along for the search, and nothing else from the
    ::  contact leaves the ship
    (expect-eq !>('abc123') !>((gs:reg fri 'email')))
    (expect !>(!(has-key:reg fri 'phone')))
    (expect !>(!(has-key:reg fri 'street')))
    (expect !>((gb:reg (gj:reg fri 'wristband') 'ok')))
    (expect-eq !>('') !>((gs:reg (gj:reg fri 'wristband') 'why')))
    ::  each person carries their index, so a tap names them
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((gn:reg ana 'i')))
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((gn:reg bo 'i')))
    (expect-eq !>('Silva') !>((gs:reg ana 'last')))
    ::  the Friday row carries the Friday choices and the Friday social
    (expect !>((gb:reg ana 'walks')))
    (expect !>((gb:reg ana 'mass_fri')))
    (expect !>((gb:reg bo 'holy_hour')))
    (expect !>((gb:reg ana 'social')))
    ::  sun_ten belongs to Sunday only
    (expect !>(!(gb:reg ana 'sun_ten')))
    (expect !>((gb:reg sun-ana 'sun_ten')))
    ::  Sunday has no social and no Mass
    (expect !>(!(gb:reg sun-ana 'social')))
    (expect !>(!(gb:reg sun-ana 'mass_fri')))
    ::  the check-in shows on the person it was made for
    (expect !>(!(gb:reg ana 'checked')))
    (expect !>((gb:reg bo 'checked')))
    (expect-eq !>('admin:Sue') !>((gs:reg bo 'by')))
    (expect-eq !>(`(unit @da)`[~ t1]) !>((gt:reg bo 'at')))
  ==
++  test-planned
  =/  p=person:reg  some-person
  =/  kid=person:reg  p(first 'Bo', child &, sun-ten |, social-fri |, mass-fri |, bus |)
  =/  base=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  =/  full=reg:reg  base(people ~[p kid], waiver [%stub '' %completed `t0])
  =/  waiting=reg:reg  base(id %def456, status %waitlist, people ~[p])
  =/  done=reg:reg  (need (with-checkin:reg full 0 %fri 'admin:Sue' t1 |))
  =/  fri=json  (planned:reg ~[done waiting] %fri)
  =/  sun=json  (planned:reg ~[done waiting] %sun)
  =/  n  |=([j=json k=@t] ^-((unit @ud) (gn:reg j k)))
  ;:  weld
    ::  two walkers on Friday: the wait listed party plans nothing
    (expect-eq !>(`(unit @ud)`[~ 2]) !>((n fri 'walk')))
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((n fri 'mass')))
    ::  each day counts its own Mass, and the trolley is Sunday's alone
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((n sun 'mass')))
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((n fri 'trolley')))
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((n fri 'holy_hour')))
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((n fri 'social')))
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((n fri 'bus')))
    ::  one check-in that day, counted wherever the party stands
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((n fri 'checked')))
    ::  Sunday splits the ten miles from the two and a half
    (expect-eq !>(`(unit @ud)`[~ 2]) !>((n sun 'walk')))
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((n sun 'sun_ten')))
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((n sun 'sun_short')))
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((n sun 'social')))
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((n sun 'checked')))
  ==
++  test-en-row-checked
  =/  p=person:reg  some-person
  =/  r0=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  =/  r1=reg:reg  (need (with-checkin:reg r0 1 %sat 'admin:Sue' t1 |))
  =/  r=reg:reg  (need (with-checkin:reg r1 0 %sat 'pilgrim' t2 |))
  =/  j=json  (en-row:reg r 15.000 0)
  =/  ck=json  (gj:reg j 'checked')
  =/  me=json  (gj:reg j 'self')
  ;:  weld
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((gn:reg ck 'fri')))
    (expect-eq !>(`(unit @ud)`[~ 2]) !>((gn:reg ck 'sat')))
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((gn:reg ck 'sun')))
    ::  one of the two checked themselves in from their link
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((gn:reg me 'sat')))
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((gn:reg me 'fri')))
  ==
::  an address with a space in it is not an address. It reached a live
::  registration that then could not pay: Stripe refuses the address, so
::  the checkout never opens and the pilgrim is stuck at the payment step
::  with no way forward and nothing on the form to tell her why.
::
++  test-email-rejects-whitespace
  ;:  weld
    (expect !>((is-email:reg 'ana@example.com')))
    (expect !>(!(is-email:reg 'weezruss12@ gmail.com')))
    (expect !>(!(is-email:reg ' ana@example.com')))
    (expect !>(!(is-email:reg 'ana@example.com ')))
    (expect !>(!(is-email:reg 'an a@example.com')))
    ::  and the plus and dot addresses people really use still pass
    (expect !>((is-email:reg 'ana.silva+camino@example.co.uk')))
  ==
::  the organizers can call the event full. Then a new party joins the
::  wait list however the counts read, so a place freed by a lapsed hold
::  goes to somebody who has been waiting rather than to whoever is on
::  the page. It must not throw out anybody already part way through.
::
++  test-at-capacity
  =/  s0=settings:reg  st
  =/  shut=settings:reg  s0(at-capacity [full=& bambino=|])
  =/  babs=settings:reg  s0(at-capacity [full=| bambino=&])
  =/  room=counts:reg  *counts:reg
  =/  p0=person:reg  some-person
  =/  one=(list person:reg)  ~[p0]
  ::  bound first: some-person is an arm, and mutating an arm's product
  ::  without binding it reaches for the arm's subject instead
  =/  idle=(list person:reg)  ~[p0(days [fri=| sat=| sun=|])]
  =/  late=@da  (add t0 ~d30)
  =/  mid=reg:reg  (some-reg %a %payment %full 1 t0)
  =/  tight=settings:reg  shut(full.caps 0)
  ;:  weld
    ::  with room and both gates open, a new party gets a place
    (expect-eq !>(%waiver) !>((decide-submit:reg s0 room %full one)))
    (expect-eq !>(%waiver) !>((decide-submit:reg s0 room %bambino one)))
    ::  the full track called full: that track waits, the other does not
    (expect-eq !>(%waitlist) !>((decide-submit:reg shut room %full one)))
    (expect-eq !>(%waiver) !>((decide-submit:reg shut room %bambino one)))
    ::  and the other way round
    (expect-eq !>(%waitlist) !>((decide-submit:reg babs room %bambino one)))
    (expect-eq !>(%waiver) !>((decide-submit:reg babs room %full one)))
    ::  somebody who walks on no day takes no walking place, so they are
    ::  let through on either track whatever is called full
    (expect-eq !>(%waiver) !>((decide-submit:reg shut room %full idle)))
    (expect-eq !>(%waiver) !>((decide-submit:reg babs room %bambino idle)))
    ::  and it does not evict a party already in the flow: a lapsed hold
    ::  is still judged on the caps alone
    (expect !>((room-for:reg shut ~[mid] mid late)))
    ::  a full cap still turns one away, called full or not
    (expect !>(!(room-for:reg tight ~[mid] mid late)))
  ==
++  test-fee-by-hand
  =/  r=reg:reg  (some-reg %abc123 %waitlist %full 3 t0)
  =/  s0=settings:reg  st
  =/  cut=settings:reg  s0(owed (~(put by *(map @ta @ud)) %abc123 5.000))
  =/  free=settings:reg  s0(owed (~(put by *(map @ta @ud)) %abc123 0))
  =/  other=settings:reg  s0(owed (~(put by *(map @ta @ud)) %zzz999 5.000))
  =/  part=reg:reg  r(payment [%check 2.000 0 `t0 '' | ''])
  ;:  weld
    (expect-eq !>(22.500) !>((fees-total:reg s0 r)))
    (expect-eq !>(5.000) !>((fees-total:reg cut r)))
    (expect-eq !>(5.000) !>((owed:reg cut r)))
    (expect-eq !>(0) !>((fees-total:reg free r)))
    (expect-eq !>(0) !>((owed:reg free r)))
    (expect-eq !>(22.500) !>((fees-total:reg other r)))
    (expect-eq !>(3.000) !>((owed:reg cut part)))
  ==
++  test-de-owed
  ::  bound, not reached through the arm: a wing path into an arm's
  ::  product is not the same thing as a field of a value
  =/  base=settings:reg  st
  =/  older=settings:reg  (de-settings:reg (jo '{"at_capacity": true}'))
  =/  both-shut=?  &(full.at-capacity.older bambino.at-capacity.older)
  =/  good=settings:reg
    %-  de-settings:reg
    %-  jo
    '''
    {"fee_overrides": {"abc1234567": 5000, "nope": 1, "bad0000000": "x"},
     "at_capacity": {"full": true}}
    '''
  ;:  weld
    (expect-eq !>(`(unit @ud)`[~ 5.000]) !>((~(get by owed.good) %abc1234567)))
    (expect-eq !>(`@ud`1) !>(~(wyt by owed.good)))
    ::  named one at a time, and the one not named stays open
    (expect !>(full.at-capacity.good))
    (expect !>(!bambino.at-capacity.good))
    ::  a bare boolean, how the setting was first written, means both
    (expect !>(both-shut))
    ::  and a document that says nothing leaves everything alone
    (expect !>(!full.at-capacity.base))
    (expect !>(!bambino.at-capacity.base))
    (expect-eq !>(`@ud`0) !>(~(wyt by owed.base)))
  ==
::  a template that says where somebody stands must not go out when the
::  record says otherwise. "A spot opened for you" reached Meg Lyons
::  three times while she sat on the wait list.
::
++  test-tpl-ok
  =/  wl=reg:reg    (some-reg %a %waitlist %full 1 t0)
  =/  wv=reg:reg    (some-reg %a %waiver %full 1 t0)
  =/  pay=reg:reg   (some-reg %a %payment %full 1 t0)
  =/  done=reg:reg  (some-reg %a %complete %full 1 t0)
  =/  gone=reg:reg  (some-reg %a %cancelled %full 1 t0)
  =/  dr=reg:reg    (some-reg %a %draft %full 1 t0)
  ;:  weld
    (expect !>(?=(^ (tpl-ok:reg 'promoted' wl))))
    (expect !>(?=(^ (tpl-ok:reg 'promoted' gone))))
    (expect !>(?=(^ (tpl-ok:reg 'promoted' dr))))
    (expect !>(!?=(^ (tpl-ok:reg 'promoted' wv))))
    (expect !>(!?=(^ (tpl-ok:reg 'promoted' pay))))
    (expect !>(!?=(^ (tpl-ok:reg 'promoted' done))))
    (expect !>(!?=(^ (tpl-ok:reg 'waitlist' wl))))
    (expect !>(?=(^ (tpl-ok:reg 'waitlist' done))))
    (expect !>(!?=(^ (tpl-ok:reg 'confirmation' done))))
    (expect !>(?=(^ (tpl-ok:reg 'confirmation' pay))))
    (expect !>(!?=(^ (tpl-ok:reg 'cancelled' gone))))
    (expect !>(?=(^ (tpl-ok:reg 'cancelled' done))))
    (expect !>(!?=(^ (tpl-ok:reg 'manage' wl))))
    (expect !>(!?=(^ (tpl-ok:reg 'manage' done))))
    (expect !>(!?=(^ (tpl-ok:reg 'reminder' wl))))
    (expect !>(!?=(^ (tpl-ok:reg 'reminder' pay))))
    (expect !>(!?=(^ (tpl-ok:reg 'assistance_approved' done))))
    (expect !>(!?=(^ (tpl-ok:reg 'assistance_declined' pay))))
  ==
::  +owed: what a registration has still to pay, and the door a paid
::  one that grew a person goes back through
::
++  test-owed-after-growing
  =/  one=reg:reg  (some-reg %a %complete %full 1 t0)
  =/  paid=reg:reg  one(payment [%stripe 7.500 0 `t0 'cs_1' | ''])
  =/  grown=reg:reg  paid(people (reap 3 some-person))
  =/  giver=reg:reg  paid(payment [%stripe 7.500 7.500 `t0 'cs_1' | ''])
  =/  big=reg:reg  giver(people (reap 3 some-person))
  ;:  weld
    ::  nothing taken yet, so the whole fee is owed
    (expect-eq !>(7.500) !>((owed:reg st one)))
    ::  paid in full: nothing
    (expect-eq !>(0) !>((owed:reg st paid)))
    ::  two more people at 7.500 each, and only the difference is owed
    (expect-eq !>(22.500) !>((fees-total:reg st grown)))
    (expect-eq !>(15.000) !>((owed:reg st grown)))
    ::  a gift stays given: it is not credit against a later fee
    (expect-eq !>(15.000) !>((owed:reg st big)))
    ::  and the way back to the payment step is open, that one way only
    (expect !>((transition-ok:reg %complete %payment)))
    (expect !>(!(transition-ok:reg %complete %waiver)))
  ==
::  a granted assistance is settled, not a shortfall: the organizers
::  waived the fee, so the record carries the whole fee and nothing
::  taken, and nothing is owed. An edit to one must not ask for it.
::
++  test-owed-when-assistance-granted
  =/  r=reg:reg  (some-reg %a %complete %full 1 t0)
  =/  waived=reg:reg  r(payment [%assistance 0 0 `t0 '' | ''])
  =/  grown=reg:reg  waived(people (reap 3 some-person))
  =/  waiting=reg:reg  r(status %assistance)
  ;:  weld
    ::  the fee stands on the record and none of it is owed
    (expect-eq !>(7.500) !>((fees-total:reg st waived)))
    (expect-eq !>(0) !>((owed:reg st waived)))
    ::  nor is it owed when the party grows: that is the organizers' call
    (expect-eq !>(0) !>((owed:reg st grown)))
    ::  but one still WAITING on the decision has paid nothing and owes
    (expect-eq !>(7.500) !>((owed:reg st waiting)))
  ==
::  a registration with money on it holds its spots at the payment step
::  however long it stands there: the hold window is for one that has
::  paid nothing
++  test-counted-when-part-paid
  =/  late=@da  (add t0 ~d30)
  =/  waiting=reg:reg  (some-reg %a %payment %full 1 t0)
  =/  paid=reg:reg  waiting(payment [%stripe 7.500 0 `t0 'cs_1' | ''])
  ;:  weld
    (expect !>((counted:reg st waiting t0)))
    (expect !>(!(counted:reg st waiting late)))
    (expect !>((counted:reg st paid late)))
  ==
--
