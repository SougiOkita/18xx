# frozen_string_literal: true

require_relative '../../../step/dividend'

module Engine
  module Game
    module G1881
      module Step
        class Dividend < Engine::Step::Dividend
          # 1881 share price movement rules:
          #   revenue >= 2× stock price  → right 2
          #   revenue >= 1× stock price  → right 1
          #   0 < revenue < stock price  → no movement (stay)
          #   revenue == 0 (withhold)    → left 1
          def share_price_change(entity, revenue)
            price = entity.share_price&.price || 0
            if revenue >= 2 * price
              { share_direction: :right, share_times: 2 }
            elsif revenue >= price
              { share_direction: :right, share_times: 1 }
            elsif revenue.positive?
              {}
            else
              { share_direction: :left, share_times: 1 }
            end
          end
        end
      end
    end
  end
end
