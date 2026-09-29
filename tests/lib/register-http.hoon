::  the pure text of an outbound request
::
/+  *test, http=register-http
|%
++  test-url-encode-plain
  %+  expect-eq
    !>  'abcXYZ019-._~'
    !>  (url-encode:http 'abcXYZ019-._~')
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
