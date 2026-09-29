::  the Resend send, built and read
::
/+  *test, mail=register-mail
|%
++  test-send-body
  %+  expect-eq
    !>  '{"from":"a@b.com","to":["b@c.org"],"subject":"Hi","text":"hello"}'
    !>  (send-body:mail 'a@b.com' 'b@c.org' 'Hi' 'hello')
::
++  test-send-body-escapes
  ::  a newline and a quote survive into the JSON, escaped
  %+  expect-eq
    !>  &
    !>  ?=(^ (de:json:html (send-body:mail 'a@b.com' 'b@c.org' 'He said "hi"' 'one\0aline')))
::
++  test-headers
  %+  expect-eq
    !>  'Bearer re_1'
    !>  +:-:(headers:mail 're_1')
::
++  test-read-send-ok
  ;:  weld
    (expect-eq !>(`'m1') !>((read-send:mail 200 '{"id":"m1"}')))
    (expect-eq !>(`'m2') !>((read-send:mail 201 '{"id":"m2"}')))
  ==
::
++  test-read-send-refused
  ;:  weld
    (expect-eq !>(~) !>((read-send:mail 422 '{"id":"m1"}')))
    (expect-eq !>(~) !>((read-send:mail 200 '{"message":"bad key"}')))
    (expect-eq !>(~) !>((read-send:mail 200 'not json')))
  ==
--
