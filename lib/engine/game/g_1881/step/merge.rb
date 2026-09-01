# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G1881
      module Step
        # Available in phases '2' and '3': two connected corporations can merge.
        # The current entity (Corp A) absorbs Corp B:
        #   - B's cash and trains transfer to A
        #   - B's shareholders receive B's share price in cash from the bank (buyout)
        #   - B's tokens are removed; B closes
        #   - A's share price moves right (up) to reflect the larger entity
        class Merge < Engine::Step::Base
          def actions(entity)
            return [] unless merge_phase?
            return [] unless entity.corporation? && entity == current_entity
            return [] if candidates(entity).empty?

            %w[merge pass]
          end

          def description
            'Merge'
          end

          def pass_description
            'Skip (Merge)'
          end

          def blocks?
            false
          end

          def merge_phase?
            %w[2 3].include?(@game.phase.name)
          end

          def candidates(entity)
            return [] unless entity.floated?
            # Minors may only be merged INTO a major -- they can never survive a
            # merge themselves, so a minor is never offered any merge candidates.
            return [] if @game.minor_corp?(entity)

            @game.corporations.select do |corp|
              next false if corp == entity
              next false unless corp.floated?
              next false if corp.closed?

              connected?(entity, corp)
            end
          end

          def process_merge(action)
            survivor = action.entity
            absorbed = action.corporation

            raise GameError, "#{absorbed.name} is not a valid merge target" unless candidates(survivor).include?(absorbed)

            @log << "#{survivor.name} merges with #{absorbed.name}"

            # Transfer cash
            if absorbed.cash.positive?
              @log << "#{absorbed.name} transfers #{@game.format_currency(absorbed.cash)} to #{survivor.name}"
              absorbed.spend(absorbed.cash, survivor)
            end

            # Transfer trains
            unless absorbed.trains.empty?
              @log << "#{absorbed.name} transfers #{absorbed.trains.size} train(s) to #{survivor.name}"
              absorbed.trains.each { |t| t.owner = survivor }
              survivor.trains.concat(absorbed.trains)
              absorbed.trains.clear
            end

            # Buy out absorbed corp's shareholders at current share price
            price_per_share = absorbed.share_price.price
            absorbed.player_share_holders.each do |player, percent|
              num_shares = percent / absorbed.share_percent
              payout = num_shares * price_per_share
              next unless payout.positive?

              @game.bank.spend(payout, player)
              @log << "#{player.name} receives #{@game.format_currency(payout)} for #{num_shares} share(s) of #{absorbed.name}"
            end

            # Move survivor's share price right (one step) to reflect the combined entity
            old_price = survivor.share_price
            @game.stock_market.move_right(survivor)
            @game.log_share_price(survivor, old_price)

            # Remove absorbed corp's tokens and close it
            @game.close_corporation(absorbed)
            @log << "#{absorbed.name} closes"
          end

          private

          def connected?(entity, other)
            graph = @game.graph
            graph.connected_nodes(entity).keys.any? do |node|
              node.city? && node.tokens.any? { |t| t&.corporation == other }
            end
          rescue StandardError
            false
          end
        end
      end
    end
  end
end
