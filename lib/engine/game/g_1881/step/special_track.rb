# frozen_string_literal: true

require_relative '../../../step/special_track'

module Engine
  module Game
    module G1881
      module Step
        # C3 and N4 both grant a free one-time tile_lay ability (see
        # entities.rb). C3's (fixed to K18) is a plain free upgrade with no
        # further effect. N4's (any reachable city/town) also tags the
        # improved hex with the acting corporation via Game#assign_bonus_hex!,
        # so revenue_for can grant that corporation a permanent +₫30 bonus there.
        class SpecialTrack < Engine::Step::SpecialTrack
          def process_lay_tile(action)
            company = action.entity
            corp = company.owner if company.is_a?(Engine::Company)

            super

            maybe_assign_bonus_hex(company, corp, action.hex)
          end

          def maybe_assign_bonus_hex(company, corp, hex)
            return if !corp || company.id != 'N4'

            @game.assign_bonus_hex!(corp, hex)
          end
        end
      end
    end
  end
end
