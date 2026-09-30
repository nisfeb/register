::  register-places: address suggestions from Photon, the OpenStreetMap
::  geocoder that is built for typing into. Pure text in, pure text out,
::  and import-free, like the rest of register's libraries.
::
::  STREET NAMES ONLY, on purpose. Asked for "1220 Penman Rd", Photon
::  answers "1220 East 3rd Avenue, Mount Dora": it matches the number
::  against some other street and offers it with every appearance of
::  confidence. An address that is wrong and looks right is worse than
::  no suggestion at all, so no house number ever comes from here. The
::  page keeps whatever number the pilgrim typed and puts it in front of
::  the street they choose.
::
|%
+$  place  [street=@t city=@t state=@t zip=@t]
++  api  'https://photon.komoot.io/api/'
++  most  6
::  ==  reading json, the few getters these arms need
::
++  gj
  |=  [jon=json k=@t]
  ^-  json
  ?.  ?=([%o *] jon)  ~
  (fall (~(get by p.jon) k) ~)
++  gs
  |=  [jon=json k=@t]
  ^-  @t
  =/  v=json  (gj jon k)
  ?:(?=([%s *] v) p.v '')
++  ga
  |=  [jon=json k=@t]
  ^-  (list json)
  =/  v=json  (gj jon k)
  ?:(?=([%a *] v) p.v ~)
::  +headers: who is asking. Photon is a free service run for the public
::  good and its terms ask that a caller name itself; its edge answers a
::  request with no user-agent with a bare nginx 400, which is how this
::  was found.
::
++  headers
  ^-  (list [@t @t])
  :~  ['user-agent' 'baby-steps-camino-register (https://babystepscamino.com)']
      ['accept' 'application/json']
  ==
::  +places-query: the query string, as pairs for +form-body.
::
::  osm_tag=highway asks for roads, which is what an address line is;
::  without it the answer is full of bus stops and shops. The walk is in
::  north-east Florida, so the bias puts what is near it first without
::  shutting anyone else out: pilgrims come from Georgia and the
::  Carolinas too.
::
++  places-query
  |=  q=@t
  ^-  (list [@t @t])
  :~  ['q' (space-plus q)]
      ['limit' '10']
      ['lang' 'en']
      ['osm_tag' 'highway']
      ['lat' '30.29']
      ['lon' '-81.39']
      ['location_bias_scale' '0.6']
  ==
::  +space-plus: a space becomes a literal +, which +form-encode then
::  writes as %2B.
::
::  This looks mad and is load-bearing. Iris will not carry a space in a
::  url: it decodes the query, finds a space, and puts a raw space into
::  the request line, and the far end answers a bare nginx 400. Both
::  spellings of a space go the same way, %20 and +, because both decode
::  to one. Any other percent-escape rides through untouched, so the
::  space is turned into a + BEFORE encoding and reaches the far end as
::  %2B. Photon reads that back as a + and breaks words on it: checked
::  both ways against "Penman Road Jacksonville" on 2026-09-30, same
::  answers.
::
::  One word searching fine and two words not is the shape this bug
::  shows up in. If iris is ever fixed, this arm can go.
::
++  space-plus
  |=  t=@t
  ^-  @t
  %+  rap  3
  %+  turn  (rip 3 t)
  |=(b=@ ^-(@t ?:(=(b ' ') '+' b)))
::  +read-places: the streets worth offering, in Photon's own order.
::
::  `type` is the discriminator that matters: a real street reads
::  "street", while a bus stop on that street reads "house". The rest is
::  housekeeping: this is a walk in the United States, a suggestion with
::  no town on it tells a pilgrim nothing, and the same street arrives
::  several times when it is drawn as several ways.
::
++  read-places
  |=  body=@t
  ^-  (list place)
  =/  jon=(unit json)  (de:json:html body)
  ?~  jon  ~
  =|  seen=(set @t)
  =|  out=(list place)
  =/  fs=(list json)  (ga u.jon 'features')
  |-  ^-  (list place)
  ?~  fs  (flop out)
  ?:  (gte (lent out) most)  (flop out)
  =/  p=json  (gj i.fs 'properties')
  =/  named=@t  (gs p 'name')
  =/  street=@t  ?:(=('' named) (gs p 'street') named)
  =/  city=@t  (gs p 'city')
  =/  state=@t  (gs p 'state')
  =/  key=@t  (rap 3 ~[street '|' city '|' (gs p 'postcode')])
  ?.  ?&  =('street' (gs p 'type'))
          =('US' (gs p 'countrycode'))
          !=('' street)
          !=('' city)
          !=('' state)
          !(~(has in seen) key)
      ==
    $(fs t.fs)
  %=  $
    fs    t.fs
    seen  (~(put in seen) key)
    out   [[street city state (gs p 'postcode')] out]
  ==
--
