# frozen_string_literal: true

require_relative '../../../step/base'
require_relative '../../../step/tracker'

module Engine
  module Game
    module G1881
      module Step
        # One-time ability unlocked the moment VNR floats (see
        # Game#float_corporation, which sets @vnr_founders_pending): its
        # sitting president may upgrade ANY hex on the map to a tile with a
        # city -- normal color progression still applies, but connectivity to
        # VNR's own network does not -- paying the tile's full upgrade cost
        # out of VNR's own treasury (see Game#upgrade_cost). Placing the
        # founding token on the new city is a separate step
        # (VnrFoundersToken) that follows once this succeeds. If nobody holds
        # VNR's presidency yet, this step offers no action at all -- the
        # ability simply stays reserved until someone does.
        class VnrFoundersTile < Engine::Step::Base
          include Engine::Step::Tracker

          ACTIONS = %w[lay_tile pass].freeze

          def actions(entity)
            return [] unless eligible?(entity)

            ACTIONS
          end

          def description
            "#{@game.vnr.name} Founding Tile"
          end

          def pass_description
            'Skip (Founding Tile)'
          end

          def blocks?
            false
          end

          def eligible?(entity)
            v = @game.vnr
            entity == v && entity == current_entity && @game.vnr_founders_tile_pending? && v.owner&.player?
          end

          # Every hex is a legal target -- the whole point of the ability.
          def available_hex(_entity, _hex)
            true
          end

          # Same geometry/city-mapping checks as Tracker#legal_tile_rotation?,
          # minus its "the entity must already be graph-connected to one of
          # this rotation's exits" requirement -- that's the one restriction
          # this ability is explicitly meant to ignore.
          def legal_tile_rotation?(entity_or_entities, hex, tile)
            entities = Array(entity_or_entities)
            entity, = entities

            return false unless @game.legal_tile_rotation?(entity, hex, tile)
            return false unless tile.exits.all? { |edge| hex_neighbor_exists?(entity, hex, edge) }
            return false unless old_paths_maintained?(hex, tile)

            old_ctedges = hex.tile.city_town_edges
            new_ctedges = tile.city_town_edges
            added_cities = [0, new_ctedges.size - old_ctedges.size].max
            multi_city_upgrade = tile.cities.size > 1 && hex.tile.cities.size > 1

            valid_added_city_count =
              added_cities >= new_ctedges.count { |newct| old_ctedges.all? { |oldct| (newct & oldct).none? } }
            return false unless valid_added_city_count

            old_cities_map_to_new =
              !multi_city_upgrade ||
              old_ctedges.all? { |oldct| new_ctedges.one? { |newct| (oldct & newct) == oldct } }
            return false unless old_cities_map_to_new

            city_sizes_maintained(hex, tile)
          end

          def process_lay_tile(action)
            v = @game.vnr
            hex = action.hex
            tile = action.tile

            raise GameError, "#{tile.name} has no city -- the founding tile must have one" if tile.cities.empty?

            lay_tile(action, extra_cost: 0, entity: v, spender: v)
            @game.vnr_founders_tile_laid!(hex)
            @log << "#{v.name}'s president lays its founding tile at #{hex.name} (#{hex.location_name})"
            pass!
          end
        end
      end
    end
  end
end
