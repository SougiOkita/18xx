# frozen_string_literal: true

require_relative '../../../step/assign'

module Engine
  module Game
    module G1881
      module Step
        # N3: discarding it to use its one-time assign_hexes ability (see
        # entities.rb) also tags the acting corporation onto the chosen port
        # hex, via Game#assign_bonus_hex!, so revenue_for can grant that
        # corporation (and only that corporation) a permanent +₫30 bonus there.
        class Assign < Engine::Step::Assign
          def process_assign(action)
            company = action.entity
            corp = company.owner

            super

            maybe_assign_bonus_hex(company, corp, action.target)
          end

          def maybe_assign_bonus_hex(company, corp, target)
            return if company.id != 'N3' || !target.is_a?(Engine::Hex)

            @game.assign_bonus_hex!(corp, target)
          end
        end
      end
    end
  end
end
