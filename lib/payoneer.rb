require 'net/http'
require 'net/https'
require "payoneer/exception"

class Payoneer
  SANDBOX_API_URL = 'https://api.sandbox.payoneer.com/Payouts/HttpApi/API.aspx?'
  PRODUCTION_API_URL = 'https://api.payoneer.com/payouts/HttpAPI/API.aspx?'
  API_PORT = '443'

  def self.new_payee_link(partner_id, username, password, member_name)
    payoneer_api = self.new(partner_id, username, password)
    payoneer_api.payee_link(member_name)
  end

  def self.transfer_funds(partner_id, username, password, options)
    payoneer_api = self.new(partner_id, username, password)
    payoneer_api.transfer_funds(options)
  end

  def self.payee_exists?(partner_id, username, password, payee_id)
    payoneer_api = self.new(partner_id, username, password)
    payoneer_api.payee_exists?(payee_id)
  end

  def initialize(partner_id, username, password)
    @partner_id, @username, @password = partner_id, username, password
  end

  def payee_link(member_name)
    @member_name = member_name
    result = api_call(payee_link_args)
    api_result(result)
  end

  def transfer_funds(options)
    result = api_call(transfer_funds_args(options))
    api_result(result)
  end

  def payee_exists?(payee_id)
    result = api_call(payee_exists_args(payee_id))
    api_result(result)
  end

  def balance
    result = api_call balance_args
    api_result(result)
    response_hash = Hash.from_xml result
    response_hash["GetAccountDetails"]["AccountBalance"].to_f
  end

  private

  def api_result(body)
    puts "[debug] Payoneer Response: #{body}"
    if is_xml? body
      xml_response_result(body)
    else
      body
    end
  end

  def is_xml?(body)
    Nokogiri::XML(body).errors.empty?
  end

  def xml_response_result(body)
    raise(PayoneerException, api_error_description(body)) if failure_api_response?(body)
    true
  end

  def failure_api_response?(body)
    body_hash = Hash.from_xml(body)
    (body_hash["PayoneerResponse"] && body_hash["PayoneerResponse"]["Description"]) || (body_hash["GetPayeeDetails"] && body_hash["GetPayeeDetails"]["Error"])
  end

  def api_error_description(body)
    body_hash = Hash.from_xml(body)
    if body_hash["PayoneerResponse"]
      body_hash["PayoneerResponse"]["Description"]
    else
      body_hash["GetPayeeDetails"]["Error"]
    end
  end

  def api_call(args_hash)
    uri = URI.parse(api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data(args_hash)
    http.request(request).body
  end

  def payee_link_args
    {
      "mname" => "GetToken",
      "p1" => @username,
      "p2" => @password,
      "p3" => @partner_id,
      "p4" => @member_name
    }
  end

  def transfer_funds_args(options)
    {
      "mname" => "PerformPayoutPayment",
      "p1" => @username,
      "p2" => @password,
      "p3" => @partner_id,
      "p4" => options[:program_id],
      "p5" => options[:internal_payment_id],
      "p6" => options[:internal_payee_id],
      "p7" => options[:amount],
      "p8" => options[:description],
      "p9" => options[:date].strftime('%m/%d/%Y %H:%M:%S')
    }
  end

  def payee_exists_args(payee_id)
    {
      "mname" => "GetPayeeDetails",
      "p1" => @username,
      "p2" => @password,
      "p3" => @partner_id,
      "p4" => payee_id
    }
  end

  def balance_args
    {
        "mname" => "GetAccountDetails",
        "p1" => @username,
        "p2" => @password,
        "p3" => @partner_id,
    }
  end

  def api_url
    PRODUCTION_API_URL
  end

end

