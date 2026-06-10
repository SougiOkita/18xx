# frozen_string_literal: true

require_relative '../../../round/auction'

module Engine
  module Game
    module G1881
      module Round
        class Auction < Engine::Round::Auction
          def name
            'Initial Auction Round'
          end

          def self.short_name
            'IAR'
          end
        end
      end
    end
  end
end
