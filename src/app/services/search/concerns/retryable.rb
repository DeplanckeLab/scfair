# frozen_string_literal: true

module Search
  module Concerns
    module Retryable
      private

        def with_retries(max: 3, base_delay: 0.5)
          attempts = 0
          begin
            attempts += 1
            yield
          rescue StandardError
            raise if attempts >= max

            sleep(base_delay * (2 ** (attempts - 1)))
            retry
          end
        end
    end
  end
end
