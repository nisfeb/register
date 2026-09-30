::  the pure text of an outbound request
::
/+  *test, http=register-http
|%
++  test-url-encode-plain
  %+  expect-eq
    !>  'abcXYZ019-._~'
    !>  (url-encode:http 'abcXYZ019-._~')
::
++  test-url-encode-edges
  ::  both ends of all three ranges, and the bytes just outside them.
  ::  A range that loses an end encodes a letter it should have passed.
  ;:  weld
    (expect-eq !>('azAZ09') !>((url-encode:http 'azAZ09')))
    ::  '@' is 'A' - 1, '[' is 'Z' + 1, '`' is 'a' - 1, '{' is 'z' + 1,
    ::  '/' is '0' - 1 and ':' is '9' + 1
    (expect-eq !>('%40%5B%60%7B%2F%3A') !>((url-encode:http '@[`{/:')))
  ==
::
++  test-url-encode-space-and-amp
  %+  expect-eq
    !>  'a%20b%26c'
    !>  (url-encode:http 'a b&c')
::
++  test-url-encode-utf8
  ::  é is two bytes, C3 A9, and both are encoded
  %+  expect-eq
    !>  '%C3%A9'
    !>  (url-encode:http 'é')
::
++  test-url-encode-brackets
  %+  expect-eq
    !>  'line_items%5B0%5D%5Bprice%5D'
    !>  (url-encode:http 'line_items[0][price]')
::
++  test-url-encode-empty
  %+  expect-eq
    !>  ''
    !>  (url-encode:http '')
::
++  test-form-body-two-keys
  %+  expect-eq
    !>  'mode=payment&customer_email=a%40b.com'
    !>  (form-body:http ~[['mode' 'payment'] ['customer_email' 'a@b.com']])
::
++  test-form-body-space-is-plus
  ::  application/x-www-form-urlencoded spells a space +, and iris
  ::  mangles a %20 inside a url it is given: the far end answers 400.
  ::  A real + in a value still has to be encoded.
  ;:  weld
    (expect-eq !>('q=Penman+Road') !>((form-body:http ~[['q' 'Penman Road']])))
    (expect-eq !>('q=a%2Bb') !>((form-body:http ~[['q' 'a+b']])))
    ::  and a path is not a form body: there a space is still %20
    (expect-eq !>('a%20b') !>((url-encode:http 'a b')))
  ==
::
++  test-form-body-one-key
  %+  expect-eq
    !>  'mode=payment'
    !>  (form-body:http ~[['mode' 'payment']])
::
++  test-form-body-empty
  %+  expect-eq
    !>  ''
    !>  (form-body:http ~)
::
++  test-bearer
  %+  expect-eq
    !>  'Bearer sk_test_1'
    !>  (bearer:http 'sk_test_1')
--
