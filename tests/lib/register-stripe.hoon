::  the Stripe calls, built and read
::
/+  *test, stripe=register-stripe, http=register-http
|%
++  lines  ~[['Registration' 15.000] ['Gift to the Baby Steps Camino' 5.000]]
::
++  body
  ^-  @t
  %-  form-body:http
  (checkout-body:stripe 'r1' 'a@b.com' lines 'https://x.test/ok' 'https://x.test/no' 1.800.000.000)
::
++  has
  |=  t=@t
  ^-  ?
  ?=(^ (find (trip t) (trip body)))
::
++  test-checkout-mode
  (expect-eq !>(&) !>((has 'mode=payment')))
::
++  test-checkout-rid
  (expect-eq !>(&) !>((has 'metadata%5Brid%5D=r1')))
::
++  test-checkout-email
  (expect-eq !>(&) !>((has 'customer_email=a%40b.com')))
::
++  test-checkout-urls
  ;:  weld
    (expect-eq !>(&) !>((has 'success_url=https%3A%2F%2Fx.test%2Fok')))
    (expect-eq !>(&) !>((has 'cancel_url=https%3A%2F%2Fx.test%2Fno')))
  ==
::
++  test-checkout-expires
  (expect-eq !>(&) !>((has 'expires_at=1800000000')))
::
++  test-checkout-lines
  ;:  weld
    (expect-eq !>(&) !>((has 'line_items%5B0%5D%5Bprice_data%5D%5Bunit_amount%5D=15000')))
    (expect-eq !>(&) !>((has 'line_items%5B1%5D%5Bprice_data%5D%5Bunit_amount%5D=5000')))
    (expect-eq !>(&) !>((has 'line_items%5B1%5D%5Bquantity%5D=1')))
  ==
::
++  test-checkout-no-email
  ::  an empty address is left out rather than sent empty
  =/  b=@t
    %-  form-body:http
    (checkout-body:stripe 'r1' '' lines 'u' 'v' 0)
  (expect-eq !>(~) !>((find "customer_email" (trip b))))
::
++  test-read-session-paid
  =/  j=@t
    '{"id":"cs_test_1","payment_status":"paid","amount_total":20000,"metadata":{"rid":"r1"},"url":"https://pay.test/1"}'
  (expect-eq !>(`['cs_test_1' & 20.000 'r1' 'https://pay.test/1']) !>((read-session:stripe j)))
::
++  test-read-session-unpaid
  =/  j=@t  '{"id":"cs_test_2","payment_status":"unpaid","amount_total":0,"metadata":{},"url":""}'
  =/  r  (read-session:stripe j)
  ?~  r  (expect-eq !>(&) !>(|))
  (expect-eq !>(|) !>(paid.u.r))
::
++  test-read-session-garbage
  ;:  weld
    (expect-eq !>(~) !>((read-session:stripe 'not json')))
    (expect-eq !>(~) !>((read-session:stripe '{"error":{"message":"no such session"}}')))
  ==
::
++  test-webhook-sid
  =/  j=@t
    '{"type":"checkout.session.completed","data":{"object":{"id":"cs_test_9","object":"checkout.session"}}}'
  (expect-eq !>(`'cs_test_9') !>((webhook-sid:stripe j)))
::
++  test-webhook-other-event
  =/  j=@t
    '{"type":"payment_intent.succeeded","data":{"object":{"id":"pi_1"}}}'
  (expect-eq !>(~) !>((webhook-sid:stripe j)))
::
++  test-read-livemode
  ;:  weld
    (expect-eq !>(`|) !>((read-livemode:stripe '{"object":"balance","livemode":false}')))
    (expect-eq !>(`&) !>((read-livemode:stripe '{"object":"balance","livemode":true}')))
    (expect-eq !>(~) !>((read-livemode:stripe '{"error":{"message":"bad key"}}')))
  ==
--
