::  Unit tests for /lib/register: the codecs, the fees, the cap fold, the
::  status machine, the templates and the masking.
::
/+  *test, reg=register
|%
++  jo  |=(t=@t ^-(json (need (de:json:html t))))
++  t0  ~2026.10.1..12.00.00
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
  ==
++  test-iso
  ;:  weld
    (expect-eq !>(`(unit @da)`[~ t0]) !>((de-iso:reg '2026-10-01T12:00:00Z')))
    (expect-eq !>('2026-10-01T12:00:00Z') !>((en-iso:reg t0)))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:reg '2026-02-30T00:00:00Z')))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:reg 'yesterday')))
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
  ;:  weld
    (expect-eq !>(`(unit @t)`~) !>((socials-ok:reg st [0 0 298 198 0 0] ~[p p])))
    (expect-eq !>(`(unit @t)`[~ 'social_sat: sold out']) !>((socials-ok:reg st [0 0 0 199 0 0] ~[p p])))
    (expect-eq !>(`(unit @t)`[~ 'social_fri: sold out']) !>((socials-ok:reg st [0 0 300 0 0 0] ~[p])))
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
    (expect !>(!(transition-ok:reg %cancelled %waiver)))
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
    (expect-eq !>(`(unit reg:reg)`[~ r]) !>((read-reg:reg `stored-reg:reg`[%1 r])))
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
++  test-copy
  =/  c=json  starter-copy:reg
  ;:  weld
    (expect !>(!=('' (gs:reg c 'landing.title'))))
    (expect !>(!=('' (gs:reg c 'email.waitlist.body'))))
    (expect !>(!=('' (gs:reg c 'form.social_soldout'))))
    (expect !>(!=('' (gs:reg c 'next.lapsed'))))
  ==
--
