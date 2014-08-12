#FALCON Specification 0.1 (Draft, Not finalized)

## Scope

The scope of this document is to provide an overview and working documentation of the FALCON protocol specification.
It is primarily concered by the interaction between gateways. 

We assume each gateway will have:
- to implement some client application for initiating and authorising transfers.
- access to some registry or some means of finding, connecting and authorising with other gateways. 

These are non trivial assumptions and other documents will discuss these in detail.


role | description
 --- | ---
Gateway | 	an institution that implements the FALCON protocol	
Sender |	a gateway that allow its clients (payers) to send money	
Payer	| an account holder at the sender gateway	
Receiver |	a gateway that allow its clients (beneficiaries) to receive money	
Beneficiary |	an account holder at the receiving gateway
Third Party Beneficiary | an account that the receiving gateway can pay to, but is not a direct account holder of the receiver
Liquidity Provider | a service that buys Bitcoin from Receiver and sells Bitcoin to Sender at quoted prices and volumes


### Simple transfer

The basic case is where a *payer* wants to send a specified amount of money to a *beneficiary*. As FALCON relies on quotes  the payer can specify the amount of money the beneficiary is to receive.

A HTTPS POST request is made to the Receiver falcon endpoint containing all the information needed to verify authenticity of the request, verify the beneficiary, identify the sender and all the transaction information needed to generate a quote and subsequently transfer the funds.

HTTPS request:

```http
POST /falcon?account=BX456898765?amount=15900?currency=USD?description=Remittance+Gift+from+Payer?payer=identification-information?refund_address=1B1tC0InExAMPL3rEfundAdDreS5t0Use?sender=auth-token-or-cert
```

JSON success response:
```json
{
  "status"     : "OK",
  "currency"   : "XBT",
  "amount"     : "0.28",
  "address"    : "1B1tC0InExAMPL3fundIN6AdDreS5t0Use",
  "expires_at" : 1402760613
}
```

JSON failure response:
```json
{
  "status"     : "FAIL",
  "code"       : "00",
  "message"    : "unauthorised"
}
```

### Failures

code | message | description
 --- | --- | ---
00 | unauthorised | the receiver cannot authenticate the sender
01 | account invalid | the account identifier is invalid
02 | currency not supported | the requested currency cannot be sent to the account
03 | amount invalid | the transfer amount requested cannot be sent at this time
04 | refund address invalid | the refund address is not a valid bitcoin address
05 | payer invalid | the payer information is not sufficient
06 | description invalid | the description should not be blank

