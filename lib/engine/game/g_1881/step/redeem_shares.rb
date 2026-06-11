# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G1881
      module Step
        # Placed at the BEGINNING of the OR: corporation may buy back one share
        # from the market (redeem), moving the share price right.
        class RedeemShares < Engine::Step::Base
          def actions(entity)
            return [] unless entity.corporation? && entity == current_entity
            return [] if redeemable_shares(entity).empty?

            %w[buy_shares pass]
          end

          def description
            'Redeem Shares'
          end

          def pass_description
            'Skip (Redeem)'
          end

          def blocks?
            false
          end

          def process_buy_shares(action)
            @game.share_pool.buy_shares(action.entity, action.bundle)
            pass!
          end

          def redeemable_shares(entity)
            @game.redeemable_shares(entity)
          end

          def visible_corporations
            []
          end
        end
      end
    end
  end
end
