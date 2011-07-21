class ExternalGateway < PaymentMethod

  require 'digest/sha1'
  require 'date'
  #We need access to routes to correctly assemble a return url
 include ActionController::UrlWriter

  #This is normally set in the Admin UI - the server in this case is where to redirect to.
  preference :server, :string

  #This holds JSON data - I've kind of had to make an assumption here that the gateway you use will pass this parameter through.
  #The particular gateway I am using does not accept URL parameters, it seems.
  preference :custom_data, :string
  #When the gateway redirects back to the return URL, it will usually include some parameters of its own
  #indicating the status of the transaction. The following two preferences indicate which parameter keys this
  #class should look for to detect whether the payment went through successfully.
  # {status_param_key} is the params key that holds the transaction status.
  # {successful_transaction_value} is the value that indicates success - this is usually a number.

  preference :status_param_key, :string, :default => 'status'
  preference :successful_transaction_value, :string, :default => 'success'

  #An array of preferences that should not be automatically inserted into the form
  INTERNAL_PREFERENCES = [:server, :status_param_key, :successful_transaction_value, :custom_data]


  def num_to_s(param)
    x = param.to_s.split(".")

    if x[1].length < 2
      x[1] = x[1]+"0"
    else
      x[1] = x[1]
    end

    return x.join(",")
  end

  #Arbitrarily, this class is called ExternalGateway, but the extension is a whole is named 'HostedGateway', so
  #this is what we want our checkout/admin view partials to be named.
  def method_type
    "hosted_gateway"
  end

  #Process response detects the status of a payment made through an external gateway by looking
  #for a success value (as configured in the successful_transaction_value preference), in a particular
  #parameter (as configured in the status_param_key preference).
  #For convenience, and to validate the incoming response from the gateway somewhat, it also attempts
  #to find the order from the parameters we sent the gateway as part of the return URL and returns it
  #along with the transaction status.
  def process_response(params)
    begin
      #Find order
      order = Order.find_by_number(ExternalGateway.parse_custom_data(params)["order_number"])
      raise ActiveRecord::RecordNotFound if order.token != ExternalGateway.parse_custom_data(params)["order_token"]

      #Check for successful response
      transaction_succeeded = params[self.preferred_status_param_key.to_sym] == self.preferred_successful_transaction_value.to_s
      return [order, transaction_succeeded]
    rescue ActiveRecord::RecordNotFound
      #Return nil and false if we couldn't find the order - this is probably bad.
      return [nil, false]
    end
  end

  #This is basically a attr_reader for server, but makes sure that it has been set.
  def get_server
    if self.preferred_server
      return self.preferred_server
    else
      raise "You need to configure a server to use an external gateway as a payment type!"
    end
  end

  #At a minimum, you should use this field to POST the order number and payment method id - but you can
  #always override it to do something else.
  def get_custom_data_for(order)
    return {"order_number" => order.number, "payment_method_id" => self.id, "order_token" => order.token}.to_json
  end

  #This is another case of stupid payment gateways, but does allow you to
  #store your custom data in whatever format you want, and then parse it
  #the same way. The only caveat is to make sure it returns a hash so
  #that the controller can find what it needs to.
  #By default, we try and parse JSON out of the param.
  def self.parse_custom_data(params)
    return ActiveSupport::JSON.decode(params[:custom_data])
  end


  #The payment gateway I'm using only accepts rounded-dollar amounts. Stupid.
  #I've added this method nonetheless, so that I can easily override it to round the amount
  def get_total_for(order)
    return order.total
  end

  #This is another attr_reader, but does a couple of necessary things to make sure we can keep track
  #of the transaction, even with multiple orders going on at different times.
  #By passing in a boolean to determine if the user is on an
  #admin checkout page (in which case we need to redirect to a different path), a full return url can be
  #assembled that will redirect back to the correct page
  #to complete the order.
  def get_return_url_for(order, on_admin_page = false)
    if on_admin_page
      return admin_gateway_landing_url(:host => Spree::Config[:site_url])
    else
      return gateway_landing_url(:host => Spree::Config[:site_url])
    end
  end

  #This method basically takes the preferences of the class, removing items that should not be POST'd to
  #the payment gateway, such as server, and the parameter name of the transaction success/failure field.
  #This method allows users to add preferences using class_eval, which should automatically be picked up
  #by this method and inserted into relevant forms as hidden fields.
  def additional_attributes
    self.preferences.select { |key| !INTERNAL_PREFERENCES.include?(key[0].to_sym) }
  end


  #Maksuturva specific methods added by: Karl Herler

  #hardcoded
  preference :pmt_action, :string, :default => 'NEW_PAYMENT_EXTENDED'
  preference :pmt_version, :string, :default => '0004'
  preference :pmt_currency, :string, :default => "EUR"
  preference :pmt_charset, :string, :default => "ISO-8859-1"
  preference :pmt_charsethttp, :string, :default => "ISO-8859-1"
  preference :pmt_hashversion, :string, :default => "SHA-1"
  preference :pmt_keygeneration, :string, :default => "001"

  

  #semihardcoded (should be gotten from admin)
  preference :pmt_sellerid, :string, :default => 'testikauppias'
  preference :pmt_id, :string, :default => '11223344556677889900' 
  preference :pmt_userlocale, :string, :default => "fi_FI"
  preference :pmt_escrow, :string, :default => "Y"
  preference :pmt_escrowchangeallowed, :string, :default => "N"
  preference :pmt_okreturn, :string, :default => "http://127.0.0.1/"
  preference :pmt_errorreturn, :string, :default => "http://127.0.0.1/404/"
  preference :pmt_cancelreturn, :string, :default => "http://127.0.0.1/cancel/"
  preference :pmt_delayedpayreturn, :string, :default => "http://127.0.0.1/delayed/"

  #should be dynamic
  preference :pmt_reference, :string, :default => '1232'
  preference :pmt_duedate, :string, :default => "01.00.0000"
  #preference :pmt_hash, :string, :default => "dadab9f6ca0b2885468e3245e3ee0e5d34b1351f"

  #preference :pmt_amount, :string, :default => "10,00"


  
  

  #added a generating method
  def get_maksuturva(order)
    get_hash(order)
    #get_buyername(order)
    #get_products(order)
  end

  #This method adds assigns order id to pmt_orderid
  def get_orderid(order)
    return order.number
  end

  def get_amount(order)
    #return "10,00"
    return num_to_s((order.total-order.ship_total).round(2))
    #order.total.round(2)
  end

  #gets data for pmt_buyername
  def get_buyername(order)
    return "#{order.bill_address.firstname} #{order.bill_address.lastname}"
  end

  
  #gets data for pmt_buyeraddress
  def get_buyeraddress(order)
    return order.bill_address.address1
  end

  #gets data for pmt_buyerpostalcode
  def get_buyerpostalcode(order)
    return order.bill_address.zipcode
  end

  #gets data for pmt_buyercity
  def get_buyercity(order)
    return order.bill_address.city
  end

  #gets data for pmt_buyercountry
  def get_buyercountry(order)
    return order.bill_address.country.to_s.slice(0, 2).upcase
  end

  #gets data for pmt_buyerphone
  def get_buyerphone(order)
    return order.bill_address.phone
  end

  #gets data for pmt_buyeremail
  def get_buyeremail(order)
    return ""
    #return order.bill_address.email
  end



  #gets data for pmt_deliveryname
  def get_deliveryname(order)
    return "#{order.ship_address.firstname} #{order.ship_address.lastname}"
  end

  #gets data for pmt_deliveryaddress
  def get_deliveryaddress(order)
    return order.ship_address.address1
  end

  #gets data for pmt_deliverypostalcode
  def get_deliverypostalcode(order)
    return order.ship_address.zipcode
  end

  #gets data for pmt_deliverycity
  def get_deliverycity(order)
    return order.ship_address.city
  end

  #gets data for pmt_deliverycountry
  def get_deliverycountry(order)
    return order.ship_address.country.to_s.slice(0, 2).upcase
  end

  #gets data for pmt_deliveryphone
  def get_deliveryphone(order)
    return order.ship_address.phone
  end

  #gets data for pmt_deliveryemail
  def get_deliveryemail(order)
    return ""
    #return order.bill_address.email
  end



  #preference :pmt_sellercosts, :string, :default => "0,00"

  
  #Gets the data for pmt_rows
  def get_rows(order)
    return (order.item_count+1)
  end

  def get_sum(order)
    return ""
  end


  # preference :pmt_row_name1, :string, :default => "Hat"
  # preference :pmt_row_desc1, :string, :default => "A hat with three(3) corners."
  # preference :pmt_row_quantity1, :string, :default => "1"
  # preference :pmt_row_unit1, :string, :default => "kpl"
  # preference :pmt_row_deliverydate1, :string, :default => "14.06.2011"
  # preference :pmt_row_price_net1, :string, :default => "10"
  # preference :pmt_row_vat1, :string, :default => "0,00"
  # preference :pmt_row_type1, :string, :default => "1"

  def add_shipping(order)
    date = DateTime.now

    product = {
      :name               => "Shipping",
      :desc               => "product", 
      #:price_vat          => num_to_s(product.price.round(2)), 
      :quantity           => "1",
      :unit               => "kpl",
      :deliverydate       => "#{date.day}.#{date.month}.#{date.year}",
      :price_net          => num_to_s(order.ship_total.round(2)),
      :vat                => "0,00",
      :discountpercentage => "0,00",
      :type => "2"
    }

    return product
  end

  def get_products(order)
    date = DateTime.now
    products = Array.new();
    
    order.products.each_with_index do |product, i|
      products[i] = {
        :name               => product.name,
        :desc               => product.description, 
        #:price_vat          => num_to_s(product.price.round(2)), 
        :quantity           => order.line_items[0].quantity,
        :unit               => "kpl",
        :deliverydate       => "#{date.day}.#{date.month}.#{date.year}",
        :price_net          => num_to_s(product.price.round(2)),
        :vat                => num_to_s(product.tax_category.tax_rates[0].amount*100),
        :discountpercentage => "0,00",
        :type => "1"
      }
    end

    products[products.length] = add_shipping(order)

    return products
  end

  def get_sellercosts(order)
    #return "0,00"
    return num_to_s(order.ship_total.round(2))
  end

  def get_hash(order)
    hashprimer = ""
    hashprimer = hashprimer + self.preferences["pmt_action"] + "&" unless self.preferences["pmt_action"].nil?
    hashprimer = hashprimer + self.preferences["pmt_version"] + "&" unless self.preferences["pmt_version"].nil?
    hashprimer = hashprimer + self.preferences["pmt_selleriban"] + "&" unless self.preferences["pmt_selleriban"].nil?
    hashprimer = hashprimer + self.preferences["pmt_id"] + "&" unless self.preferences["pmt_id"].nil?
    
    hashprimer = hashprimer + get_orderid(order) + "&" unless get_orderid(order).nil?
    
    hashprimer = hashprimer + self.preferences["pmt_reference"] + "&" unless self.preferences["pmt_reference"].nil?
    hashprimer = hashprimer + self.preferences["pmt_duedate"] + "&" unless self.preferences["pmt_duedate"].nil?
    
    hashprimer = hashprimer + get_amount(order) + "&" unless get_amount(order).nil?
    

    hashprimer = hashprimer + self.preferences["pmt_currency"] + "&" unless self.preferences["pmt_currency"].nil?
    hashprimer = hashprimer + self.preferences["pmt_okreturn"] + "&" unless self.preferences["pmt_okreturn"].nil?
    hashprimer = hashprimer + self.preferences["pmt_errorreturn"] + "&" unless self.preferences["pmt_errorreturn"].nil?
    hashprimer = hashprimer + self.preferences["pmt_cancelreturn"] + "&" unless self.preferences["pmt_cancelreturn"].nil?
    hashprimer = hashprimer + self.preferences["pmt_delayedpayreturn"] + "&" unless self.preferences["pmt_delayedpayreturn"].nil?
    hashprimer = hashprimer + self.preferences["pmt_escrow"] + "&" unless self.preferences["pmt_escrow"].nil?
    hashprimer = hashprimer + self.preferences["pmt_escrowchangeallowed"] + "&" unless self.preferences["pmt_escrowchangeallowed"].nil?
    
    hashprimer = hashprimer + get_buyername(order) + "&" unless get_buyername(order).nil?
    # hashprimer = hashprimer + params[k]+"&" if k=="pmt_paymentmethod"
    # hashprimer = hashprimer + params[k]+"&" if k=="pmt_buyeridentificationcode"
    hashprimer = hashprimer + get_buyeraddress(order) + "&" unless get_buyeraddress(order).nil?
    hashprimer = hashprimer + get_buyerpostalcode(order) + "&" unless get_buyerpostalcode(order).nil?
    hashprimer = hashprimer + get_buyercity(order) + "&" unless get_buyercity(order).nil?
    hashprimer = hashprimer + get_buyercountry(order) + "&" unless get_buyercountry(order).nil?


    hashprimer = hashprimer + get_deliveryname(order) + "&" unless get_deliveryname(order).nil?
    # hashprimer = hashprimer + params[k]+"&" if k=="pmt_paymentmethod"
    # hashprimer = hashprimer + params[k]+"&" if k=="pmt_deliveryidentificationcode"
    hashprimer = hashprimer + get_deliveryaddress(order) + "&" unless get_deliveryaddress(order).nil?
    hashprimer = hashprimer + get_deliverypostalcode(order) + "&" unless get_deliverypostalcode(order).nil?
    hashprimer = hashprimer + get_deliverycity(order) + "&" unless get_deliverycity(order).nil?
    hashprimer = hashprimer + get_deliverycountry(order) + "&" unless get_deliverycountry(order).nil?
    
    hashprimer = hashprimer + get_sellercosts(order) + "&" unless get_sellercosts(order).nil?
    

    get_products(order).each do |n|
      hashprimer = hashprimer + n[:name] + "&"
      hashprimer = hashprimer + n[:desc] + "&"
      # hashprimer = hashprimer + n[:price_vat] + "&"
      hashprimer = hashprimer + n[:quantity].to_s + "&"
      hashprimer = hashprimer + n[:unit] + "&"
      hashprimer = hashprimer + n[:deliverydate] + "&"
      hashprimer = hashprimer + n[:price_net].to_s + "&"
      hashprimer = hashprimer + n[:vat].to_s + "&"
      hashprimer = hashprimer + n[:discountpercentage].to_s + "&"
      hashprimer = hashprimer + n[:type].to_s + "&"
    end

    hashprimer = hashprimer + "11223344556677889900&"

    #return hashprimer
    return Digest::SHA1.hexdigest hashprimer
  end
end

