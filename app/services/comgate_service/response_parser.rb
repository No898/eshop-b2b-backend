# frozen_string_literal: true

class ComgateService
  module ResponseParser
    private

    def parse_payment_response(response)
      raise ApiError, response['message'] || 'Unknown payment error' unless response['code'].zero?

      {
        success: true,
        payment_id: response['transId'],
        payment_url: response['redirect']
      }
    end

    def parse_verification_response(response)
      if response['code'].zero?
        {
          success: true,
          status: response['status'],
          message: response['message'],
          test: response['test'],
          price: response['price'],
          currency: response['curr']
        }
      else
        {
          success: false,
          error: response['message'] || 'Payment verification failed'
        }
      end
    end
  end
end
