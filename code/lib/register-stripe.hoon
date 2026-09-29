::  register-stripe: the Stripe Checkout calls, as pure text.
::
::  Nothing here talks to anything. Each arm either builds a request the
::  nexus hands to iris, or reads a body iris brought back. Import-free
::  like the rest of register's libraries.
::
::  Only Checkout is used. There is no signature check on the webhook,
::  because the webhook body is never trusted: the route takes the
::  session id out of it and asks Stripe directly.
::
|%
++  api  'https://api.stripe.com/v1'
::  ==  reading json, the few getters these arms need
::
++  gj                                          ::  one key, or ~
  |=  [jon=json k=@t]
  ^-  json
  ?.  ?=([%o *] jon)  ~
  (fall (~(get by p.jon) k) ~)
++  gs                                          ::  a string, or ''
  |=  [jon=json k=@t]
  ^-  @t
  =/  v=json  (gj jon k)
  ?:(?=([%s *] v) p.v '')
++  gn                                          ::  a whole number, or 0
  |=  [jon=json k=@t]
  ^-  @ud
  =/  v=json  (gj jon k)
  ?.  ?=([%n *] v)  0
  (fall (rush p.v dem) 0)
++  num                                         ::  decimal, no dots
  |=  n=@ud
  ^-  @t
  (crip (a-co:co n))
::  ==  building requests
::
::  +headers: form-encoded, with the secret key as a bearer token
::
++  headers
  |=  key=@t
  ^-  (list [@t @t])
  :~  ['authorization' (cat 3 'Bearer ' key)]
      ['content-type' 'application/x-www-form-urlencoded']
  ==
::  +line: one line item's form keys. `i` is its place in the list,
::  `cents` its whole price, quantity always one.
::
++  line
  |=  [i=@ud name=@t cents=@ud]
  ^-  (list [@t @t])
  =/  pre=@t  (rap 3 ~['line_items[' (num i) ']'])
  :~  [(cat 3 pre '[quantity]') '1']
      [(cat 3 pre '[price_data][currency]') 'usd']
      [(cat 3 pre '[price_data][unit_amount]') (num cents)]
      [(cat 3 pre '[price_data][product_data][name]') name]
  ==
::  +checkout-body: the form pairs of a Checkout session. The caller
::  passes the urls whole; +form-body encodes them, and Stripe decodes
::  {CHECKOUT_SESSION_ID} back out of success_url at its end.
::
++  checkout-body
  |=  $:  rid=@t
          email=@t
          lines=(list [name=@t cents=@ud])
          success=@t
          cancel=@t
          expires=@ud
      ==
  ^-  (list [@t @t])
  =/  items=(list [@t @t])
    =|  i=@ud
    |-  ^-  (list [@t @t])
    ?~  lines  ~
    (weld (line i name.i.lines cents.i.lines) $(lines t.lines, i +(i)))
  ;:  weld
    :~  ['mode' 'payment']
        ['client_reference_id' rid]
        ['metadata[rid]' rid]
        ['success_url' success]
        ['cancel_url' cancel]
    ==
    ?:(=('' email) ~ ~[['customer_email' email]])
    ?:(=(0 expires) ~ ~[['expires_at' (num expires)]])
    items
  ==
::  ==  reading answers
::
::  +read-session: what the app is allowed to believe about a session.
::  Only paid, the total, and whose registration it was.
::
++  read-session
  |=  body=@t
  ^-  (unit [id=@t paid=? total=@ud rid=@t url=@t])
  =/  jon=(unit json)  (de:json:html body)
  ?~  jon  ~
  =/  id=@t  (gs u.jon 'id')
  ?:  =('' id)  ~
  :-  ~
  :*  id
      =('paid' (gs u.jon 'payment_status'))
      (gn u.jon 'amount_total')
      (gs (gj u.jon 'metadata') 'rid')
      (gs u.jon 'url')
  ==
::  +webhook-sid: the checkout session an event is about. Anything that
::  is not a checkout.session.* event answers ~, and so is ignored.
::
++  webhook-sid
  |=  body=@t
  ^-  (unit @t)
  =/  jon=(unit json)  (de:json:html body)
  ?~  jon  ~
  =/  kind=@t  (gs u.jon 'type')
  ?.  =('checkout.session.' (end [3 17] kind))  ~
  =/  id=@t  (gs (gj (gj u.jon 'data') 'object') 'id')
  ?:(=('' id) ~ `id)
::  +read-livemode: whether the key that answered is a live key. Used by
::  the admin key check, which is the only thing that may say so.
::
++  read-livemode
  |=  body=@t
  ^-  (unit ?)
  =/  jon=(unit json)  (de:json:html body)
  ?~  jon  ~
  =/  v=json  (gj u.jon 'livemode')
  ?:(?=([%b *] v) `p.v ~)
--
