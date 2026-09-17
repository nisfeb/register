::  register: sign-up and backoffice for the Baby Steps Camino.
::  docs/superpowers/specs/2026-09-17-register-design.md
::
::  The tree this nexus owns (every persistent path has a row in +on-load):
::    /main.sig            the writer: every mutation goes through it
::    /web.sig             binds /apps/register; one fiber per request
::    /requests/<id>       the ephemeral request fibers
::    /regs/<rid>          one registration       [/register %reg], retention on
::    /settings.json       the event: fees, caps, window, providers
::    /copy.json           every string the pilgrim reads
::    /counts.json         actual counts per day per activity
::    /beacon/rev          the change beacon, nested so it streams
::    /tr/last  /tr/log    the last writer outcome, the audit ring of 2000
::    the page and the manifests     laid fresh on every load, not %fall
::
::  ROADS ARE NEXUS-RELATIVE. A desk-installed app cannot learn its own
::  absolute path, so every road is [%| up lane], where up is the number
::  of steps from the calling fiber to the nexus root: 0 for the writer
::  and the binder, 1 for a request fiber at /requests/<id>.
::
::  THE WRITER MUST NOT CRASH. +rise-wait restarts a failed process by
::  consuming the next poke without processing it, so every refusal is a
::  branch that returns cleanly and writes /tr/last.
::
::  WHO MAY WRITE. Only this ship's own request fibers poke the writer,
::  and they set `by` honestly: 'pilgrim' for the public routes, 'admin'
::  for the owner's. A foreign ship is refused at the top of +apply.
::
/<  reg   /lib/register.hoon
/&  icon  icon.svg
/&  public-html  public.html
/&  public-css   public.css
/&  public-js    public.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Register'
            info+s+'Baby Steps Camino sign-up and backoffice'
            color+s+'#0b7fc2'
            image+s+'/grubbery/tiles/icon/register'
            href+s+'/apps/register/admin'
        ==
      =/  link=json
        (pairs:enjs:format ~[['name' s+'register'] ['description' s+'Baby Steps Camino registration']])
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'link.json'] [[/ %json] link]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'public.html'] [[/ %mime] public-html]]
          [%over %& [/ %'public.css'] [[/ %mime] public-css]]
          [%over %& [/ %'public.js'] [[/ %mime] public-js]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /regs empty-dir:loader]
          [%fall %| /tr empty-dir:loader]
          [%fall %| /beacon empty-dir:loader]
          [%fall %& [/ %'settings.json'] [[/ %json] starter-settings:reg]]
          [%fall %& [/ %'copy.json'] [[/ %json] starter-copy:reg]]
          [%fall %& [/ %'counts.json'] [[/ %json] [%o ~]]]
          [%fall %& [/beacon %rev] [[/ %json] (numb:enjs:format 0)]]
          [%fall %& [/tr %last] [[/ %json] [%o ~]]]
          [%fall %& [/tr %log] [[/ %json] [%a ~]]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  the writer. It reaches nothing at rise: a jailed install
          ::  would have every bowl poke vetoed.
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%register writer: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ;<  changed=?  bind:m  (apply from sage)
        ;<  ~  bind:m  ?.(changed (pure:m ~) bump-beacon)
        $
          ::  the HTTP binder. bind-http-self is veto-tolerant: jailed,
          ::  it logs and waits; the approval reload binds for real.
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%register web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /apps/register])
        (http-dispatch:io %register)
          ::  one ephemeral fiber per in-flight request
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%register request: failed")
        (handle-request name.rail)
      ==
    --
|%
::  ==  roads
::
++  rf  |=([up=@ud p=path n=@ta] ^-(road:tarball [%| up [%& p n]]))
++  rv  |=([up=@ud p=path] ^-(road:tarball [%| up [%| p]]))
++  srv  ~(. http-res:io [%| 1 %& ~ %'web.sig'])
::  ==  the ask
::
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the clock and the name of this ship')
          (line '/sys/eyre/' 'serve the sign-up page, the backoffice and the check-in app at /apps/register')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/sys/link/' 'find where this app is installed, so the page can address its own writer')
      ==
      ['make' a+~]
  ==
::  ==  the writer
::
::  +apply: one op from a poke. Answers whether the tree changed.
::
++  apply
  |=  [=from:fiber:nexus =sage:tarball]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ?.  =([/ %json] p.sage)  (pure:m |)
  ;<  our=@p  bind:m  get-our:io
  =/  src=(unit @p)  (get-poke-src:io from)
  ?.  ?|(?=(~ src) =(our u.src))
    (refuse 'poke' 'a foreign ship may not write here')
  =/  jon=json  (fall (mole |.(!<(json q.sage))) ~)
  =/  op=@t  (gs:reg jon 'op')
  ?:  =('save-draft' op)  (do-save-draft jon)
  ?:  =('submit' op)  (do-submit jon)
  ?:  =('edit' op)  (do-edit jon)
  ?:  =('cancel' op)  (do-cancel jon)
  ?:  =('advance' op)  (do-advance jon)
  ?:  =('promote' op)  (do-promote jon)
  ?:  =('assist' op)  (do-assist jon)
  ?:  =('note' op)  (do-note jon)
  ?:  =('set-settings' op)  (do-set-doc %'settings.json' 'set-settings' jon)
  ?:  =('set-copy' op)  (do-set-doc %'copy.json' 'set-copy' jon)
  ?:  =('set-counts' op)  (do-set-doc %'counts.json' 'set-counts' jon)
  (refuse op 'unknown op')
::  +refuse: a refusal that leaves the writer standing
::
++  refuse
  |=  [op=@t why=@t]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m  (note-rid op | why '' '')
  (pure:m |)
::  +trail-entry: one audit row
::
++  trail-entry
  |=  [op=@t ok=? why=@t by=@t rid=@t now=@da]
  ^-  json
  %-  pairs:enjs:format
  :~  ['op' s+op]  ['ok' b+ok]  ['why' s+why]  ['by' s+by]  ['rid' s+rid]  ['at' (en-time:reg now)]
  ==
::  +note-rid: the last writer outcome at /tr/last, and the audit ring
::  at /tr/log (the last 2000). Fiber prints reach only the raw console;
::  a grub is readable by every tool.
::
++  note-rid
  |=  [op=@t ok=? why=@t by=@t rid=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  entry=json  (trail-entry op ok why by rid now)
  ;<  ~  bind:m  (over:io (rf 0 /tr %last) [[/ %json] entry])
  ;<  log=json  bind:m  (read-json (rf 0 /tr %log))
  (over:io (rf 0 /tr %log) [[/ %json] (ring:reg log entry max-log:reg)])
::  +bump-beacon: the change beacon moves once per op that changed the
::  tree. Milliseconds since 1970, so a browser keeps it exact.
::
++  bump-beacon
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  ms=@ud  ?:((lth now ~1970.1.1) 0 (div (sub now ~1970.1.1) (div ~s1 1.000)))
  (over:io (rf 0 /beacon %rev) [[/ %json] (numb:enjs:format ms)])
::  +by-of: who a poke says acted, capped
::
++  by-of
  |=  jon=json
  ^-  @t
  =/  b=@t  (gs:reg jon 'by')
  ?:  =('' b)  'pilgrim'
  (end [3 max-by:reg] b)
::  +rid-of: the registration a poke names, or '' when it is not a rid
::
++  rid-of
  |=  jon=json
  ^-  @ta
  =/  r=@t  (gs:reg jon 'rid')
  ?:((ok-rid r) `@ta`r %$)
::  +ok-rid: ten lowercase hex digits
::
++  ok-rid
  |=  t=@t
  ^-  ?
  =/  tap=tape  (trip t)
  ?.  =(10 (lent tap))  |
  %+  levy  `tape`tap
  |=(c=@ |(&((gte c '0') (lte c '9')) &((gte c 'a') (lte c 'f'))))
::  +do-save-draft: a fresh draft, or the fields of an existing one.
::  An autosave is not an audit event; only a fresh draft is noted.
::
++  do-save-draft
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  ?:  =('' rid)  (refuse 'save-draft' 'rid: bad')
  =/  got  (de-input:reg (gj:reg jon 'input') |)
  ?:  ?=(%| -.got)  (refuse 'save-draft' p.got)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur
    =/  r=reg:reg  (new-reg:reg rid (gs:reg jon 'token') %web p.got now)
    ;<  ~  bind:m  (write-reg 0 r &)
    ;<  ~  bind:m  (note-rid 'save-draft' & 'new' 'pilgrim' rid)
    (pure:m &)
  ?.  =(%draft status.u.cur)  (refuse 'save-draft' 'not a draft')
  =/  r=reg:reg  (with-input:reg u.cur p.got)
  ;<  ~  bind:m  (write-reg 0 r(updated now) |)
  (pure:m &)
::  +do-submit: the form becomes a held registration or a wait list row.
::  The caps are checked here, against the tree as it is at this
::  moment, so two submits for the last spot cannot both hold it.
::
++  do-submit
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  ?:  =('' rid)  (refuse 'submit' 'rid: bad')
  =/  got  (de-input:reg (gj:reg jon 'input') &)
  ?:  ?=(%| -.got)  (refuse 'submit' p.got)
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 0)
  ?.  (window-open:reg s now)  (refuse 'submit' 'closed')
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?:  &(?=(^ cur) !=(%draft status.u.cur))  (refuse 'submit' 'already submitted')
  =/  base=reg:reg
    ?~  cur  (new-reg:reg rid (gs:reg jon 'token') %web p.got now)
    (with-input:reg u.cur p.got)
  ;<  regs=(list reg:reg)  bind:m  (load-regs 0)
  =/  c=counts:reg  (tally:reg s regs now)
  =/  sold=(unit @t)  (socials-ok:reg s c people.base)
  ?^  sold  (refuse 'submit' u.sold)
  =/  to=@tas  (decide-submit:reg s c track.base people.base)
  =/  r=reg:reg
    ?:  =(%waitlist to)
      (set-status:reg base(position +(waitlist.c)) %waitlist 'pilgrim' 'submitted, wait listed' now)
    (set-status:reg base %waiver 'pilgrim' 'submitted' now)
  ;<  ~  bind:m  (write-reg 0 r ?=(~ cur))
  ;<  ~  bind:m  (note-rid 'submit' & to 'pilgrim' rid)
  (pure:m &)
::  +do-edit: the fields of an active registration, by the pilgrim or
::  an organizer. The route checked the cutoff and the room.
::
++  do-edit
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  =/  got  (de-input:reg (gj:reg jon 'input') &)
  ?:  ?=(%| -.got)  (refuse 'edit' p.got)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'edit' 'no such registration')
  ?.  (active:reg u.cur)  (refuse 'edit' 'not active')
  =/  r=reg:reg  (note-hist:reg (with-input:reg u.cur p.got) by 'edited' now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'edit' & '' by rid)
  (pure:m &)
::  +do-cancel: frees the spots at once
::
++  do-cancel
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'cancel' 'no such registration')
  ?.  (transition-ok:reg status.u.cur %cancelled)  (refuse 'cancel' 'cannot cancel')
  =/  what=@t  (cat 3 'cancelled: ' (end [3 max-notes:reg] (gs:reg jon 'note')))
  =/  r=reg:reg  (set-status:reg u.cur(position 0) %cancelled by what now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'cancel' & '' by rid)
  (pure:m &)
::  +do-advance: one step of the flow, with what the step recorded: the
::  waiver's envelope, the payment's session. The route computed the
::  step; the machine refuses one that does not follow.
::
++  do-advance
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  =/  to=@tas  `@tas`(gs:reg jon 'to')
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'advance' 'no such registration')
  ?.  (transition-ok:reg status.u.cur to)
    (refuse 'advance' (rap 3 'cannot go from ' status.u.cur ' to ' to ~))
  =/  pj=json  (gj:reg jon 'payment')
  =/  wj=json  (gj:reg jon 'waiver')
  =/  r=reg:reg  u.cur
  =/  r=reg:reg
    ?~  pj  r
    %_  r
      payment  :*  `@tas`(gs:reg pj 'method')
                   (fall (gn:reg pj 'amount') 0)
                   (fall (gn:reg pj 'gift') 0)
                   `now
                   (gs:reg pj 'ref')
                   |
                   ''
               ==
    ==
  =/  r=reg:reg
    ?~  wj  r
    r(waiver [`@tas`(gs:reg wj 'method') (gs:reg wj 'envelope') `@tas`(gs:reg wj 'status') `now])
  =/  r=reg:reg  (set-status:reg r to by (end [3 max-notes:reg] (gs:reg jon 'what')) now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'advance' & to by rid)
  (pure:m &)
::  +do-promote: off the wait list and into the flow. The cap is not
::  checked: the organizer looked.
::
++  do-promote
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'promote' 'no such registration')
  ?.  =(%waitlist status.u.cur)  (refuse 'promote' 'not on the wait list')
  =/  r=reg:reg  (set-status:reg u.cur(position 0) %waiver by 'promoted from the wait list' now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'promote' & '' by rid)
  (pure:m &)
::  +do-assist: the organizers' decision on a request for assistance
::
++  do-assist
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  =/  approve=?  (gb:reg jon 'approve')
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'assist' 'no such registration')
  ?.  =(%assistance status.u.cur)  (refuse 'assist' 'not awaiting assistance')
  =/  r=reg:reg
    ?:  approve
      %-  set-status:reg
      :*  u.cur(payment [%assistance 0 0 `now '' | ''])
          %complete  by  'assistance approved'  now
      ==
    (set-status:reg u.cur %payment by 'assistance declined' now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'assist' & ?:(approve 'approved' 'declined') by rid)
  (pure:m &)
::  +do-note: a request fiber's outcome, in the ring. A stub email lands
::  here so a rehearsal can read what would have been sent.
::
++  do-note
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m
    %-  note-rid
    :*  (end [3 32] (gs:reg jon 'what'))
        (gb:reg jon 'ok')
        (end [3 500] (gs:reg jon 'why'))
        (by-of jon)
        (rid-of jon)
    ==
  (pure:m |)
::  +do-set-doc: one of the three documents, whole
::
++  do-set-doc
  |=  [name=@ta op=@t jon=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  doc=json  (gj:reg jon 'doc')
  ?.  ?=([%o *] doc)  (refuse op 'doc: an object is required')
  ;<  cur=json  bind:m  (read-json (rf 0 / name))
  ?:  =(cur doc)
    ;<  ~  bind:m  (note-rid op & 'unchanged' (by-of jon) '')
    (pure:m |)
  ;<  ~  bind:m  (over:io (rf 0 / name) [[/ %json] doc])
  ;<  ~  bind:m  (note-rid op & '' (by-of jon) '')
  (pure:m &)
::  ==  reads and writes on the tree
::
++  read-json
  |=  road=road:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] vw)  (pure:m [%o ~])
  (pure:m (fall (mole |.(!<(json (need-vase:tarball sang.vw)))) [%o ~]))
++  read-settings
  |=  up=@ud
  =/  m  (fiber:fiber:nexus ,settings:reg)
  ^-  form:m
  ;<  sj=json  bind:m  (read-json (rf up / %'settings.json'))
  (pure:m (de-settings:reg sj))
::  +load-regs: every registration under /regs
::
++  load-regs
  |=  up=@ud
  =/  m  (fiber:fiber:nexus ,(list reg:reg))
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (rv up /regs) ~)
  ?.  ?=([%ball *] vw)  (pure:m ~)
  ?~  fil.ball.vw  (pure:m ~)
  %-  pure:m
  %+  murn  ~(tap by contents.u.fil.ball.vw)
  |=  [nam=@ta c=[=sang:tarball gain=? bang=(unit tang)]]
  (read-reg:reg (sang-noun:tarball sang.c))
++  find-reg
  |=  [up=@ud rid=@ta]
  =/  m  (fiber:fiber:nexus ,(unit reg:reg))
  ^-  form:m
  ?:  =('' rid)  (pure:m ~)
  ;<  vw=view:nexus  bind:m  (peek:io (rf up /regs rid) ~)
  ?.  ?=([%file *] vw)  (pure:m ~)
  (pure:m (read-reg:reg (sang-noun:tarball sang.vw)))
::  +write-reg: a fresh registration with retention on, or the new
::  version of one that exists
::
++  write-reg
  |=  [up=@ud r=reg:reg fresh=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (rf up /regs id.r)
  ?.  fresh
    (over:io road [[/register %reg] `stored-reg:reg`[%1 r]])
  ;<  *  bind:m  (make-gained-soft:io road |+[[[/register %reg] `stored-reg:reg`[%1 r]] ~])
  (pure:m ~)
::  +poke-writer: one op to /main.sig from a request fiber
::
++  poke-writer
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] jon])
::  +lower: ascii lowercase
::
++  lower  |=(t=@t ^-(@t (crip (cass (trip t)))))
::  +is-admin: an actor the owner's routes named, 'admin:<name>'
::
++  is-admin  |=(by=@t ^-(? =('admin:' (end [3 6] by))))
::  +dup-of: an active registration under this email, other than rid
::
++  dup-of
  |=  [regs=(list reg:reg) email=@t rid=@ta]
  ^-  (unit reg:reg)
  =/  want=@t  (lower email)
  ?:  =('' want)  ~
  |-  ^-  (unit reg:reg)
  ?~  regs  ~
  ?:  ?&  (active:reg i.regs)
          !=(rid id.i.regs)
          =(want (lower email.contact.i.regs))
      ==
    `i.regs
  $(regs t.regs)
::  +without: every registration but one
::
++  without
  |=  [regs=(list reg:reg) rid=@ta]
  ^-  (list reg:reg)
  (skip regs |=(r=reg:reg =(rid id.r)))
::  ==  HTTP
::
++  send-json
  |=  [eyre-id=@ta code=@ud jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
  =/  heads
    :~  ['content-type' 'application/json']
        ['cache-control' 'no-store']
    ==
  (send-simple:srv eyre-id [[code heads] `bod])
++  send-err
  |=  [eyre-id=@ta code=@ud msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-json eyre-id code (pairs:enjs:format ~[['error' s+msg]]))
++  send-ok
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
::  +serve-file: one of the page files, with its own type and nosniff
::
++  serve-file
  |=  [eyre-id=@ta name=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  ct=(unit @t)
    ?+  name  ~
      %'public.html'  `'text/html; charset=utf-8'
      %'public.css'   `'text/css; charset=utf-8'
      %'public.js'    `'text/javascript; charset=utf-8'
    ==
  ?~  ct  (send-err eyre-id 404 'no such file')
  ;<  vw=view:nexus  bind:m  (peek:io (rf 1 / name) `[/ %mime])
  ?.  ?=([%file *] vw)  (send-err eyre-id 404 'no such file')
  =/  got=(unit mime)  (mole |.(!<(mime (need-vase:tarball sang.vw))))
  ?~  got  (send-err eyre-id 500 'unreadable file')
  =/  heads
    :~  ['content-type' u.ct]
        ['cache-control' 'no-cache']
        ['x-content-type-options' 'nosniff']
    ==
  (send-simple:srv eyre-id [[200 heads] `q.u.got])
::  +handle-request: one HTTP request, on its own ephemeral fiber. The
::  public routes need no cookie and prove themselves with the
::  registration's token. Everything under /api/admin needs the owner:
::  eyre's authenticated flag with src equal to our.
::
++  handle-request
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  =/  parsed  (parse-url:http-utils url.request.req)
  ::  drop /apps/register; a trailing slash parses as a trailing empty knot
  =/  suffix0=path  (slag 2 site.parsed)
  =/  suffix=path
    ?:  &(?=(^ suffix0) =('' (rear `path`suffix0)))  (snip `path`suffix0)
    suffix0
  =/  meth=@t  method.request.req
  =/  owner=?  &(authenticated.req =(src our))
  =/  own  |=(f=form:m ^-(form:m ?:(owner f (send-err eyre-id 403 'owner only'))))
  ::  the organizer's name, from the header the backoffice sends. A
  ::  change without one is refused so the page can ask.
  =/  actor=@t
    (end [3 max-by:reg] (fall (get-header:http 'x-actor' header-list.request.req) ''))
  =/  admin-by=@t  (cat 3 'admin:' actor)
  =/  act  |=(f=form:m ^-(form:m ?:(=('' actor) (send-err eyre-id 400 'actor: required') f)))
  ::  a body is read as JSON, so a request carrying one says it is JSON
  =/  ctype=@t
    =/  raw=tape
      (cass (trip (fall (get-header:http 'content-type' header-list.request.req) '')))
    (crip raw)
  ?:  ?&  |(=('POST' meth) =('PUT' meth))
          ?=(^ body.request.req)
          !=(0 p.u.body.request.req)
          !=('application/json' (end [3 16] ctype))
      ==
    (send-err eyre-id 415 'content-type: application/json required')
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) ~)
  =/  args=quay:eyre  args.parsed
  =/  tok=@t  (fall (get-key:kv:html-utils 't' args) '')
  =/  s2=@ta  ?:(?=([@ @ @ *] suffix) i.t.t.suffix %$)
  =/  s3=@ta  ?:(?=([@ @ @ @ *] suffix) i.t.t.t.suffix %$)
  ?:  &(=('GET' meth) ?=(~ suffix))                              (serve-file eyre-id %'public.html')
  ?:  &(=('GET' meth) ?=([%'public.css' ~] suffix))               (serve-file eyre-id %'public.css')
  ?:  &(=('GET' meth) ?=([%'public.js' ~] suffix))                (serve-file eyre-id %'public.js')
  ?:  &(=('GET' meth) ?=([%api %status ~] suffix))               (serve-status eyre-id)
  ?:  &(=('POST' meth) ?=([%api %draft ~] suffix))               (serve-draft eyre-id jon)
  ?:  &(=('POST' meth) ?=([%api %submit ~] suffix))              (serve-submit eyre-id jon)
  ?:  &(=('GET' meth) ?=([%api %reg @ ~] suffix))                (serve-reg eyre-id s2 tok)
  ?:  &(=('POST' meth) ?=([%api %reg @ %edit ~] suffix))         (serve-edit eyre-id s2 tok jon 'pilgrim')
  ?:  &(=('POST' meth) ?=([%api %reg @ %cancel ~] suffix))       (serve-cancel eyre-id s2 tok jon 'pilgrim')
  ?:  &(=('POST' meth) ?=([%api %reg @ %sign ~] suffix))         (serve-sign eyre-id s2 tok)
  ?:  &(=('POST' meth) ?=([%api %reg @ %pay ~] suffix))          (serve-pay eyre-id s2 tok)
  ?:  &(=('POST' meth) ?=([%api %resend-link ~] suffix))         (serve-resend eyre-id jon)
  ?:  &(=('GET' meth) ?=([%api %admin %regs ~] suffix))          (own (serve-regs eyre-id))
  ?:  &(=('GET' meth) ?=([%api %admin %reg @ ~] suffix))         (own (serve-admin-reg eyre-id s3))
  ?:  &(=('POST' meth) ?=([%api %admin %reg @ ~] suffix))        (own (act (serve-admin-act eyre-id s3 jon admin-by)))
  ?:  &(=('GET' meth) ?=([%api %admin %settings ~] suffix))      (own (serve-settings eyre-id))
  ?:  &(=('PUT' meth) ?=([%api %admin %settings ~] suffix))      (own (act (serve-set-settings eyre-id jon admin-by)))
  ?:  &(=('GET' meth) ?=([%api %admin %copy ~] suffix))          (own (serve-doc eyre-id %'copy.json'))
  ?:  &(=('PUT' meth) ?=([%api %admin %copy ~] suffix))          (own (act (serve-set-doc eyre-id 'set-copy' jon admin-by)))
  (send-err eyre-id 404 'no such route')
::  +with-reg: the registration a public route names, proven by its
::  token. A wrong token and a missing registration answer the same.
::
++  with-reg
  |=  [eyre-id=@ta rid=@t tok=@t]
  =/  m  (fiber:fiber:nexus ,(unit reg:reg))
  ^-  form:m
  ?.  (ok-rid rid)  (pure:m ~)
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 1 `@ta`rid)
  ?~  cur  (pure:m ~)
  ?.  &(!=('' tok) =(tok token.u.cur))  (pure:m ~)
  (pure:m cur)
::  +serve-status: the meter, the caps, the window and the copy
::
++  serve-status
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  sj=json  bind:m  (read-json (rf 1 / %'settings.json'))
  ;<  cj=json  bind:m  (read-json (rf 1 / %'copy.json'))
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  =/  s=settings:reg  (de-settings:reg sj)
  (send-json eyre-id 200 (status-json:reg s sj cj (tally:reg s regs now) now))
::  +serve-draft: a draft the moment there is an email or a phone. The
::  rid and token come back so the page can resume and submit.
::
++  serve-draft
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  got  (de-input:reg jon |)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  =/  want=@t  (gs:reg jon 'rid')
  =/  tok=@t  (gs:reg jon 'token')
  ;<  cur=(unit reg:reg)  bind:m  (with-reg eyre-id want tok)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  fresh=?  |(?=(~ cur) !=(%draft status.u.cur))
  =/  rid=@ta  ?:(fresh (rid-from:reg eny) id.u.cur)
  =/  token=@t  ?:(fresh (token-from:reg eny) token.u.cur)
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'save-draft']  ['rid' s+rid]  ['token' s+token]  ['input' jon]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['rid' s+rid] ['token' s+token]]))
::  +serve-submit: validate, check the window, the duplicate and the
::  socials, decide the wait list, and hand the form to the writer,
::  which decides again against the tree as it is when the poke lands.
::
++  serve-submit
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  got  (de-input:reg jon &)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ?.  (window-open:reg s now)  (send-err eyre-id 403 'closed')
  =/  want=@t  (gs:reg jon 'rid')
  =/  tok=@t  (gs:reg jon 'token')
  ;<  cur=(unit reg:reg)  bind:m  (with-reg eyre-id want tok)
  ?:  &(?=(^ cur) !=(%draft status.u.cur))  (send-err eyre-id 409 'already submitted')
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  rid=@ta  ?~(cur (rid-from:reg eny) id.u.cur)
  =/  token=@t  ?~(cur (token-from:reg eny) token.u.cur)
  =/  dup=(unit reg:reg)  (dup-of regs email.contact.p.got rid)
  ?^  dup
    %^  send-json  eyre-id  409
    (pairs:enjs:format ~[['error' s+'email: already registered'] ['code' s+'duplicate']])
  =/  c=counts:reg  (tally:reg s regs now)
  =/  sold=(unit @t)  (socials-ok:reg s c people.p.got)
  ?^  sold  (send-err eyre-id 400 u.sold)
  =/  to=@tas  (decide-submit:reg s c track.p.got people.p.got)
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'submit']  ['rid' s+rid]  ['token' s+token]  ['input' jon]  ['by' s+'pilgrim']
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  =/  probe=reg:reg  (new-reg:reg rid token %web p.got now)
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['rid' s+rid]
      ['token' s+token]
      ['status' s+to]
      ['position' (en-num:reg ?:(=(%waitlist to) +(waitlist.c) 0))]
      ['fees' (en-num:reg (fees-total:reg s probe))]
  ==
::  +serve-reg: the pilgrim's view of their own registration
::
++  serve-reg
  |=  [eyre-id=@ta rid=@t tok=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m  (with-reg eyre-id rid tok)
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 1)
  =/  j=json  (en-reg-pilgrim:reg u.cur (fees-total:reg s u.cur))
  ?.  ?=([%o *] j)  (send-json eyre-id 200 j)
  =/  extra=(map @t json)
    %-  malt
    ^-  (list [@t json])
    :~  ['changes_open' b+(changes-open:reg s now)]
        ['mode' s+mode.s]
    ==
  (send-json eyre-id 200 [%o (~(uni by p.j) extra)])
::  +serve-edit: a change to an active registration. A pilgrim is held
::  to the cutoff; an organizer is not. Room is checked against the
::  tree without this registration, so a party may grow only into free
::  spots and a sold-out social stays sold out.
::
++  serve-edit
  |=  [eyre-id=@ta rid=@t tok=@t jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m
    ?:  (is-admin by)  (find-reg 1 ?:((ok-rid rid) `@ta`rid %$))
    (with-reg eyre-id rid tok)
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ?.  (active:reg u.cur)  (send-err eyre-id 409 'not active')
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ?:  &(=('pilgrim' by) !(changes-open:reg s now))  (send-err eyre-id 403 'changes closed')
  =/  got  (de-input:reg jon &)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  =/  dup=(unit reg:reg)  (dup-of regs email.contact.p.got id.u.cur)
  ?^  dup
    %^  send-json  eyre-id  409
    (pairs:enjs:format ~[['error' s+'email: already registered'] ['code' s+'duplicate']])
  =/  c=counts:reg  (tally:reg s (without regs id.u.cur) now)
  =/  sold=(unit @t)  (socials-ok:reg s c people.p.got)
  ?^  sold  (send-err eyre-id 400 u.sold)
  ?:  ?&  !=(%waitlist status.u.cur)
          =(%waitlist (decide-submit:reg s c track.p.got people.p.got))
      ==
    (send-err eyre-id 409 'people: no room for the added people')
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'edit']  ['rid' s+id.u.cur]  ['input' jon]  ['by' s+by]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  =/  after=reg:reg  (with-input:reg u.cur p.got)
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['ok' b+&]
      ['fees_before' (en-num:reg (fees-total:reg s u.cur))]
      ['fees' (en-num:reg (fees-total:reg s after))]
  ==
++  serve-cancel
  |=  [eyre-id=@ta rid=@t tok=@t jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m
    ?:  (is-admin by)  (find-reg 1 ?:((ok-rid rid) `@ta`rid %$))
    (with-reg eyre-id rid tok)
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ?.  (transition-ok:reg status.u.cur %cancelled)  (send-err eyre-id 409 'cannot cancel')
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ?:  &(=('pilgrim' by) !(changes-open:reg s now))  (send-err eyre-id 403 'changes closed')
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'cancel']  ['rid' s+id.u.cur]  ['by' s+by]  ['note' s+(gs:reg jon 'note')]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-ok eyre-id)
::  +serve-sign: the waiver step. In stub mode it completes itself; the
::  live branch is phase 2.
::
++  serve-sign
  |=  [eyre-id=@ta rid=@t tok=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m  (with-reg eyre-id rid tok)
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ?.  =(%waiver status.u.cur)  (send-err eyre-id 409 'not at the waiver step')
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ?:  =(%live mode.s)  (send-err eyre-id 501 'signing is not configured yet')
  =/  to=@tas  (after-waiver:reg u.cur)
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'advance']  ['rid' s+id.u.cur]  ['to' s+to]  ['by' s+'pilgrim']
        ['what' s+'signed the waiver (stub)']
        ['waiver' (pairs:enjs:format ~[['method' s+'stub'] ['envelope' s+''] ['status' s+'completed']])]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['next' s+to]]))
::  +serve-pay: the payment step, the same way
::
++  serve-pay
  |=  [eyre-id=@ta rid=@t tok=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m  (with-reg eyre-id rid tok)
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ?:  =(%assistance status.u.cur)  (send-err eyre-id 409 'awaiting the assistance decision')
  ?.  =(%payment status.u.cur)  (send-err eyre-id 409 'not at the payment step')
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ?:  =(%live mode.s)  (send-err eyre-id 501 'payment is not configured yet')
  =/  fees=@ud  (fees-total:reg s u.cur)
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'advance']  ['rid' s+id.u.cur]  ['to' s+'complete']  ['by' s+'pilgrim']
        ['what' s+'paid (stub)']
        :-  'payment'
        %-  pairs:enjs:format
        :~  ['method' s+'stub']  ['amount' (en-num:reg fees)]  ['gift' (en-num:reg 0)]  ['ref' s+'stub']
        ==
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['next' s+'complete']]))
::  +serve-resend: the manage link to an address that has a registration.
::  Answers the same whether or not one exists. Phase 2 sends the mail;
::  here the outcome is noted in the ring.
::
++  serve-resend
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  email=@t  (gs:reg jon 'email')
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  =/  hit=(unit reg:reg)  (dup-of regs email '')
  ;<  *  bind:m
    %-  poke-writer
    %-  pairs:enjs:format
    :~  ['op' s+'note']  ['what' s+'resend-link']  ['ok' b+?=(^ hit)]
        ['why' s+?~(hit 'no active registration' 'stub: not sent')]
        ['by' s+'pilgrim']  ['rid' s+?~(hit '' id.u.hit)]
    ==
  (send-ok eyre-id)
::  ==  the owner's routes
::
++  serve-regs
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  ;<  now=@da  bind:m  get-time:io
  =/  c=counts:reg  (tally:reg s regs now)
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['regs' a+(turn regs |=(r=reg:reg (en-reg:reg r (fees-total:reg s r))))]
      :-  'counts'
      %-  pairs:enjs:format
      :~  ['full' (en-num:reg full.c)]  ['bambino' (en-num:reg bambino.c)]
          ['social_fri' (en-num:reg social-fri.c)]  ['social_sat' (en-num:reg social-sat.c)]
          ['late' (en-num:reg late.c)]  ['waitlist' (en-num:reg waitlist.c)]
      ==
  ==
++  serve-admin-reg
  |=  [eyre-id=@ta rid=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 1 ?:((ok-rid rid) `@ta`rid %$))
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ;<  s=settings:reg  bind:m  (read-settings 1)
  (send-json eyre-id 200 (en-reg:reg u.cur (fees-total:reg s u.cur)))
::  +serve-admin-act: an organizer's action on one registration, named
::  by op. Phase 3 grows this list.
::
++  serve-admin-act
  |=  [eyre-id=@ta rid=@t jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  op=@t  (gs:reg jon 'op')
  ?:  =('edit' op)  (serve-edit eyre-id rid '' (gj:reg jon 'input') by)
  ?:  =('cancel' op)  (serve-cancel eyre-id rid '' jon by)
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 1 ?:((ok-rid rid) `@ta`rid %$))
  ?~  cur  (send-err eyre-id 404 'no such registration')
  =/  pk=(unit json)
    ?:  =('promote' op)
      `(pairs:enjs:format ~[['op' s+'promote'] ['rid' s+id.u.cur] ['by' s+by]])
    ?:  =('assist' op)
      `(pairs:enjs:format ~[['op' s+'assist'] ['rid' s+id.u.cur] ['by' s+by] ['approve' b+(gb:reg jon 'approve')]])
    ~
  ?~  pk  (send-err eyre-id 400 'op: promote, assist, edit or cancel')
  ?:  &(=('promote' op) !=(%waitlist status.u.cur))  (send-err eyre-id 409 'not on the wait list')
  ?:  &(=('assist' op) !=(%assistance status.u.cur))  (send-err eyre-id 409 'not awaiting assistance')
  ;<  err=(unit tang)  bind:m  (poke-writer u.pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-ok eyre-id)
++  serve-doc
  |=  [eyre-id=@ta name=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  doc=json  bind:m  (read-json (rf 1 / name))
  (send-json eyre-id 200 doc)
++  serve-settings
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  doc=json  bind:m  (read-json (rf 1 / %'settings.json'))
  (send-json eyre-id 200 (mask:reg doc))
::  +serve-set-settings: a masked secret coming back keeps the stored one
::
++  serve-set-settings
  |=  [eyre-id=@ta jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'a JSON object is required')
  ;<  old=json  bind:m  (read-json (rf 1 / %'settings.json'))
  =/  pk=json  (pairs:enjs:format ~[['op' s+'set-settings'] ['doc' (unmask:reg jon old)] ['by' s+by]])
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-ok eyre-id)
++  serve-set-doc
  |=  [eyre-id=@ta op=@t jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'a JSON object is required')
  =/  pk=json  (pairs:enjs:format ~[['op' s+op] ['doc' jon] ['by' s+by]])
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-ok eyre-id)
--
