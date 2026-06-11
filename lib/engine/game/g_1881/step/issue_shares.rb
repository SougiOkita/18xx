# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G1881
      module Step
        # Placed at the END of the OR (after buy train): corporation may sell
        # one or more IPO shares to the market (issue), moving the share price left.
        class IssueShares < Engine::Step::Base
          def actions(entity)
            return [] unless entity.corporation? && entity == current_entity
            return [] if issuable_shares(entity).empty?

            %w[sell_shares pass]
          end

          def description
            'Issue Shares'
          end

          def pass_description
            'Skip (Issue)'
          end

          def blocks?
            false
          end

          def process_sell_shares(action)
            @game.sell_shares_and_change_price(action.bundle)
            pass!
          end

          def issuable_shares(entity)
            @game.issuable_shares(entity)
          end

          def visible_corporations
            []
          end
        end
      end
    end
  end
end
