# frozen_string_literal: true

require_relative '../../../step/base'
require_relative '../../../step/share_buying'

module Engine
  module Game
    module G1881
      module Step
        # C3, N3, N4, and S4 each reserve one IPO share in their associated
        # concession corp (Game#reserve_one_ipo_share). The player holding one
        # of these privates may redeem it, at any point during a Stock Round
        # (not just on the turn they act), for that reserved share -- this
        # closes the private and hands the player the share for free. Mirrors
        # Engine::Step::Exchange (already used elsewhere in this game), but
        # against Game's own ad-hoc reservation bookkeeping instead of the
        # generic Ability::Exchange system, since which concession corp each
        # private reserves against isn't known until the auction resolves.
        class RedeemPrivateShare < Engine::Step::Base
          include Engine::Step::ShareBuying

          ACTIONS = %w[buy_shares].freeze

          def actions(entity)
            return [] unless redeemable?(entity)

            ACTIONS
          end

          def description
            'Redeem Reserved Share'
          end

          def blocks?
            false
          end

          def redeemable?(company)
            return false unless company.company?
            return false unless (share = @game.reserved_share_for(company.id))

            can_gain?(company.owner, share.to_bundle, exchange: true)
          end

          def can_buy?(entity, bundle)
            can_gain?(entity, bundle, exchange: true)
          end

          def process_buy_shares(action)
            company = action.entity
            share = @game.reserved_share_for(company.id)
            raise GameError, "#{company.name} has no reserved share left to redeem" unless share

            buy_shares(company.owner, action.bundle, exchange: company)
            @game.clear_reserved_share!(company.id)
            @log << "#{company.owner.name} redeems #{company.name} for one share of #{share.corporation.name}"
            company.close!
          end
        end
      end
    end
  end
end
