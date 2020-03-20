require 'net/http'

module Integrations::Shopify::CustomActions
  module Auth

    def auth_connect
      if params[:shop_name].blank?
        render :template => "auth"
      else
        @state[:shop] = "#{params[:shop_name]}.myshopify.com"
        p account = Account.find(session[:integration_session][:id])
        account.is_connected = true
        account.save()
        p callback_url = integration_custom_action_url('auth_success_callback')

        api_key = Rails.application.config_for('integrations/shopify')['api_key']

        redirect_url = "https://#{@state[:shop]}/admin/oauth/authorize?client_id=#{api_key}&scope=write_products,write_orders,read_customers&redirect_uri=#{callback_url}"

        render status: 200, json: { url: redirect_url}
      end
    end

    def auth_success_callback
      uri = URI.parse("https://#{@state[:shop]}/admin/oauth/access_token")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'application/json'})
      request.body = {
        client_id: Rails.application.config_for('integrations/shopify')['api_key'],
        client_secret: Rails.application.config_for('integrations/shopify')['secret'],
        code: params[:code]
      }.to_json
      response = http.request(request)

      p params[:shop] = @state[:shop]
      @state[:access_token] = JSON.parse(response.body)["access_token"]
      shopify_session = ShopifyAPI::Session.new(@state[:shop], @state[:access_token])

      ShopifyAPI::Base.activate_session(session)

      scope = %w(write_products write_orders)
      p permission_url = shopify_session.create_permission_url(scope)
      # p @state[:access_token] = shopify_session.request_token(params)
      flash[:notice] = 'Shopify account connected successfully'
      if Rails.env.development?
        redirect_to "http://localhost:8080/#/order-management/connected-accounts"
      else
        redirect_to Rails.application.routes.url_helpers.root_url + "/#/order-management/connected-accounts"
      end
    rescue
      flash[:alert] = 'There was an error connecting your Shopify account'
      if Rails.env.development?
        redirect_to "http://localhost:8080/#/order-management/connected-accounts"
      else
        redirect_to Rails.application.routes.url_helpers.root_url + "/#/order-management/connected-accounts"
      end
    end
  end
end
