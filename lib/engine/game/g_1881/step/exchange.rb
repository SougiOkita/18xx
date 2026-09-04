# frozen_string_literal: true

require_relative '../../../step/exchange'

module Engine
  module Game
    module G1881
      module Step
        # C3/N3/N4/S4: redeeming the reserved share does NOT close the private
        # (unlike the base Engine::Step::Exchange) -- the owner keeps it and may
        # still sell it to a corporation afterward. See Game#redeem_reserved_private!
        # for the bookkeeping that instead drops its income to zero and retires
        # the exchange ability so it can't be redeemed a second time.
        class Exchange < Engine::Step::Exchange
          def process_buy_shares(action)
            company = action.entity
            bundle = action.bundle
            unless can_exchange?(company, bundle)
              raise GameError, "Cannot exchange #{action.entity.id} for #{bundle.corporation.id}"
            end

            buy_shares(company.owner, bundle, exchange: company)
            @round.players_history[company.owner][bundle.corporation] << action if @round.respond_to?(:players_history)
            @game.redeem_reserved_private!(company)
          end
        end
      end
    end
  end
end
