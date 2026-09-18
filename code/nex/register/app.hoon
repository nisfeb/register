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
::    the three pages and the manifests laid fresh on every load, not %fall
::    the PWA assets (sw.js, manifest.json, the two icons) the same way
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
/&  admin-html   admin.html
/&  admin-css    admin.css
/&  admin-js     admin.js
/&  checkin-html  checkin.html
/&  checkin-css   checkin.css
/&  checkin-js    checkin.js
/&  sw-js         sw.js
/&  manifest-json  manifest.json
/&  icon-192  icon-192.png
/&  icon-512  icon-512.png
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
            href+s+'/apps/register/'
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
          [%over %& [/ %'admin.html'] [[/ %mime] admin-html]]
          [%over %& [/ %'admin.css'] [[/ %mime] admin-css]]
          [%over %& [/ %'admin.js'] [[/ %mime] admin-js]]
          [%over %& [/ %'checkin.html'] [[/ %mime] checkin-html]]
          [%over %& [/ %'checkin.css'] [[/ %mime] checkin-css]]
          [%over %& [/ %'checkin.js'] [[/ %mime] checkin-js]]
          [%over %& [/ %'sw.js'] [[/ %mime] sw-js]]
          [%over %& [/ %'manifest.json'] [[/ %mime] manifest-json]]
          [%over %& [/ %'icon-192.png'] [[/ %mime] icon-192]]
          [%over %& [/ %'icon-512.png'] [[/ %mime] icon-512]]
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
  ;<  our=@p  bind:m  get-our:io
  =/  src=(unit @p)  (get-poke-src:io from)
  ?.  ?|(?=(~ src) =(our u.src))
    (refuse 'poke' 'a foreign ship may not write here')
  ::  a restore comes as a noun, not as JSON: a whole bundle in one poke
  ?:  =([/register %bundle] p.sage)  (do-restore q.q.sage)
  ?.  =([/ %json] p.sage)  (refuse 'poke' 'not json')
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
  ?:  =('pay' op)  (do-pay jon)
  ?:  =('set-waiver' op)  (do-set-waiver jon)
  ?:  =('refund' op)  (do-refund jon)
  ?:  =('exempt' op)  (do-exempt jon)
  ?:  =('reinstate' op)  (do-reinstate jon)
  ?:  =('set-notes' op)  (do-set-notes jon)
  ?:  =('add' op)  (do-add jon)
  ?:  =('checkin' op)  (do-checkin jon)
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
  =/  ms=@ud  ?:((lth now ~1970.1.1) 0 (div (mul 1.000 (sub now ~1970.1.1)) ~s1))
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
  ?:((ok-rid:reg r) `@ta`r %$)
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
  ?:  ?&  ?=(^ cur)
          !=(%draft status.u.cur)
      ==
    (refuse 'submit' 'already submitted')
  =/  base=reg:reg
    ?~  cur  (new-reg:reg rid (gs:reg jon 'token') %web p.got now)
    (with-input:reg u.cur p.got)
  ;<  regs=(list reg:reg)  bind:m  (load-regs 0)
  =/  dup=(unit reg:reg)  (dup-of regs email.contact.base rid)
  ?^  dup  (refuse 'submit' 'email: already registered')
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
  =/  was=@tas  status.u.cur
  =/  r=reg:reg  (set-status:reg u.cur(position 0, prior was) %cancelled by what now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'cancel' & '' by rid)
  (pure:m &)
::  +do-advance: one step of the flow, with what the step recorded: the
::  waiver's envelope, the payment's session. The route computed the
::  step; the machine refuses one that does not follow. A `position`
::  key, when present, is written as given: on a lapsed hold going to
::  the wait list the route had just read the tree, so the writer takes
::  its word rather than folding the caps a second time.
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
  =/  posn=(unit @ud)  (gn:reg jon 'position')
  =/  r=reg:reg  ?~(posn r r(position u.posn))
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
    (over:io road [[/register %reg] `stored-reg:reg`[%2 r]])
  ;<  *  bind:m  (make-gained-soft:io road |+[[[/register %reg] `stored-reg:reg`[%2 r]] ~])
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
      %'admin.html'   `'text/html; charset=utf-8'
      %'admin.css'    `'text/css; charset=utf-8'
      %'admin.js'     `'text/javascript; charset=utf-8'
      %'checkin.html'  `'text/html; charset=utf-8'
      %'checkin.css'   `'text/css; charset=utf-8'
      %'checkin.js'    `'text/javascript; charset=utf-8'
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
::  +serve-asset: a PWA asset, with its own type, its own cache rule and
::  whatever extra header it needs. No nosniff: a service worker and a
::  manifest are fetched by the browser itself, which reads the type.
::
++  serve-asset
  |=  [eyre-id=@ta name=@ta ct=@t cc=@t extra=(list [@t @t])]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (rf 1 / name) `[/ %mime])
  ?.  ?=([%file *] vw)  (send-err eyre-id 404 'no such file')
  =/  got=(unit mime)  (mole |.(!<(mime (need-vase:tarball sang.vw))))
  ?~  got  (send-err eyre-id 500 'unreadable file')
  =/  base=(list [@t @t])  ~[['content-type' ct] ['cache-control' cc]]
  (send-simple:srv eyre-id [[200 (weld base extra)] `q.u.got])
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
  ::  the PWA assets, served WITHOUT the cookie on purpose. A browser
  ::  fetches a manifest, an icon and a service worker uncredentialed:
  ::  only Chrome honours crossorigin=use-credentials and iOS never
  ::  sends a cookie for an icon. Behind the owner gate they answer 403
  ::  and the install degrades silently to a bookmark with no standalone
  ::  window. Nothing here is private: a name, two colours, a check mark
  ::  and a caching worker. Lattice serves its own the same way.
  ?:  &(=('GET' meth) ?=([%'manifest.json' ~] suffix))
    (serve-asset eyre-id %'manifest.json' 'application/manifest+json' 'public, max-age=86400' ~)
  ?:  &(=('GET' meth) ?=([%'sw.js' ~] suffix))
    ::  service-worker-allowed widens the scope past the worker's own
    ::  directory, and no-cache so a new worker reaches the phone
    %^  serve-asset  eyre-id  %'sw.js'
    ['text/javascript; charset=utf-8' 'no-cache' ~[['service-worker-allowed' '/apps/register/']]]
  ?:  &(=('GET' meth) ?=([%'icon-192.png' ~] suffix))
    (serve-asset eyre-id %'icon-192.png' 'image/png' 'public, max-age=86400' ~)
  ?:  &(=('GET' meth) ?=([%'icon-512.png' ~] suffix))
    (serve-asset eyre-id %'icon-512.png' 'image/png' 'public, max-age=86400' ~)
  ::  the volunteers' check-in app. The page, its script and its style
  ::  are the owner's, like the backoffice; a volunteer opens it with
  ::  the ship's own login, and the page redirects there without one.
  ?:  &(=('GET' meth) ?=([%checkin ~] suffix))
    ?.(owner (send-login eyre-id '/apps/register/checkin') (serve-file eyre-id %'checkin.html'))
  ?:  &(=('GET' meth) ?=([%'checkin.css' ~] suffix))             (own (serve-file eyre-id %'checkin.css'))
  ?:  &(=('GET' meth) ?=([%'checkin.js' ~] suffix))              (own (serve-file eyre-id %'checkin.js'))
  ?:  &(=('GET' meth) ?=([%api %checkin %roster ~] suffix))
    (own (serve-checkin-roster eyre-id (fall (get-key:kv:html-utils 'day' args) '')))
  ?:  &(=('POST' meth) ?=([%api %checkin ~] suffix))             (own (act (serve-checkin eyre-id jon admin-by)))
  ::  the backoffice itself. Without the cookie it is a redirect to
  ::  eyre's login form, not a refusal: an organizer opened a link.
  ?:  &(=('GET' meth) ?=([%admin ~] suffix))
    ?.(owner (send-login eyre-id '/apps/register/admin') (serve-file eyre-id %'admin.html'))
  ?:  &(=('GET' meth) ?=([%'admin.css' ~] suffix))               (own (serve-file eyre-id %'admin.css'))
  ?:  &(=('GET' meth) ?=([%'admin.js' ~] suffix))                (own (serve-file eyre-id %'admin.js'))
  ?:  &(=('GET' meth) ?=([%api %admin %regs ~] suffix))          (own (serve-regs eyre-id))
  ?:  &(=('GET' meth) ?=([%api %admin %reg @ ~] suffix))         (own (serve-admin-reg eyre-id s3))
  ?:  &(=('POST' meth) ?=([%api %admin %reg @ ~] suffix))        (own (act (serve-admin-act eyre-id s3 jon admin-by)))
  ?:  &(=('GET' meth) ?=([%api %admin %settings ~] suffix))      (own (serve-settings eyre-id))
  ?:  &(=('PUT' meth) ?=([%api %admin %settings ~] suffix))      (own (act (serve-set-settings eyre-id jon admin-by)))
  ?:  &(=('GET' meth) ?=([%api %admin %copy ~] suffix))          (own (serve-doc eyre-id %'copy.json'))
  ?:  &(=('PUT' meth) ?=([%api %admin %copy ~] suffix))          (own (act (serve-set-doc eyre-id 'set-copy' jon admin-by)))
  ?:  &(=('GET' meth) ?=([%api %admin %counts ~] suffix))        (own (serve-doc eyre-id %'counts.json'))
  ?:  &(=('PUT' meth) ?=([%api %admin %counts ~] suffix))        (own (act (serve-set-doc eyre-id 'set-counts' jon admin-by)))
  ?:  &(=('POST' meth) ?=([%api %admin %add ~] suffix))          (own (act (serve-add eyre-id jon admin-by)))
  ?:  &(=('GET' meth) ?=([%api %admin %export @ ~] suffix))      (own (serve-export eyre-id s3))
  ?:  &(=('POST' meth) ?=([%api %admin %import ~] suffix))       (own (act (serve-import eyre-id jon args admin-by)))
  (send-err eyre-id 404 'no such route')
::  +with-reg: the registration a public route names, proven by its
::  token. A wrong token and a missing registration answer the same.
::
++  with-reg
  |=  [eyre-id=@ta rid=@t tok=@t]
  =/  m  (fiber:fiber:nexus ,(unit reg:reg))
  ^-  form:m
  ?.  (ok-rid:reg rid)  (pure:m ~)
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
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ?.  (window-open:reg s now)  (send-err eyre-id 403 'closed')
  =/  got  (de-input:reg jon |)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  =/  want=@t  (gs:reg jon 'rid')
  =/  tok=@t  (gs:reg jon 'token')
  ;<  cur=(unit reg:reg)  bind:m  (with-reg eyre-id want tok)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  rid=@ta
    ?~  cur  (rid-from:reg eny)
    ?.  =(%draft status.u.cur)  (rid-from:reg eny)
    id.u.cur
  =/  token=@t
    ?~  cur  (token-from:reg eny)
    ?.  =(%draft status.u.cur)  (token-from:reg eny)
    token.u.cur
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
  ?:  ?&  ?=(^ cur)
          !=(%draft status.u.cur)
      ==
    (send-err eyre-id 409 'already submitted')
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
  =/  posn=@ud  ?:(=(%waitlist to) +(waitlist.c) 0)
  ::  the stub email: only the subject, so no {{link}} body reaches the ring
  ;<  ~  bind:m
    ?.  =(%waitlist to)  (pure:m ~)
    ;<  cj=json  bind:m  (read-json (rf 1 / %'copy.json'))
    =/  who=@t  ?~(people.p.got '' first.i.people.p.got)
    =/  subj=@t
      %+  fill:reg  (gs:reg cj 'email.waitlist.subject')
      ~[['first' who] ['position' (crip (a-co:co posn))]]
    ;<  *  bind:m
      %-  poke-writer
      %-  pairs:enjs:format
      :~  ['op' s+'note']  ['what' s+'email.waitlist']  ['ok' b+&]
          ['why' s+subj]  ['by' s+'stub']  ['rid' s+rid]
      ==
    (pure:m ~)
  =/  probe=reg:reg  (new-reg:reg rid token %web p.got now)
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['rid' s+rid]
      ['token' s+token]
      ['status' s+to]
      ['position' (en-num:reg posn)]
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
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  =/  j=json
    %-  en-reg-pilgrim:reg
    [u.cur (fees-total:reg s u.cur) (position-of:reg regs u.cur)]
  ?.  ?=([%o *] j)  (send-json eyre-id 200 j)
  =/  extra=(map @t json)
    %-  malt
    ^-  (list [@t json])
    :~  ['changes_open' b+(changes-open:reg s now)]
        ['mode' s+mode.s]
        ['lapsed' b+!(counted:reg s u.cur now)]
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
    ?:  (is-admin by)  (find-reg 1 ?:((ok-rid:reg rid) `@ta`rid %$))
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
    ?:  (is-admin by)  (find-reg 1 ?:((ok-rid:reg rid) `@ta`rid %$))
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
::  +lapse-to-waitlist: a hold that aged out while the track filled.
::  The route reads the tree, decides, and tells the writer where the
::  registration lands on the wait list.
::
++  lapse-to-waitlist
  |=  [eyre-id=@ta s=settings:reg regs=(list reg:reg) r=reg:reg now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  c=counts:reg  (tally:reg s (without regs id.r) now)
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'advance']  ['rid' s+id.r]  ['to' s+'waitlist']  ['by' s+'pilgrim']
        ['what' s+'hold lapsed, wait listed']
        ['position' (en-num:reg +(waitlist.c))]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  %^  send-json  eyre-id  409
  %-  pairs:enjs:format
  :~  ['error' s+'the track filled while your registration waited']
      ['code' s+'waitlist']
  ==
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
  ;<  now=@da  bind:m  get-time:io
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  ?.  (room-for:reg s regs u.cur now)
    (lapse-to-waitlist eyre-id s regs u.cur now)
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
  ;<  now=@da  bind:m  get-time:io
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  ?.  (room-for:reg s regs u.cur now)
    (lapse-to-waitlist eyre-id s regs u.cur now)
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
  :~  ['regs' a+(turn regs |=(r=reg:reg (en-row:reg r (fees-total:reg s r) (position-of:reg regs r))))]
      :-  'counts'
      %-  pairs:enjs:format
      :~  ['full' (en-num:reg full.c)]  ['bambino' (en-num:reg bambino.c)]
          ['social_fri' (en-num:reg social-fri.c)]  ['social_sat' (en-num:reg social-sat.c)]
          ['late' (en-num:reg late.c)]  ['waitlist' (en-num:reg waitlist.c)]
      ==
      :-  'caps'
      %-  pairs:enjs:format
      :~  ['full' (en-num:reg full.caps.s)]  ['bambino' (en-num:reg bambino.caps.s)]
          ['social_fri' (en-num:reg social-fri.caps.s)]  ['social_sat' (en-num:reg social-sat.caps.s)]
          ['late_adds' (en-num:reg late.caps.s)]  ['party' (en-num:reg max-party:reg)]
      ==
      ['now' (en-time:reg now)]
  ==
++  serve-admin-reg
  |=  [eyre-id=@ta rid=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 1 ?:((ok-rid:reg rid) `@ta`rid %$))
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  %^  send-json  eyre-id  200
  (en-reg:reg u.cur (fees-total:reg s u.cur) (position-of:reg regs u.cur))
::  +serve-admin-act: an organizer's action on one registration, named
::  by op. Each op's status rule is checked here, so the page gets a
::  409 with a reason rather than a silent refusal in the ring.
::
++  serve-admin-act
  |=  [eyre-id=@ta rid=@t jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  op=@t  (gs:reg jon 'op')
  ?:  =('edit' op)  (serve-edit eyre-id rid '' (gj:reg jon 'input') by)
  ?:  =('cancel' op)  (serve-cancel eyre-id rid '' jon by)
  ?:  =('recheck-waiver' op)  (send-err eyre-id 501 'waiver recheck is phase 2')
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 1 ?:((ok-rid:reg rid) `@ta`rid %$))
  ?~  cur  (send-err eyre-id 404 'no such registration')
  ?:  =('resend' op)  (serve-resend-template eyre-id u.cur jon)
  =/  r=reg:reg  u.cur
  =/  meth=@t  (gs:reg jon 'method')
  ?:  &(=('promote' op) !=(%waitlist status.r))  (send-err eyre-id 409 'not on the wait list')
  ?:  &(=('assist' op) !=(%assistance status.r))  (send-err eyre-id 409 'not awaiting assistance')
  ?:  &(=('pay' op) !?=(?(%payment %assistance) status.r))
    (send-err eyre-id 409 'not awaiting payment')
  ?:  &(=('pay' op) !?=(?(%check %cash %other) meth))
    (send-err eyre-id 400 'method: check, cash or other')
  ?:  &(=('waiver-paper' op) !(active:reg r))  (send-err eyre-id 409 'not active')
  ?:  &(=('refund' op) =(%none method.payment.r))  (send-err eyre-id 409 'no payment to refund')
  ?:  &(=('reinstate' op) !=(%cancelled status.r))  (send-err eyre-id 409 'not cancelled')
  ?:  &(=('reinstate' op) =(%$ prior.r))  (send-err eyre-id 409 'nothing to reinstate to')
  =/  pk=(unit json)
    ?:  =('promote' op)
      `(pairs:enjs:format ~[['op' s+'promote'] ['rid' s+id.r] ['by' s+by]])
    ?:  =('assist' op)
      `(pairs:enjs:format ~[['op' s+'assist'] ['rid' s+id.r] ['by' s+by] ['approve' b+(gb:reg jon 'approve')]])
    ?:  =('pay' op)
      :-  ~
      %-  pairs:enjs:format
      :~  ['op' s+'pay']  ['rid' s+id.r]  ['by' s+by]  ['method' s+meth]
          ['amount' (en-num:reg (fall (gn:reg jon 'amount') 0))]
          ['gift' (en-num:reg (fall (gn:reg jon 'gift') 0))]
          ['ref' s+(gs:reg jon 'ref')]  ['note' s+(gs:reg jon 'note')]
      ==
    ?:  =('waiver-paper' op)
      `(pairs:enjs:format ~[['op' s+'set-waiver'] ['rid' s+id.r] ['by' s+by]])
    ?:  =('refund' op)
      `(pairs:enjs:format ~[['op' s+'refund'] ['rid' s+id.r] ['by' s+by] ['note' s+(gs:reg jon 'note')]])
    ?:  =('exempt' op)
      `(pairs:enjs:format ~[['op' s+'exempt'] ['rid' s+id.r] ['by' s+by] ['on' b+(gb:reg jon 'on')]])
    ?:  =('reinstate' op)
      `(pairs:enjs:format ~[['op' s+'reinstate'] ['rid' s+id.r] ['by' s+by]])
    ?:  =('note' op)
      `(pairs:enjs:format ~[['op' s+'set-notes'] ['rid' s+id.r] ['by' s+by] ['notes' s+(gs:reg jon 'notes')]])
    ~
  ?~  pk  (send-err eyre-id 400 'op: not an organizer op this ship knows')
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
::  ==  the organizer's writer ops
::
::  +do-pay: an organizer records a check, cash or another payment. The
::  route checked the status and the method.
::
++  do-pay
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  =/  meth=@t  (gs:reg jon 'method')
  ?.  ?=(?(%check %cash %other) meth)  (refuse 'pay' 'method: check, cash or other')
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'pay' 'no such registration')
  ?.  ?=(?(%payment %assistance) status.u.cur)  (refuse 'pay' 'not awaiting payment')
  =/  paid=payment:reg
    :*  `@tas`meth
        (fall (gn:reg jon 'amount') 0)
        (fall (gn:reg jon 'gift') 0)
        `now
        (gs:reg jon 'ref')
        |
        (end [3 max-notes:reg] (gs:reg jon 'note'))
    ==
  =/  what=@t  (cat 3 'payment recorded: ' meth)
  =/  r=reg:reg  (set-status:reg u.cur(payment paid) %complete by what now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'pay' & meth by rid)
  (pure:m &)
::  +do-set-waiver: a waiver signed on paper. At the waiver step it also
::  advances; anywhere else only the record changes.
::
++  do-set-waiver
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'set-waiver' 'no such registration')
  ?.  (active:reg u.cur)  (refuse 'set-waiver' 'not active')
  =/  base=reg:reg  u.cur(waiver [%paper '' %completed `now])
  =/  what=@t  'waiver signed on paper'
  =/  r=reg:reg
    ?.  =(%waiver status.base)  (note-hist:reg base by what now)
    (set-status:reg base (after-waiver:reg base) by what now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'set-waiver' & status.r by rid)
  (pure:m &)
::  +do-refund: the money went back. The status does not move: the spot
::  is freed by a cancel, not by a refund.
::
++  do-refund
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'refund' 'no such registration')
  ?:  =(%none method.payment.u.cur)  (refuse 'refund' 'no payment to refund')
  =/  note=@t  (end [3 max-notes:reg] (gs:reg jon 'note'))
  =/  was=@t  note.payment.u.cur
  =/  joined=@t
    ?:  =('' note)  was
    ?:  =('' was)  note
    (rap 3 was '; ' note ~)
  =/  p=payment:reg  payment.u.cur
  =/  p2=payment:reg  p(refunded &, note (end [3 max-notes:reg] joined))
  =/  r=reg:reg  (note-hist:reg u.cur(payment p2) by 'refunded' now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'refund' & '' by rid)
  (pure:m &)
::  +do-exempt: the organizer's mark. An exempt party holds no spot on
::  its track and none in the late-add pool.
::
++  do-exempt
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  =/  on=?  (gb:reg jon 'on')
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'exempt' 'no such registration')
  =/  what=@t  ?:(on 'marked exempt' 'exempt cleared')
  =/  r=reg:reg  (note-hist:reg u.cur(exempt on) by what now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'exempt' & what by rid)
  (pure:m &)
::  +do-reinstate: a cancel undone, back to the status it left
::
++  do-reinstate
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'reinstate' 'no such registration')
  =/  got=(unit reg:reg)  (reinstate:reg u.cur by now)
  ?~  got  (refuse 'reinstate' 'cannot reinstate')
  =/  r=reg:reg  u.got(prior %$)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'reinstate' & status.r by rid)
  (pure:m &)
::  +do-set-notes: the organizers' private note on a registration
::
++  do-set-notes
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'set-notes' 'no such registration')
  =/  notes=@t  (end [3 max-notes:reg] (gs:reg jon 'notes'))
  =/  r=reg:reg  (note-hist:reg u.cur(notes notes) by 'notes changed' now)
  ;<  ~  bind:m  (write-reg 0 r |)
  ;<  ~  bind:m  (note-rid 'set-notes' & '' by rid)
  (pure:m &)
::  +do-add: an organizer's manual registration. No window and no cap:
::  the organizer looked. The waiver and the payment the organizer took
::  on the spot are applied in this one op, each with its history line.
::
++  do-add
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  ?:  =('' rid)  (refuse 'add' 'rid: bad')
  =/  by=@t  (by-of jon)
  =/  got  (de-input:reg (gj:reg jon 'input') &)
  ?:  ?=(%| -.got)  (refuse 'add' p.got)
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?^  cur  (refuse 'add' 'rid: taken')
  =/  base=reg:reg  (new-reg:reg rid (gs:reg jon 'token') %admin p.got now)
  =/  held=reg:reg
    (set-status:reg base(exempt (gb:reg jon 'exempt')) %waiver by 'added by organizer' now)
  =/  paper=?  (gb:reg jon 'waiver_paper')
  =/  signed=reg:reg
    ?.  paper  held
    =/  w=reg:reg  held(waiver [%paper '' %completed `now])
    (set-status:reg w (after-waiver:reg w) by 'waiver signed on paper' now)
  =/  pj=json  (gj:reg jon 'paid')
  =/  meth=@t  (gs:reg pj 'method')
  =/  can-pay=?
    ?&  ?=([%o *] pj)
        ?=(?(%check %cash %other) meth)
        ?=(?(%payment %assistance) status.signed)
    ==
  =/  r=reg:reg
    ?.  can-pay  signed
    =/  paid=payment:reg
      :*  `@tas`meth
          (fall (gn:reg pj 'amount') 0)
          (fall (gn:reg pj 'gift') 0)
          `now
          (gs:reg pj 'ref')
          |
          (end [3 max-notes:reg] (gs:reg pj 'note'))
      ==
    =/  what=@t  (cat 3 'payment recorded: ' meth)
    (set-status:reg signed(payment paid) %complete by what now)
  ;<  ~  bind:m  (write-reg 0 r &)
  ;<  ~  bind:m  (note-rid 'add' & status.r by rid)
  (pure:m &)
::  +do-restore: a backup applied. Every registration in the bundle is
::  written, fresh or over the one that is there, with a history line.
::  The three documents are replaced, with a masked secret keeping the
::  stored one. With wipe, a registration the bundle does not name is
::  culled, which is the true restore.
::
++  do-restore
  |=  n=*
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  got=(unit [wipe=? by=@t b=bundle:reg])  (mole |.(;;([? @t bundle:reg] n)))
  ?~  got  (refuse 'restore' 'the bundle did not read')
  =/  wipe=?  wipe.u.got
  =/  by=@t  by.u.got
  =/  b=bundle:reg  b.u.got
  ;<  now=@da  bind:m  get-time:io
  ;<  have=(list reg:reg)  bind:m  (load-regs 0)
  =/  here=(set @ta)  (sy (turn have |=(r=reg:reg id.r)))
  =/  keep=(set @ta)  (sy (turn regs.b |=(r=reg:reg id.r)))
  =/  dead=(list @ta)
    (skim (turn have |=(r=reg:reg id.r)) |=(i=@ta !(~(has in keep) i)))
  =/  marked=(list reg:reg)
    (turn regs.b |=(r=reg:reg (note-hist:reg r by 'restored from backup' now)))
  ;<  ~  bind:m  (restore-regs here marked)
  ;<  ~  bind:m  (put-doc %'settings.json' settings.b &)
  ;<  ~  bind:m  (put-doc %'copy.json' copy.b |)
  ;<  ~  bind:m  (put-doc %'counts.json' counts.b |)
  =/  doomed=(list @ta)  ?:(wipe dead ~)
  ;<  ~  bind:m  (cull-each 0 /regs doomed)
  =/  culled=@ud  (lent doomed)
  =/  wrote=@t  (crip (a-co:co (lent regs.b)))
  =/  gone=@t  (crip (a-co:co culled))
  =/  why=@t  (rap 3 'restored ' wrote ' registrations, culled ' gone ~)
  ;<  ~  bind:m  (note-rid 'restore' & why by '')
  (pure:m &)
::  +put-doc: a document a backup carries, written only when the bundle
::  really holds an object. A bundle missing the document, or carrying a
::  JSON null in its place, leaves the stored one alone. With mask, a
::  masked secret coming back keeps the stored value.
::
++  put-doc
  |=  [name=@tas new=json mask=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] new)  (pure:m ~)
  ?.  mask  (over:io (rf 0 / name) [[/ %json] new])
  ;<  old=json  bind:m  (read-json (rf 0 / name))
  (over:io (rf 0 / name) [[/ %json] (unmask:reg new old)])
::  +restore-regs: one write per registration, fresh ones with retention
::
++  restore-regs
  |=  [here=(set @ta) regs=(list reg:reg)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  regs  (pure:m ~)
  ;<  ~  bind:m  (write-reg 0 i.regs !(~(has in here) id.i.regs))
  (restore-regs here t.regs)
::  +cull-each: remove each named grub from a directory, best effort
::
++  cull-each
  |=  [up=@ud dir=path names=(list @ta)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  names  (pure:m ~)
  ;<  *  bind:m  (cull-soft:io (rf up dir i.names))
  (cull-each up dir t.names)
::  ==  the backoffice's HTTP helpers
::
::  +send-login: eyre's own login form, so an organizer who opens the
::  link gets asked for the code instead of a bare refusal
::
++  send-login
  |=  [eyre-id=@ta back=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  heads=(list [@t @t])  ~[['location' (cat 3 '/~/login?redirect=' back)]]
  (send-simple:srv eyre-id [[302 heads] ~])
::  +send-download: a file the browser saves
::
++  send-download
  |=  [eyre-id=@ta ctype=@t fname=@t body=octs]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  heads
    :~  ['content-type' ctype]
        ['cache-control' 'no-store']
        ['content-disposition' (rap 3 'attachment; filename="' fname '"' ~)]
    ==
  (send-simple:srv eyre-id [[200 heads] `body])
++  min-date
  |=  l=(list @da)
  ^-  (unit @da)
  ?~  l  ~
  =/  out=@da  i.l
  =/  rest=(list @da)  t.l
  |-  ^-  (unit @da)
  ?~  rest  `out
  $(rest t.rest, out ?:((lth i.rest out) i.rest out))
++  max-date
  |=  l=(list @da)
  ^-  (unit @da)
  ?~  l  ~
  =/  out=@da  i.l
  =/  rest=(list @da)  t.l
  |-  ^-  (unit @da)
  ?~  rest  `out
  $(rest t.rest, out ?:((gth i.rest out) i.rest out))
::  +read-bundle: the tree as a bundle. The settings go out masked, as
::  every settings read does, and a restore unmasks against the stored
::  document, so a backup never carries a secret off the ship.
::
++  read-bundle
  |=  up=@ud
  =/  m  (fiber:fiber:nexus ,bundle:reg)
  ^-  form:m
  ;<  regs=(list reg:reg)  bind:m  (load-regs up)
  ;<  sj=json  bind:m  (read-json (rf up / %'settings.json'))
  ;<  cj=json  bind:m  (read-json (rf up / %'copy.json'))
  ;<  nj=json  bind:m  (read-json (rf up / %'counts.json'))
  (pure:m [%1 regs (mask:reg sj) cj nj])
::  +serve-export: the four downloads
::
++  serve-export
  |=  [eyre-id=@ta which=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(?(%'people.csv' %'regs.csv' %'bundle.json' %'bundle.jam') which)
    (send-err eyre-id 404 'no such export')
  ;<  now=@da  bind:m  get-time:io
  ;<  s=settings:reg  bind:m  (read-settings 1)
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  =/  day=@t  (end [3 10] (en-iso:reg now))
  ?:  =(%'people.csv' which)
    =/  fname=@t  (rap 3 'register-people-' day '.csv' ~)
    =/  body=octs  (as-octs:mimes:html (csv-people:reg regs s))
    (send-download eyre-id 'text/csv; charset=utf-8' fname body)
  ?:  =(%'regs.csv' which)
    =/  fname=@t  (rap 3 'register-regs-' day '.csv' ~)
    =/  body=octs  (as-octs:mimes:html (csv-regs:reg regs s))
    (send-download eyre-id 'text/csv; charset=utf-8' fname body)
  ;<  b=bundle:reg  bind:m  (read-bundle 1)
  ?:  =(%'bundle.json' which)
    =/  fname=@t  (rap 3 'register-' day '.json' ~)
    =/  body=octs  (as-octs:mimes:html (en:json:html (en-bundle:reg b)))
    (send-download eyre-id 'application/json; charset=utf-8' fname body)
  =/  a=@  (jam-bundle:reg b)
  =/  fname=@t  (rap 3 'register-' day '.jam' ~)
  (send-download eyre-id 'application/octet-stream' fname [(met 3 a) a])
::  +serve-import: a jam or a JSON bundle, inspected with dry=1 and
::  applied otherwise. A bundle that does not read answers 400 saying
::  what was wrong with it, and nothing is written.
::
::  The dry run answers a confirm token over the decoded bundle and the
::  ids the tree holds right now. The apply needs that token back, so a
::  restore that was inspected against a different tree is refused.
::
++  serve-import
  |=  [eyre-id=@ta jon=json args=quay:eyre by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  dry=?  =('1' (fall (get-key:kv:html-utils 'dry' args) ''))
  =/  wipe=?  =('1' (fall (get-key:kv:html-utils 'wipe' args) ''))
  =/  b64=@t  (gs:reg jon 'jam')
  =/  got=(each bundle:reg @t)
    ?.  =('' b64)
      =/  dec=(unit (unit octs))  (mole |.((de:base64:mimes:html b64)))
      ?~  dec  [%| 'jam: not base64']
      ?~  u.dec  [%| 'jam: not base64']
      =/  cued=(unit bundle:reg)  (cue-bundle:reg q.u.u.dec)
      ?~  cued  [%| 'jam: not a register bundle']
      [%& u.cued]
    ?.  (has-key:reg jon 'bundle')  [%| 'jam or bundle is required']
    (de-bundle-why:reg (gj:reg jon 'bundle'))
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  =/  b=bundle:reg  p.got
  ;<  have=(list reg:reg)  bind:m  (load-regs 1)
  =/  here=(set @ta)  (sy (turn have |=(r=reg:reg id.r)))
  =/  confirm=@t  (hex-of:reg (sham [b here]) 8)
  ?:  dry
    =/  ids=(list @ta)  (turn regs.b |=(r=reg:reg id.r))
    =/  stamps=(list @da)  (turn regs.b |=(r=reg:reg created.r))
    =/  over=@ud  (lent (skim ids |=(i=@ta (~(has in here) i))))
    =/  done=@ud  (lent (skim regs.b |=(r=reg:reg =(%complete status.r))))
    =/  wl=@ud  (lent (skim regs.b |=(r=reg:reg =(%waitlist status.r))))
    =/  gone=@ud  (lent (skim regs.b |=(r=reg:reg =(%cancelled status.r))))
    %^  send-json  eyre-id  200
    %-  pairs:enjs:format
    :~  ['regs' (en-num:reg (lent regs.b))]
        ['complete' (en-num:reg done)]
        ['waitlist' (en-num:reg wl)]
        ['cancelled' (en-num:reg gone)]
        ['earliest' (en-maybe-time:reg (min-date stamps))]
        ['latest' (en-maybe-time:reg (max-date stamps))]
        ['event_days' (gj:reg (gj:reg settings.b 'event') 'days')]
        ['overwrite' (en-num:reg over)]
        ['confirm' s+confirm]
    ==
  =/  said=@t  (fall (get-key:kv:html-utils 'confirm' args) '')
  ?.  =(said confirm)
    (send-err eyre-id 400 'confirm: the dry run token is missing or stale')
  ;<  err=(unit tang)  bind:m
    (poke-soft:io (rf 1 / %'main.sig') [[/register %bundle] [wipe by b]])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  %^  send-json  eyre-id  200
  (pairs:enjs:format ~[['ok' b+&] ['applied' (en-num:reg (lent regs.b))]])
::  +serve-add: a manual registration. Strict input, the duplicate rule
::  the pilgrims have, and no window or cap check at all.
::
++  serve-add
  |=  [eyre-id=@ta jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  got  (de-input:reg (gj:reg jon 'input') &)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  =/  dup=(unit reg:reg)  (dup-of regs email.contact.p.got %$)
  ?^  dup
    %^  send-json  eyre-id  409
    (pairs:enjs:format ~[['error' s+'email: already registered'] ['code' s+'duplicate']])
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  rid=@ta  (rid-from:reg eny)
  =/  token=@t  (token-from:reg eny)
  =/  paper=?  (gb:reg jon 'waiver_paper')
  =/  pj=json  (gj:reg jon 'paid')
  =/  meth=@t  (gs:reg pj 'method')
  =/  paid=?  &(?=([%o *] pj) ?=(?(%check %cash %other) meth))
  ?:  &(paid !paper)
    (send-err eyre-id 400 'paid: a payment needs the waiver on paper')
  =/  after=@tas  ?:(assistance.p.got %assistance %payment)
  =/  final=@tas  ?.(paper %waiver ?.(paid after %complete))
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'add']  ['rid' s+rid]  ['token' s+token]  ['by' s+by]
        ['input' (gj:reg jon 'input')]
        ['exempt' b+(gb:reg jon 'exempt')]
        ['waiver_paper' b+paper]
        ['paid' pj]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  %^  send-json  eyre-id  200
  (pairs:enjs:format ~[['rid' s+rid] ['token' s+token] ['status' s+final]])
::  ==  the check-in

::  +by-last: the roster's order, the first person's last name, ties
::  broken by rid. +aor and not +lth: a cord compares as a number, and
::  'ab' is the larger number but the earlier name.
::
++  by-last
  |=  [a=reg:reg b=reg:reg]
  ^-  ?
  =/  x=@t  ?~(people.a '' (lower last.i.people.a))
  =/  y=@t  ?~(people.b '' (lower last.i.people.b))
  ?.  =(x y)  (aor x y)
  (aor id.a id.b)
::  +find-by-id: one registration out of a list already loaded
::
++  find-by-id
  |=  [regs=(list reg:reg) rid=@ta]
  ^-  (unit reg:reg)
  ?:  =(%$ rid)  ~
  |-  ^-  (unit reg:reg)
  ?~  regs  ~
  ?:  =(rid id.i.regs)  `i.regs
  $(regs t.regs)
::  +serve-checkin-roster: every party a volunteer may meet that day,
::  sorted by the first person's last name. A draft is not a
::  registration yet and is left out; a cancelled one is carried, so a
::  volunteer searching the name reads the red answer rather than
::  nothing.
::
++  serve-checkin-roster
  |=  [eyre-id=@ta day=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  want=(unit @tas)  (checkin-day:reg day)
  ?~  want  (send-err eyre-id 400 'day: fri, sat or sun')
  ;<  now=@da  bind:m  get-time:io
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  ;<  cj=json  bind:m  (read-json (rf 1 / %'counts.json'))
  =/  shown=(list reg:reg)  (skip regs |=(r=reg:reg =(%draft status.r)))
  =/  rows=(list reg:reg)  (sort shown by-last)
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['day' s+u.want]
      ['now' (en-time:reg now)]
      ['rows' a+(turn rows |=(r=reg:reg (en-roster-row:reg r u.want)))]
      ['planned' (planned:reg rows u.want)]
      ['counts' (gj:reg cj u.want)]
  ==
::  +serve-checkin: a batch of taps from one phone. Each item is checked
::  against the tree here, so a rid or an index that is gone comes back
::  named instead of vanishing into the writer.
::
++  serve-checkin
  |=  [eyre-id=@ta jon=json by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  want=(unit @tas)  (checkin-day:reg (gs:reg jon 'day'))
  ?~  want  (send-err eyre-id 400 'day: fri, sat or sun')
  =/  items=(list json)  (ga:reg jon 'checkins')
  ?:  (gth (lent items) 200)  (send-err eyre-id 400 'checkins: over 200 in one batch')
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  ;<  out=[done=@ud bad=(list json)]  bind:m
    (apply-checkins regs u.want by items 0 ~)
  %^  send-json  eyre-id  200
  (pairs:enjs:format ~[['applied' (en-num:reg done.out)] ['rejected' a+bad.out]])
::  +apply-checkins: one writer op per good item, one named refusal per
::  bad one. The count is of items the writer took, not of tree changes:
::  a tap on someone already checked in is applied and changes nothing.
::
++  apply-checkins
  |=  [regs=(list reg:reg) day=@tas by=@t items=(list json) done=@ud bad=(list json)]
  =/  m  (fiber:fiber:nexus ,[@ud (list json)])
  ^-  form:m
  ?~  items  (pure:m [done (flop bad)])
  =/  it=json  i.items
  =/  rid=@t  (gs:reg it 'rid')
  =/  i=@ud  (fall (gn:reg it 'i') 0)
  =/  cur=(unit reg:reg)  (find-by-id regs ?:((ok-rid:reg rid) `@ta`rid %$))
  =/  why=@t
    ?~  cur  'no such registration'
    ?.  (lth i (lent people.u.cur))  'no such person'
    ''
  ?.  =('' why)
    =/  row=json
      (pairs:enjs:format ~[['rid' s+rid] ['i' (en-num:reg i)] ['why' s+why]])
    (apply-checkins regs day by t.items done [row bad])
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'checkin']  ['rid' s+rid]  ['i' (en-num:reg i)]
        ['day' s+day]  ['undo' b+(gb:reg it 'undo')]  ['by' s+by]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  (apply-checkins regs day by t.items ?^(err done +(done)) bad)
::  +do-checkin: one person checked in, or the check-in taken back. A
::  tap that changes nothing writes nothing: no grub, no ring entry, no
::  beacon, so two volunteers tapping the same name cost one write.
::
++  do-checkin
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  rid=@ta  (rid-of jon)
  =/  by=@t  (by-of jon)
  =/  i=@ud  (fall (gn:reg jon 'i') 0)
  =/  undo=?  (gb:reg jon 'undo')
  =/  want=(unit @tas)  (checkin-day:reg (gs:reg jon 'day'))
  ?~  want  (refuse 'checkin' 'day: fri, sat or sun')
  ;<  now=@da  bind:m  get-time:io
  ;<  cur=(unit reg:reg)  bind:m  (find-reg 0 rid)
  ?~  cur  (refuse 'checkin' 'no such registration')
  =/  next=(unit reg:reg)  (with-checkin:reg u.cur i u.want by now undo)
  ?~  next  (refuse 'checkin' 'no such person')
  ?:  =(u.next u.cur)  (pure:m |)
  ;<  ~  bind:m  (write-reg 0 u.next |)
  ;<  ~  bind:m  (note-rid 'checkin' & u.want by rid)
  (pure:m &)
::  +serve-resend-template: phase 2 sends the mail. Here the subject is
::  filled and noted in the ring, so a rehearsal reads what would go
::  out. Never a body: a body carries the manage link.
::
++  serve-resend-template
  |=  [eyre-id=@ta r=reg:reg jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  tpl=@t  (gs:reg jon 'template')
  ::  the names carry underscores, which a term may not, so they are
  ::  compared as cords
  =/  known=?
    ?|  =('confirmation' tpl)  =('manage' tpl)  =('promoted' tpl)
        =('assistance_approved' tpl)  =('assistance_declined' tpl)
        =('reminder' tpl)  =('cancelled' tpl)
    ==
  ?.  known
    (send-err eyre-id 400 'template: not one of the seven')
  ;<  cj=json  bind:m  (read-json (rf 1 / %'copy.json'))
  ;<  regs=(list reg:reg)  bind:m  (load-regs 1)
  =/  raw=@t  (gs:reg cj (rap 3 'email.' tpl '.subject' ~))
  =/  who=@t  ?~(people.r '' first.i.people.r)
  =/  posn=@t  (crip (a-co:co (position-of:reg regs r)))
  =/  subj=@t
    ?:  =('' raw)  (rap 3 'no copy for email.' tpl '.subject' ~)
    (fill:reg raw ~[['first' who] ['position' posn]])
  =/  pk=json
    %-  pairs:enjs:format
    :~  ['op' s+'note']  ['what' s+(rap 3 'email.' tpl ~)]  ['ok' b+&]
        ['why' s+subj]  ['by' s+'stub']  ['rid' s+id.r]
    ==
  ;<  err=(unit tang)  bind:m  (poke-writer pk)
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  %^  send-json  eyre-id  200
  (pairs:enjs:format ~[['ok' b+&] ['template' s+tpl] ['subject' s+subj]])
--
