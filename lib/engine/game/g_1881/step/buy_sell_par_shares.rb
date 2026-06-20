# frozen_string_literal: true

require_relative '../../../step/buy_sell_par_shares'
require_relative '../../../action/short'

module Engine
  module Game
    module G1881
      module Step
        class BuySellParShares < Engine::Step::BuySellParShares
          def actions(entity)
            actions = super
            # Add 'short' when the player has normal choices (indicated by 'pass' being present)
            # and hasn't already bought this turn.
            actions << 'short' if actions.include?('pass') && !bought? && can_short_any?(entity)
            actions
          end

          def can_short_any?(entity)
            @game.corporations.any? { |c| can_short?(entity, c) }
          end

          def can_short?(entity, corporation)
            # Only major corps (10-share corps, not SFTC/FMT which have share_percent 25)
            return false unless corporation.total_shares >= 10
            return false unless corporation.floated? && corporation.operated?
            return false if @game.shorts(corporation).size >= corporation.total_shares
            return false if entity.num_shares_of(corporation).positive?
            return false if corporation.share_price&.acquisition? || corporation.share_price&.liquidation?
            return false if @round.players_sold[entity].value?(:short)

            true
          end

          def process_short(action)
            entity = action.entity
            corporation = action.corporation
            raise GameError, "Cannot short #{corporation.name}" unless can_short?(entity, corporation)

            @round.players_sold[entity][corporation] = :short
            @game.short(entity, corporation)
            track_action(action, corporation)
          end

          def process_buy_shares(action)
            entity = action.entity
            bundle = action.bundle
            # If player holds a short in this corp, buying covers it.
            covering = entity.player? && entity.percent_of(bundle.corporation).negative?
            super
            @game.unshort(entity, bundle.shares.first) if covering
          end
        end
      end
    end
  end
end
