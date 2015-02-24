require 'sinatra/base'
require 'json'

# Order is used to process and return a transfer object to the sender.
# The order will contain a bitcoin address, that will be monitored for the duration of the quote time, and periodically thereafer
# If the expected bitcoin amount is deposited to the address before the expire time, the transaction will complete successfully (payment settlement to receiver can continue)
# If more bitcoin is deposited to the address, it will be returned to the refund_address address
# If too little bitcoin is deposited it must be returned to the refund_address address too.

# Orders should be in some form of a database where monitoring etc can be run from; and payments can be made from.
Order = Struct.new(:q_id, :bitcoin_amount, :expires_at, :bitcoin_address, :refund_address, :description, :payer) do
  def address
    # an unique address per transfer that can be monitored to know if transaction is filled.
    # could get this from brokerage
    # BitX example:
    #                 BitX.new_receive_address[:address]
    @bitcoin_address ||= '1demob1tc01naddressf0rfalc0n'
  end

  def received_bitcoin?
    if BitX.received_by_address(address)["total_received"].to_f >= @bitcoin_amount.to_f
      if Time.now.to_i < @expires_at.to_i - 30000
        BitX.exercise_quote(@q_id)
      end
    end
  end

  def refund_if_required; end
  def pay_recipient; end

  # TODO Code that monitors receiving of bitcoin untill expires_at
  #      and credits funds to the recieving account
  #      and performs refunds for amounts overpaid and late payments

end


class Falcon < Sinatra::Base


  # handle api authentication
  helpers do
    def protected!
      return if authorized?
      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
      halt 401, {
        status:   "FAIL",
        code:     "00",
        message:  "unauthorised"
      }.to_json
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == ['falcon', 'demo']
    end
  end


  # Endpoint to confirm that the service is running
  # http GET localhost:9292/authed
  get '/' do
    'FALCON service active'
  end

  # Endpoint to confirm that the caller is authorized
  # http -a falcon:demo GET localhost:9292/authed
  # {"status":"OK"}
  get '/authed' do
    protected!
    {status: "OK"}.to_json
  end

  # FALCON protocol receive endpoint
  # using httpie for demo:
  # http -a falcon:demo POST localhost:9292/falcon account==BXACCT0001 amount==200 currency==zar refund_address==127zNrQ7jfeTonFCGN2K7znptdKXt8Pz9N payer==falcontestdemohash
  #
  # This method relies on a number of
  post '/falcon' do
    protected!
    pay_to( params[:account] ) do |account|
      with_currency( account, params[:currency] ) do |cur|
        refund_address = refund_to( params[:refund_address] )
        description = params[:description] || ""
        payer = validate_payer(params[:payer])
        amount = params[:amount].to_f
        if can_deliver?(cur, amount)

          begin
            # get quote from broker
            q = create_quote(cur, amount)

            # create order
            o = Order.new(q[:id], q[:counter_amount], q[:expires_at], nil, refund_address, description, payer)

            # return order
            {
              status:      "OK",
              currency:    "XBT",
              amount:      o.bitcoin_amount,
              address:     o.address,
              expires_at:  o.expires_at.to_i - 30000
            }.to_json
          rescue
            halt 400, {
              status:   "FAIL",
              code:     "03",
              message:  "Amount cannot be processes at this time"
            }.to_json
          end
        else
          halt 400, {
              status:   "FAIL",
              code:     "03",
              message:  "Amount invalid"
            }.to_json
        end
      end
    end
  end


  # * mocked for demo *
  def create_quote(cur, amount)
    # an example of using BitX broker:
    #   BitX.create_quote("#{cur}XBT", add_profit(amount), "BUY")
    # would return something like the following
    {
      id:             1234,
      type:           'BUY',
      pair:           "#{cur}XBT",
      base_amount:    add_profit(amount),
      counter_amount: "0.0123",
      created_at:     Time.now,
      expires_at:     Time.now + 300,
      discarded:      false,
      exercised:      false
    }
  end

  # some profit/added cost calculations
  def add_profit(amount)
    amount * 1.005
  end

  # confirm the amount can be credited to the receiver
  def can_deliver?(cur, amount)
    amount > 0.01 && amount <= available_balance(cur)
  end

  # check balance available for payout
  # * mocked for demo *
  def available_balance(cur)
    1000
  end

  # performs some validation check or CA service lookup for possible KYC/AML requirements
  # for demo we just check that is isn't blank
  def validate_payer(payer_hash, &block)
    if payer_hash.nil? || payer_hash == ''
      halt 400, {
        status:   "FAIL",
        code:     "05",
        message:  "payer invalid"
      }.to_json
    else
      if block_given?
        yield payer_hash
      else
        payer_hash
      end
    end
  end

  # requires a valid bitcoin address to send refunds (over- or underpayments) to
  def refund_to(address, &block)
    #basic test for valid address
    if address =~ /^[13][a-km-zA-HJ-NP-Z0-9]{26,33}$/
      #could add some additional checks/requirements here
      if block_given?
        yield(address)
      else
        address
      end
    else
      halt 400, {
        status:   "FAIL",
        code:     "04",
        message:  "refund address invalid"
      }.to_json
    end
  end

  #verifies that a valid receiving account identifier was supplied
  def pay_to(account_identifier, &block)
    account = ACCOUNT[account_identifier]
    if account
      if block_given?
        yield(account)
      else
        account
      end
    else
      halt 400, {
        status:   "FAIL",
        code:     "01",
        message:  "account invalid"
      }.to_json
    end
  end

  #verifies that the receiving account can receive the specified currency
  def with_currency(account, cur, &block)
    if cur.nil?
      halt 400, {
        status:   "FAIL",
        code:     "02",
        message:  "currency is required"
      }.to_json
    end
    cur = cur.upcase
    if account[:currencies].include? cur
      if block_given?
        yield(cur)
      else
        cur
      end
    else
      halt 400, {
        status:   "FAIL",
        code:     "02",
        message:  "currency not supported"
      }.to_json
    end
  end


  # Receiving Accounts
  # * mocked * FOR DEMO PURPOSES
  # would in practice be in some database, with accounts that can be credited
  ACCOUNT = {
    "BXACCT0001" => {
      currencies: %w{ZAR XBT}
    },
    "BXACCT0002" => {
      currencies: %w{MYR XBT}
    },
    "BXACCT0003" => {
      currencies: %w{IDR XBT}
    }
  }


end

