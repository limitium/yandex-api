require 'net/http'
require 'net/https'
require 'json'
require 'yaml'
require 'uri'

module Yandex
  module API
    module Direct
      URL_API = "https://api.direct.yandex.ru/live/v4/json/"

      def self.configuration
        if defined? @enviroment
          raise RuntimeError.new("not configured Yandex.Direct for #{@enviroment} enviroment") unless @configuration
        else
          raise RuntimeError.new("not configured Yandex.Direct") unless @configuration
        end
        @configuration
      end

      def self.parse_json json
        begin
          return JSON.parse(json)
        rescue => e
          raise RuntimeError.new "#{e.message} in response"
        end
      end

      def self.load file, env = nil
        @enviroment = env if env
        config = YAML.load_file(file)
        @configuration = defined?(@enviroment) ? config[@enviroment] : config
      end

      def self.request method, params = {}, direct_params = {}

        body = {
            :locale => configuration["locale"],
            :login => configuration["login"],
            :application_id => configuration["application_id"],
            :token => configuration["token"],
            :method => method
        }

        body.merge!(direct_params) unless direct_params.empty?
        body.merge!({:param => params}) unless params.empty?

        url = URI.parse(URL_API)

        if configuration["verbose"]
          puts "\t\033[32mURL: \033[0m#{URL_API}"
          puts "\t\033[32mMethod: \033[0m#{method}"
          puts "\t\033[32mParams: \033[0m#{params.inspect}"
          puts "\t\033[32mDirect params: \033[0m#{direct_params.inspect}"
        end

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        puts JSON.generate(body)
        response = http.post(url.path, JSON.generate(body))

        raise Yandex::API::RuntimeError.new("#{response.code} - #{response.message}") unless response.code.to_i == 200

        json = Direct.parse_json(response.body)

        if json.has_key?("error_code") and json.has_key?("error_str")
          code = json["error_code"].to_i
          error = json["error_detail"].length > 0 ? json["error_detail"] : json["error_str"]
          raise RuntimeError.new "#{code} - #{error}"
        end

        return json["data"]
      end

      def self.finance_request method, operation_num, params = {}
        request(method, params, {
            :finance_token => Digest::SHA256.hexdigest(configuration["master_token"] + operation_num.to_s + method + configuration["login"]),
            :operation_num => operation_num
        })
      end

      def self.transfer_money from_compaign_id, to_compaign_id, sum, operation_num, currency = "RUB"
        finance_request("TransferMoney", operation_num, {
            :FromCampaigns => [
                {
                    :CampaignID => from_compaign_id,
                    :Sum => sum,
                    :Currency => currency
                }
            ],
            :ToCampaigns => [
                {
                    :CampaignID => to_compaign_id,
                    :Sum => sum,
                    :Currency => currency
                }
            ]
        })
      end
    end
  end
end
