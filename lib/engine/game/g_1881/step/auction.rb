# frozen_string_literal: true

require_relative '../../../step/base'
require_relative '../../../step/auctioner'

module Engine
  module Game
    module G1881
      module Step
        class Auction < Engine::Step::Base
          include Engine::Step::Auctioner

          CONCESSION_ACTIONS = %w[bid pass].freeze
          OFFER_ACTIONS = %w[offer].freeze
          BID_ACTIONS = %w[bid pass].freeze

          attr_reader :companies, :auctioning

          def description
            @sub_phase == :concessions ? 'Concession Auction' : 'Auction off Privates'
          end

          def finished?
            @sub_phase == :privates && @companies.empty?
          end

          def setup
            setup_auction
            @sub_phase = :concessions
            @companies = []

            @concession_queue = build_concession_queue
            @log << "Concession order: #{@concession_queue.map(&:name).join(' → ')}"
            start_next_concession!
          end

          def available
            @auctioning ? [@auctioning] : current_entity.unsold_companies
          end

          def active_auction
            company = @auctioning
            bids = @bids[company]
            yield company, bids if company && bids&.any?
          end

          def show_map
            true
          end

          def show_companies
            true
          end

          def actions(entity)
            return [] if finished?

            if @sub_phase == :concessions
              entity == current_entity ? CONCESSION_ACTIONS : []
            elsif @auctioning
              entity == current_entity ? BID_ACTIONS : []
            else
              entity == current_entity ? OFFER_ACTIONS : []
            end
          end

          def may_purchase?(_company)
            false
          end

          def may_offer?(company)
            @sub_phase == :privates && !@auctioning &&
              current_entity.unsold_companies.include?(company)
          end

          def min_bid(company)
            return unless company

            return company.value + min_increment if @bids[company].empty?

            highest_bid(company).price + min_increment
          end

          def max_bid(player, _company)
            player.cash
          end

          def committed_cash(_player, _show_hidden)
            0
          end

          def starting_bid(company)
            company.value + min_increment
          end

          def round_state
            { companies_pending_par: [] }
          end

          # ---------------------------------------------------------------
          # Action dispatch
          # ---------------------------------------------------------------

          def process_bid(action)
            @sub_phase == :concessions ? process_concession_bid(action) : process_private_bid(action)
          end

          def process_pass(action)
            @sub_phase == :concessions ? process_concession_pass(action) : process_private_pass(action)
          end

          def process_offer(action)
            player = action.entity
            company = action.company

            @auctioneer = player
            @player1 = entities[(entity_index + 1) % entities.size]
            @player2 = entities[(entity_index + 2) % entities.size]
            @receiver = entities.size == 4 ? entities[(entity_index + 3) % entities.size] : nil
            @auctioning = company

            @player1.unpass!
            @player2.unpass!

            @log << "#{player.name} offers #{company.name} for auction"
            goto_entity!(@player1)
            auto_pass_if_forced!
          end

          # ---------------------------------------------------------------
          # Concession phase
          # ---------------------------------------------------------------

          private

          def company(id)
            @game.companies.find { |c| c.id == id }
          end

          def build_concession_queue
            if @game.players.size == 3
              central_id = %w[CFCA-C RCL-C].sort_by { @game.rand }.first
              central = company(central_id)
              @log << "Central concession in play: #{central.name}"
              [company('CFI-C'), central, company('STC-C')].sort_by { @game.rand }
            else
              [company('CFI-C'), company('CFCA-C'), company('RCL-C'), company('STC-C')].sort_by { @game.rand }
            end
          end

          def start_next_concession!(first_bidder = nil)
            @auctioning = @concession_queue.shift
            entities.each(&:unpass!)
            @log << "--- Concession auction: #{@auctioning.name} ---"
            starter = first_bidder || entities.first
            goto_entity!(starter)
          end

          def process_concession_bid(action)
            player = action.entity
            price = action.price

            # Always bid on the current concession regardless of what company the UI sent
            corrected = Engine::Action::Bid.new(player, company: @auctioning, price: price)
            player.unpass!
            add_bid(corrected)
            @log << "#{player.name} bids #{@game.format_currency(price)} for #{@auctioning.name}"

            advance_concession_entity!
          end

          def process_concession_pass(action)
            player = action.entity
            @log << "#{player.name} passes on #{@auctioning.name}"
            player.pass!

            active = entities.reject(&:passed?)

            if active.empty?
              # Everyone passed — resolve by bids or force highest cash
              if @bids[@auctioning].empty?
                force_concession!
              else
                resolve_concession!(highest_bid(@auctioning))
              end
            elsif active.size == 1 && !@bids[@auctioning].empty?
              # One player left and bids exist — they win at their bid
              resolve_concession!(highest_bid(@auctioning))
            else
              # Still multiple active players, or sole player hasn't bid yet — keep going
              advance_concession_entity!
            end
          end

          def advance_concession_entity!
            loop do
              @round.next_entity_index!
              break unless current_entity.passed?
            end
          end

          def resolve_concession!(bid)
            winner = bid.entity
            price = bid.price
            company = @auctioning

            company.owner = winner
            winner.companies << company
            winner.spend(price, @game.bank)
            @bids.delete(company)

            @log << "#{winner.name} wins #{company.name} for #{@game.format_currency(price)}"
            @game.after_buy_company(winner, company, price)

            after_concession!(winner)
          end

          def force_concession!
            force_concession_to!(entities.max_by(&:cash))
          end

          def force_concession_to!(player)
            company = @auctioning
            price = company.value
            company.owner = player
            player.companies << company
            player.spend(price, @game.bank)
            @bids.delete(company)

            @log << "#{player.name} is forced to buy #{company.name} for #{@game.format_currency(price)}"
            @game.after_buy_company(player, company, price)

            after_concession!(player)
          end

          def after_concession!(winner)
            entities.each(&:unpass!)

            if @concession_queue.empty?
              distribute_privates!
              @sub_phase = :privates
              @auctioning = nil
              @log << "--- Private auction begins ---"
              goto_entity!(entities.first)
              auto_offer_if_sole!
            else
              # Next concession starts with the player seated after the winner
              next_starter = entities[(entities.index(winner) + 1) % entities.size]
              start_next_concession!(next_starter)
            end
          end

          # ---------------------------------------------------------------
          # Private distribution
          # ---------------------------------------------------------------

          def distribute_privates!
            num_players = @game.players.size
            n_pool = privates_for_group('N', num_players).sort_by { @game.rand }
            s_pool = privates_for_group('S', num_players).sort_by { @game.rand }
            c_pool = privates_for_group('C', num_players).sort_by { @game.rand }

            if num_players == 3
              north_winner = company('CFI-C').owner
              south_winner = company('STC-C').owner
              central_concession = %w[CFCA-C RCL-C].map { |id| company(id) }.find(&:owned_by_player?)
              central_winner = central_concession.owner

              assign_pile(north_winner,   n_pool.shift(2) + [s_pool.shift, c_pool.shift])
              assign_pile(south_winner,   s_pool.shift(2) + [n_pool.shift, c_pool.shift])
              assign_pile(central_winner, c_pool.shift(2) + [n_pool.shift, s_pool.shift])

              # C1/C2 both map to the single floated central corp; C3 reserved share same corp
              central_sym = central_concession.id.delete_suffix('-C')
              @game.setup_central_share_data(
                share_assignments: { 'C1' => central_sym, 'C2' => central_sym },
                c3_reserved_corp: central_sym
              )
            else
              # 4p: identify the two central winners
              central_winners = %w[CFCA-C RCL-C].map { |id| company(id).owner }

              @game.players.each do |player|
                pile = [n_pool.shift, s_pool.shift, c_pool.shift].compact
                pile << c_pool.shift if central_winners.include?(player)
                assign_pile(player, pile.compact)
              end

              # 4p: randomly split C1/C2/C1+/C2+ — two give CFCA shares, two give RCL shares
              share_privates = %w[C1 C2 C1+ C2+].sort_by { @game.rand }
              share_assignments = {}
              share_privates[0..1].each { |id| share_assignments[id] = 'CFCA' }
              share_privates[2..3].each { |id| share_assignments[id] = 'RCL' }
              c3_corp = %w[CFCA RCL].sort_by { @game.rand }.first
              @game.setup_central_share_data(
                share_assignments: share_assignments,
                c3_reserved_corp: c3_corp
              )
            end
          end

          def privates_for_group(prefix, num_players)
            @game.companies.select do |c|
              next false unless c.id.start_with?(prefix)
              next false if c.id.end_with?('-C')  # skip concession companies

              # Only 4p-labeled privates are excluded from smaller games.
              # 3p-labeled privates are included in all player counts.
              if prefix == 'C'
                c.name.include?('(4p)') ? num_players == 4 : true
              else
                next false if c.name.include?('(4p)') && num_players != 4

                true
              end
            end
          end

          def assign_pile(player, privates)
            privates = privates.compact
            privates.each { |c| player.unsold_companies << c }
            @companies.concat(privates)
            @log << "#{player.name}'s private pile: #{privates.map(&:name).join(', ')}"
          end

          # ---------------------------------------------------------------
          # Private auction phase (1871-style offer/bid)
          # ---------------------------------------------------------------

          def process_private_bid(action)
            add_bid(action)
            entity = action.entity
            price = action.price

            @log << "#{entity.name} bids #{@game.format_currency(price)} for #{action.company.name}"
            next_private_bidder!
          end

          def process_private_pass(action)
            player = action.entity
            @log << "#{player.name} passes on #{@auctioning.name}"
            player.pass!

            unless @bids[@auctioning].empty?
              win_private!(highest_bid(@auctioning))
              return
            end

            if @player1.passed? && @player2.passed?
              force_private!(@auctioning)
              return
            end

            next_private_bidder!
          end

          def win_private!(bid)
            winner = bid.entity
            company = bid.company
            price = bid.price

            assign_private!(winner, company, @auctioneer, price)
            @log << "#{winner.name} wins #{company.name} for #{@game.format_currency(price)}"
            end_private_auction!
          end

          def force_private!(company)
            if @receiver&.cash.to_i >= company.value
              value = company.value
              assign_private!(@receiver, company, @auctioneer, value)
              @log << "#{@receiver.name} is forced to buy #{company.name} for #{@game.format_currency(value)}"
            else
              force_on_highest_cash!(company)
            end
            end_private_auction!
          end

          def force_on_highest_cash!(company)
            while (highest = entities.max_by(&:cash)).cash < company.value
              @log << "No player can afford #{company.name}, paying out revenues"
              @game.payout_companies
            end
            assign_private!(highest, company, @auctioneer, company.value)
            @log << "#{highest.name} is forced to buy #{company.name} for #{@game.format_currency(company.value)}"
          end

          def assign_private!(player, company, auctioneer, price)
            company.owner = player
            player.companies << company
            player.spend(price || company.value, @game.bank)

            auctioneer.unsold_companies.delete(company)
            @companies.delete(company)
            @bids.delete(company)

            @game.after_buy_company(player, company, price)
          end

          def end_private_auction!
            next_player = @player1
            goto_entity!(@player1)

            @player1.unpass!
            @player2&.unpass!
            @auctioneer = @auctioning = @player1 = @player2 = @receiver = nil

            auto_offer_if_sole!(next_player)
          end

          def next_private_bidder!
            if entity_index == entities.index(@player1)
              goto_entity!(@player2)
            else
              goto_entity!(@player1)
            end
            auto_pass_if_forced!
          end

          def auto_pass_if_forced!
            return unless @auctioning

            player = current_entity
            min_cash = min_bid(@auctioning)
            return if player.cash >= min_cash

            @log << "#{player.name} cannot afford #{@game.format_currency(min_cash)} — auto-pass"
            @round.process_action(Engine::Action::Pass.new(player))
          end

          def auto_offer_if_sole!(player = current_entity)
            return unless player.unsold_companies.size == 1

            @round.process_action(
              Engine::Action::Offer.new(player, company: player.unsold_companies.first)
            )
          end

          def goto_entity!(entity)
            @round.goto_entity!(entity)
          end
        end
      end
    end
  end
end
