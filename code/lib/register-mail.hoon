::  register-mail: one Resend send, as pure text. Import-free like the
::  rest of register's libraries.
::
|%
++  api  'https://api.resend.com/emails'
::  +headers: JSON in, with the API key as a bearer token
::
++  headers
  |=  key=@t
  ^-  (list [@t @t])
  :~  ['authorization' (cat 3 'Bearer ' key)]
      ['content-type' 'application/json']
  ==
::  +send-body: the request body. Plain text only: register sends no
::  HTML, so nothing a mail client renders can differ from what the
::  organizers wrote in copy.json.
::
++  send-body
  |=  [from=@t to=@t subject=@t text=@t]
  ^-  @t
  %-  en:json:html
  %-  pairs:enjs:format
  :~  ['from' s+from]
      ['to' a+~[s+to]]
      ['subject' s+subject]
      ['text' s+text]
  ==
::  +read-send: the message id Resend answers with, or ~ when it did
::  not take the message. The caller records only the id.
::
++  read-send
  |=  [status=@ud body=@t]
  ^-  (unit @t)
  ?.  |(=(200 status) =(201 status))  ~
  =/  jon=(unit json)  (de:json:html body)
  ?~  jon  ~
  ?.  ?=([%o *] u.jon)  ~
  =/  v=json  (fall (~(get by p.u.jon) 'id') ~)
  ?.  ?=([%s *] v)  ~
  ?:(=('' p.v) ~ `p.v)
::  +why-not: what Resend said when it would not send, short enough for
::  the ring. A key that may only mail its own owner, an unverified from
::  domain and a bad key all come back here, and an organizer reading
::  the log needs to tell them apart.
::
++  why-not
  |=  [status=@ud body=@t]
  ^-  @t
  =/  jon=(unit json)  (de:json:html body)
  =/  msg=@t
    ?~  jon  ''
    ?.  ?=([%o *] u.jon)  ''
    =/  v=json  (fall (~(get by p.u.jon) 'message') ~)
    ?:(?=([%s *] v) p.v '')
  =/  code=@t  (crip (a-co:co status))
  ?:(=('' msg) code (rap 3 ~[code ': ' msg]))
--
