::  register-http: the parts of an outbound request that are pure text.
::
::  Import-free like code/lib/register.hoon, with no /< and no /&, so the
::  test kit builds it for a clay desk with no translation.
::
|%
::  +url-encode: percent-encode a cord. Everything outside the unreserved
::  set A-Za-z0-9 - . _ ~ becomes %XX over the UTF-8 bytes, hex in upper
::  case. A space becomes %20.
::
++  url-encode  |=(t=@t ^-(@t (encode t |)))
::  +form-encode: the same, but a space becomes +.
::
::  This is what application/x-www-form-urlencoded actually specifies,
::  and it is not cosmetic: iris mangles a %20 inside a url it is handed
::  and the far end answers a bare nginx 400. One word searched fine and
::  two words did not, which is how that was found.
::
++  form-encode  |=(t=@t ^-(@t (encode t &)))
++  encode
  |=  [t=@t plus=?]
  ^-  @t
  =/  hex=@t  '0123456789ABCDEF'
  %+  rap  3
  %+  turn  (rip 3 t)
  |=  b=@
  ^-  @t
  ?:  &(plus =(b ' '))  '+'
  ?:  ?|  &((gte b 'a') (lte b 'z'))
          &((gte b 'A') (lte b 'Z'))
          &((gte b '0') (lte b '9'))
          =(b '-')  =(b '.')  =(b '_')  =(b '~')
      ==
    b
  %+  rap  3
  :~  '%'
      (cut 3 [(div b 16) 1] hex)
      (cut 3 [(mod b 16) 1] hex)
  ==
::  +form-body: an application/x-www-form-urlencoded body. Keys are
::  encoded too, because Stripe's are full of brackets.
::
++  form-body
  |=  kvs=(list [k=@t v=@t])
  ^-  @t
  |-  ^-  @t
  ?~  kvs  ''
  =/  one=@t  (rap 3 ~[(form-encode k.i.kvs) '=' (form-encode v.i.kvs)])
  =/  rest=@t  $(kvs t.kvs)
  ?:  =('' rest)  one
  (rap 3 ~[one '&' rest])
::  +bearer: the Authorization header value for a bearer token.
::
++  bearer
  |=  t=@t
  ^-  @t
  (cat 3 'Bearer ' t)
--
