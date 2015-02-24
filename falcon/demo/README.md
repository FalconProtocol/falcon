
This is a demo implementation of the receiving FALCON protocol endpoint.

To be functional it should be connected with proper data sources,
 that takes care of state changes for transfer orders;
 as well as have access to Bitcoin Liquidity and monitoring
 (example BitX API)

The sending endpoint needs to do various balance,
identity and authorization checks; and the eventual bitcoin send.

Details regarding the payer hash and API authentication is to be defined by the protocol and falcon CA




# TO run the demo endpoint:

- install ruby 2.2.0
- install rubygems
- install bundler

`bundle install`

`bundle exec rackup`


## using Httpie

```http -a falcon:demo POST localhost:9292/falcon account==BXACCT0001 amount==200 currency==zar refund_address==127zNrQ7jfeTonFCGN2K7znptdKXt8Pz9N payer==falcontestdemohash```


## using cURL

```curl -u falcon:demo -d "account=BXACCT0002&amount=30&currency=myr&refund_address=127zNrQ7jfeTonFCGN2K7znptdKXt8Pz9N&payer=falcontestdemohash" http://localhost:9292/falcon```
