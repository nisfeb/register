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
++  old-reg
  ^-  reg-1:reg
  =/  r=reg:reg  (some-reg %abc123 %complete %full 2 t0)
  :*  id.r  status.r  track.r  source.r  created.r  updated.r
      contact.r  org.r  why.r  assistance.r  together.r  people.r
      payment.r  waiver.r  token.r  position.r  notes.r  history.r
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
    (expect-eq !>(`(unit reg:reg)`[~ r]) !>((read-reg:reg `stored-reg:reg`[%2 r])))
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
  ==
::  ==  the shape ladder
::
++  test-read-reg-1
  =/  o=reg-1:reg  old-reg
  =/  got=(unit reg:reg)  (read-reg:reg `stored-reg-1:reg`[%1 o])
  ?>  ?=(^ got)
  =/  r=reg:reg  u.got
  ;:  weld
    (expect-eq !>('abc123') !>(id.r))
    (expect-eq !>(%complete) !>(status.r))
    (expect-eq !>(2) !>((lent people.r)))
    ::  a %1 grub reads as %2 with the new fields at their defaults
    (expect !>(!exempt.r))
    (expect !>(=(%$ prior.r)))
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
    (expect-eq !>(45) !>(hp))
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
  =/  r=reg:reg  (need (with-checkin:reg r0 1 %sat 'admin:Sue' t1 |))
  =/  j=json  (en-row:reg r 15.000 0)
  =/  ck=json  (gj:reg j 'checked')
  ;:  weld
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((gn:reg ck 'fri')))
    (expect-eq !>(`(unit @ud)`[~ 1]) !>((gn:reg ck 'sat')))
    (expect-eq !>(`(unit @ud)`[~ 0]) !>((gn:reg ck 'sun')))
  ==
--
