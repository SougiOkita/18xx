# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G1881
      module Step
        # Automatic, placed after Dividend: deducts 10 per outstanding Doumer
        # fund loan from the operating corporation, falling back to its
        # president if the treasury falls short. See Game#collect_doumer_interest!.
        class PayInterest < Engine::Step::Base
          def actions(_entity)
            []
          end

          def skip!
            pass!
            entity = current_entity
            @game.collect_doumer_interest!(entity) if entity&.corporation?
          end
        end
      end
    end
  end
end
