::  the address suggestions, built and read
::
/+  *test, places=register-places, http=register-http
|%
++  test-places-query
  =/  q=@t  (form-body:http (places-query:places 'Penman Rd'))
  =/  has  |=(t=@t ^-(? ?=(^ (find (trip t) (trip q)))))
  ;:  weld
    ::  a space rides as %2B, because iris will not carry one: see
    ::  +space-plus. Photon reads it back as a word break.
    (expect-eq !>(&) !>((has 'q=Penman%2BRd')))
    ::  roads, not bus stops and shops
    (expect-eq !>(&) !>((has 'osm_tag=highway')))
    ::  near the walk, but not walled in
    (expect-eq !>(&) !>((has 'location_bias_scale=0.6')))
  ==
::
++  body
  ^-  @t
  '''
  {"features":[
   {"properties":{"type":"house","osm_value":"bus_stop","name":"Beach Blvd.",
     "street":"Beach Boulevard","city":"Buena Park","state":"California",
     "postcode":"90622","countrycode":"US"}},
   {"properties":{"type":"street","osm_value":"residential","name":"Penman Road",
     "city":"Jacksonville Beach","state":"Florida","postcode":"32250","countrycode":"US"}},
   {"properties":{"type":"street","osm_value":"residential","name":"Penman Road",
     "city":"Jacksonville Beach","state":"Florida","postcode":"32250","countrycode":"US"}},
   {"properties":{"type":"street","osm_value":"residential","name":"Northcott Drive",
     "city":"Newcastle","state":"New South Wales","postcode":"2305","countrycode":"AU"}},
   {"properties":{"type":"street","osm_value":"residential","name":"Penman Road South",
     "city":"Jacksonville Beach","state":"Florida","postcode":"32266","countrycode":"US"}},
   {"properties":{"type":"street","osm_value":"residential",
     "city":"Nowhere","state":"Florida","postcode":"00000","countrycode":"US"}},
   {"properties":{"type":"street","osm_value":"residential","name":"Lost Road",
     "state":"Florida","postcode":"00000","countrycode":"US"}}
  ]}
  '''
::
++  test-read-places
  =/  got  (read-places:places body)
  ;:  weld
    ::  the bus stop, the Australian street, the one with no name and the
    ::  one with no town are all left out, and the repeat appears once
    (expect-eq !>(2) !>((lent got)))
    (expect-eq !>(`place:places`['Penman Road' 'Jacksonville Beach' 'Florida' '32250']) !>(-.got))
  ==
::
++  test-read-places-order
  ::  Photon's own order is kept: it has already ranked them
  =/  got  (read-places:places body)
  ?.  ?=([* * *] got)  (expect-eq !>('two') !>((lent got)))
  (expect-eq !>('Penman Road South') !>(street.i.t.got))
::
++  test-read-places-garbage
  ;:  weld
    (expect-eq !>(~) !>((read-places:places 'not json')))
    (expect-eq !>(~) !>((read-places:places '{"features":[]}')))
    (expect-eq !>(~) !>((read-places:places '{}')))
  ==
--
