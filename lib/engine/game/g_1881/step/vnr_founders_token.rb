# frozen_string_literal: true

require_relative '../../../step/base'
require_relative '../../../step/tokener'

module Engine
  module Game
    module G1881
      module Step
        # Second half of the VNR founder's ability (see VnrFoundersTile):
        # once the founding tile has been laid, its president places a VNR
        # token on the new city -- again with no connectivity requirement --
        # paying the token's normal price out of VNR's treasury. Completing
        # this is what finally marks the whole ability used.
        class VnrFoundersToken < Engine::Step::Base
          include Engine::Step::Tokener

          ACTIONS = %w[place_token pass].freeze

          def actions(entity)
            return [] unless eligible?(entity)

            ACTIONS
          end

          def description
            "#{@game.vnr.name} Founding Token"
          end

          def pass_description
            'Skip (Founding Token)'
          end

          def blocks?
            false
          end

          def eligible?(entity)
            v = @game.vnr
            entity == v && entity == current_entity && @game.vnr_founders_token_pending? && v.owner&.player?
          end

          def available_hex(_entity, hex)
            hex == @game.vnr_founders_tile_laid_hex
          end

          def process_place_token(action)
            v = @game.vnr
            hex = @game.vnr_founders_tile_laid_hex
            raise GameError, "#{action.city.hex.name} is not #{v.name}'s founding hex" if action.city.hex != hex

            place_token(v, action.city, v.next_token, connected: false, extra_action: true, spender: v)
            @game.vnr_founders_ability_used!
            @log << "#{v.name} places its founding token on #{hex.name} (#{hex.location_name})"
            pass!
          end
        end
      end
    end
  end
end
