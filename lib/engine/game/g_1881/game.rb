# frozen_string_literal: true

require_relative 'entities'
require_relative 'map'
require_relative 'meta'
require_relative 'round/auction'
require_relative 'step/auction'
require_relative 'step/buy_train'
require_relative 'step/dividend'
require_relative 'step/redeem_shares'
require_relative 'step/issue_shares'
require_relative 'step/loan'
require_relative 'step/pay_interest'
require_relative 'step/nationalization'
require_relative 'step/merge'
require_relative '../../loan'
require_relative '../base'

module Engine
  module Game
    module G1881
      class Game < Game::Base
        include_meta(G1881::Meta)
        include Entities
        include Map

        # Vietnamese Dong
        CURRENCY_FORMAT_STR = '₫%s'

        # Unlimited bank (represented as very large number)
        BANK_CASH = 99_999
        TOTAL_STARTING_CASH = 1800


        CERT_LIMIT = { 3 => 20, 4 => 16 }.freeze

        STARTING_CASH = {}.freeze

        CAPITALIZATION = :incremental

        MUST_SELL_IN_BLOCKS = false

        # =====================================================================
        # DOUMER FUND
        # A 10-share corporation representing the French state railway fund. It
        # pars and floats automatically at game start (see setup_doumer_fund) and
        # never operates -- it exists only so players can invest in it, and so it
        # can lend money to operating corporations. See the "DOUMER FUND" section
        # below for the loan/interest mechanics.
        # =====================================================================
        DOUMER_ID = 'DOUMER'
        DOUMER_PAR_PRICE = 100
        DOUMER_STARTING_CASH = 2000
        LOAN_VALUE = 100
        LOAN_INTEREST = 10
        NUM_DOUMER_LOANS = DOUMER_STARTING_CASH / LOAN_VALUE

        # STOCK MARKET
        # Par zones: p=yellow (always); x=green par (155, unlocked by green_par event); z=brown par (247, unlocked by brown_par event)
        # Endgame zone: e=light blue (355, 360, 395, 400, 450)
        MARKET = [
          # Row 0 (highest) – cols 16-18 are light blue endgame zone
          %w[70 76 82 90 100 112 126 142 160 180 200 225 250 275 300 325 360e 400e 450e],
          # Row 1 – 247 = brown par + multiple-buy; cols 17-18 are endgame zone
          %w[65 71 77 85 93 104 116 128 143 160 180 200 220 247zb 260 290 320 355e 395e],
          # Row 2 – 155 = green par + ignore-sale
          %w[59 64 70 76 82 90 100 111 125 140 155xi 170 185 204 230 253],
          # Row 3 – yellow par only (cols 2-7); 110-182 are uncoloured
          %w[54 59 65p 72p 78p 84p 90p 100p 110 121 133 147 162 182 201 222],
          # Row 4
          %w[50 54 60 66 73 80 87 94 102 112 123 136 151 169 190],
          # Row 5 – right edge at 158 (⭡ arrow: moving right wraps up to row 4)
          %w[45 50 56 62 68 75 83 91 100 110 122 134 146 158],
          # Row 6 – right edge at 142 (⭡ arrow: wraps up to row 5)
          %w[40 45 50 55 62 69 77 84 92 100 108 117 128 142],
          # Row 7 – right edge at 99 (⭡ arrow: wraps up to row 6)
          %w[30 34 38 42 47 53 59 66 73 81 90 99],
          # Row 8 (bottom) – close cell at col 0; right edge at 60 (⭡ arrow: wraps up to row 7)
          %w[0c 24 28 31 35 40 44 52 60],
        ].freeze

        STOCKMARKET_COLORS = Base::STOCKMARKET_COLORS.merge(
          par: :yellow,
          par_1: :green,
          par_2: :brown,
        ).freeze

        # Endgame: bankrupt = immediate; stock market (light blue zone) OR first 8+ purchase = one more full OR set
        GAME_END_CHECK = { bankrupt: :immediate, stock_market: :one_more_full_or_set }.freeze

        EVENTS_TEXT = Base::EVENTS_TEXT.merge(
          green_par: ['Green par available', 'Corporations may now par at green price (₫155)'],
          brown_par: ['Brown par available', 'Corporations may now par at brown price (₫247)'],
          diesel_purchased: ['First D train sold', 'End game triggered — complete this OR set then play one more'],
        ).freeze

        # =====================================================================
        # PHASES
        # =====================================================================
        PHASES = [
          {
            name: '+1',
            train_limit: 4,
            tiles: [:yellow],
            operating_rounds: 1,
          },
          {
            name: '2',
            on: '2',
            train_limit: 4,
            tiles: [:yellow],
            operating_rounds: 2,
          },
          {
            name: '3',
            on: '3',
            train_limit: 3,
            tiles: %i[yellow green],
            operating_rounds: 2,
          },
          {
            name: '4',
            on: '4',
            train_limit: 3,
            tiles: %i[yellow green],
            operating_rounds: 2,
          },
          {
            name: '5',
            on: '5',
            train_limit: 3,
            tiles: %i[yellow green brown],
            operating_rounds: 3,
          },
          {
            name: '5+1',
            on: '5+1',
            train_limit: 3,
            tiles: %i[yellow green brown],
            operating_rounds: 3,
          },
          {
            name: '6',
            on: '6',
            train_limit: 3,
            tiles: %i[yellow green brown],
            operating_rounds: 3,
          },
          {
            name: '8+',
            on: '8+',
            train_limit: 2,
            tiles: %i[yellow green brown],
            operating_rounds: 3,
          },
          {
            name: 'D',
            on: 'D',
            train_limit: 2,
            tiles: %i[yellow green brown],
            operating_rounds: 3,
          },
          {
            name: 'R2+1',
            on: 'R2+1',
            train_limit: 2,
            tiles: %i[yellow green brown],
            operating_rounds: 3,
          },
        ].freeze

        # =====================================================================
        # TRAINS
        # Parenthetical prices in JSON (e.g. "120(40)") indicate the trade-in
        # cost when discounting a prior train — stored as discount entries below.
        # =====================================================================
        TRAINS = [
          # Standard trains — 2-trains are the first purchasable trains
          { name: '2', distance: 2, price: 80, rusts_on: '4', num: 12 },

          # 120 base; 40 discount when trading a 2-train (saves 80)
          {
            name: '3',
            distance: 3,
            price: 120,
            discount: { '2' => 80 },
            rusts_on: '5',
            num: 6,
            events: [{ 'type' => 'green_par' }],
          },

          # 300 base; 60 discount when trading a 3-train (saves 60 → pays 240)
          {
            name: '4',
            distance: 4,
            price: 300,
            discount: { '3' => 100 },
            rusts_on: '6',
            num: 4,
          },

          # 450 base; 150 discount when trading a 4-train (pays 300)
          {
            name: '5',
            distance: 5,
            price: 450,
            discount: { '4' => 150 },
            rusts_on: '8+',
            num: 4,
            events: [{ 'type' => 'close_companies' }, { 'type' => 'brown_par' }],
          },

          # 5+1: 5 cities/offboards + 1 free town (E-train style)
          {
            name: '5+1',
            distance: [
              { 'nodes' => %w[city offboard], 'pay' => 5, 'visit' => 5 },
              { 'nodes' => %w[town],          'pay' => 1, 'visit' => 1 },
            ],
            price: 520,
            discount: { '5' => 100 },
            num: 2,
          },

          # 630 base (430 with trade-in)
          {
            name: '6',
            distance: 6,
            price: 630,
            discount: { '5' => 200, '5+1' => 200 },
            num: 3,
          },

          # 8+ ultra train: 8 cities/offboards + all towns free (E-train style). First purchase triggers end game.
          {
            name: '8+',
            distance: [
              { 'nodes' => %w[city offboard], 'pay' => 8,  'visit' => 8  },
              { 'nodes' => %w[town],          'pay' => 99, 'visit' => 99 },
            ],
            price: 900,
            discount: { '5' => 250, '5+1' => 250, '6' => 250 },
            num: 2,
          },
          {
            name: 'D',
            distance: [
              { 'nodes' => %w[city offboard], 'pay' => 99,  'visit' => 99  },
              { 'nodes' => %w[town],          'pay' => 99, 'visit' => 99 },
            ],
            price: 1100,
            discount: {  '6' => 300, '8+' => 600 },
            num: 12,
            events: [{ 'type' => 'diesel_purchased' }],
          },

          # R2+1: Rapid 2+1 regional train (like a 3E/diesel variant)
          {
            name: 'R2+1',
            distance: [{ 'nodes' => %w[city offboard town], 'pay' => 2, 'visit' => 3 }],
            price: 300,
            num: 6,
          },

          # +1 trains are always available. They cannot run alone; while owned by a
          # corporation, they grant one free town stop to each numeric-distance train route.
          {
            name: '+1',
            distance: 1,
            price: 30,
            num: 12,
            available_on: '+1',
          },
        ].freeze

        # =====================================================================
        # ROUTE RULES
        # =====================================================================

        # The four Laos offboard hexes form a single region: when a route visits
        # multiple Laos hexes they count as ONE stop for distance and ONE revenue
        # value (the highest-revenue Laos hex on the route is collected).
        LAOS_HEXES = %w[E14 E16 F17 G18].freeze

        # The Cambodia gate path (red pass-through hexes with no revenue nodes).
        # A route using any of these hexes requires a token in Phnom Penh (C30).
        CAMBODIA_GATE_HEXES = %w[C28 D27 E26 F25].freeze
        PHNOM_PENH_HEX = 'C30'

        # =====================================================================
        # TILE LAY RULES (phase-based)
        # Yellow: 2 yellow lays; Green: 2 yellow OR 1 green upgrade; Brown: 1
        # =====================================================================
        YELLOW_TILE_LAYS = [
          { lay: true, upgrade: false, cost: 0 },
          { lay: true, upgrade: false, cost: 0 },
        ].freeze

        GREEN_TILE_LAYS = [
          { lay: true, upgrade: true, cost: 0 },
          { lay: :not_if_upgraded, upgrade: false, cost: 0 },
        ].freeze

        BROWN_TILE_LAYS = [{ lay: true, upgrade: true, cost: 0 }].freeze

        # =====================================================================
        # TILE LAY RULES
        # =====================================================================
        def tile_lays(_entity)
          if @phase.tiles.include?(:brown)
            self.class::BROWN_TILE_LAYS
          elsif @phase.tiles.include?(:green)
            self.class::GREEN_TILE_LAYS
          else
            self.class::YELLOW_TILE_LAYS
          end
        end

        # =====================================================================
        # ROUTE METHODS
        # =====================================================================

        # Exclude +1 trains from the list of trains that can be submitted as routes.
        # They act as a passive bonus (see check_distance below).
        def route_trains(entity)
          super.reject { |t| t.name == '+1' }
        end

        # Laos grouping: collapse all Laos stops to ONE for distance counting.
        # Revenue from all visited Laos hexes is still collected in full.
        def laos_collapsed(visits)
          laos = visits.select { |v| self.class::LAOS_HEXES.include?(v.hex.id) }
          return visits if laos.size <= 1

          visits - laos[1..]
        end

        # How many +1 trains does the owning corporation hold?
        def num_plus_one_trains(owner)
          return 0 unless owner.respond_to?(:trains)

          owner.trains.count { |t| t.name == '+1' }
        end

        # Distance validation:
        #   1. Collapse multiple Laos stops to one stop for distance purposes.
        #   2. For simple numeric-distance trains (2/3/4/5/6), each +1 train the
        #      corporation owns grants one free town stop on this route.
        def check_distance(route, visits, train = nil)
          t = train || route.train
          effective = laos_collapsed(visits)

          if t.distance.is_a?(Numeric) && t.name != '+1'
            num_free = num_plus_one_trains(t.owner)
            if num_free.positive?
              free_towns = effective.select(&:town?).first(num_free)
              effective = effective - free_towns
            end
          end

          super(route, effective, t)
        end

        # Per-route checks:
        #   - +1 train cannot be submitted as a standalone route.
        #   - Using the Cambodia gate path (C28→D27→E26→F25) requires a token in C30.
        def check_other(route)
          if route.train.name == '+1'
            raise GameError, '+1 train cannot run a route by itself'
          end

          if route.all_hexes.any? { |h| self.class::CAMBODIA_GATE_HEXES.include?(h.id) }
            pp = hex_by_id(self.class::PHNOM_PENH_HEX)
            tokened = pp.tile.cities.any? { |c| c.tokened_by?(route.corporation) }
            raise GameError, 'Must have a token in Phnom Penh (C30) to use the Cambodia gate path' unless tokened
          end
        end

        # Cross-route guard: +1 trains must not appear in any submitted route.
        def check_route_combination(routes)
          if routes.any? { |r| r.train.name == '+1' }
            raise GameError, '+1 train cannot be run as a route'
          end
        end

        # =====================================================================
        # ISSUE / REDEEM
        # Like 1849: may not issue/redeem until after first full OR.
        # Redeem: buy back 1 share from market (share price moves right).
        # Issue: sell up to 5 IPO shares to market (share price moves left).
        # =====================================================================
        def issuable_shares(entity)
          return [] unless entity.operating_history.size >= 1

          num_shares = 5 - entity.num_market_shares
          bundles = bundles_for_corporation(entity, entity)
          bundles.reject { |bundle| bundle.num_shares > num_shares }
        end

        def redeemable_shares(entity)
          return [] unless entity.operating_history.size >= 1

          bundles_for_corporation(share_pool, entity)
            .reject { |bundle| bundle.shares.size > 1 || entity.cash < bundle.price }
        end

        # =====================================================================
        # MERGE (phases '2' and '3' only)
        # =====================================================================
        def mergeable?(corp)
          corp != doumer && corp.floated? && !corp.closed?
        end

        # =====================================================================
        # GAME END
        # =====================================================================
        def game_end_check_stock_market?
          @stock_market.max_reached? || @diesel_purchased
        end

        def event_diesel_purchased!
          @log << '-- Event: First 8+ train purchased — end game triggered --'
          @diesel_purchased = true
        end

        def init_starting_cash(players, bank)
          cash = self.class::TOTAL_STARTING_CASH / players.size
          players.each { |p| bank.spend(cash, p) }
        end

        # Terrain costs (mountain/water) apply to every upgrade, not just blank→yellow.
        # Placed tiles carry no terrain data, so fall back to the hex's original preprinted
        # tile to read the terrain cost for yellow→green, green→brown, etc.
        def upgrade_cost(tile, hex, entity, spender)
          terrain_tile = tile.terrain.any? ? tile : hex.original_tile
          super(terrain_tile, hex, entity, spender)
        end

        # =====================================================================
        # PAR ZONE MANAGEMENT
        # =====================================================================
        def setup
          @available_par_groups = %i[par]
          @diesel_purchased = false
          @central_share_assignments = {}
          @c3_reserved_corp_sym = nil
          @reserved_redeemed = {}
          @reserved_shares = {}   # private_id => Share object marked buyable:false
          @laos_contract_owner = nil
          # Set after concession phase by setup_north/south_share_data
          @north_concession_corp = nil
          @south_concession_corp = nil

          # Tranche state — setup_tranches is called from step/auction after concessions resolve
          @tranches = []
          @current_tranche_idx = 0
          @tranche_exhausted = false
          @stock_round_count = 0

          @doumer_interest_pool = 0
          @doumer_loan_taken_this_or = false
          @pending_nationalization = nil
          @nationalized_corps = []
          setup_doumer_fund
        end

        # Called from step/auction.rb after distribute_privates! to record
        # which central corp each share certificate maps to, and to reserve
        # the C3 share in the appropriate central corp.
        def setup_central_share_data(share_assignments:, c3_reserved_corp:)
          @central_share_assignments = share_assignments
          @c3_reserved_corp_sym = c3_reserved_corp
          @log << "Central share certificate assignments: " \
                  "#{share_assignments.map { |id, sym| "#{id}→#{sym}" }.join(', ')}"
          @log << "C3 reserved share: #{c3_reserved_corp}"
          reserve_one_ipo_share(c3_reserved_corp, 'C3')
        end

        def setup_north_share_data(corp_sym)
          @north_concession_corp = corp_sym
          @log << "North Concession corporation: #{corp_sym} (N2/N3/N4 interact with #{corp_sym})"
          reserve_one_ipo_share(corp_sym, 'N3')
          reserve_one_ipo_share(corp_sym, 'N4')
        end

        def setup_south_share_data(corp_sym)
          @south_concession_corp = corp_sym
          @log << "South Concession corporation: #{corp_sym} (S1/S2/S4 interact with #{corp_sym})"
          reserve_one_ipo_share(corp_sym, 'S4')
        end

        # Mark one non-president IPO share of corp_sym as non-buyable (reserved).
        def reserve_one_ipo_share(corp_sym, private_id)
          corp = corporation_by_id(corp_sym)
          return unless corp

          share = corp.shares.find { |s| !s.president && s.owner == corp && s.buyable }
          return unless share

          share.buyable = false
          @reserved_shares[private_id] = share
        end

        # Restore the reserved share to normal IPO availability.
        def release_reserved_share(private_id)
          share = @reserved_shares.delete(private_id)
          share&.buyable = true
        end

        def par_prices
          @stock_market.share_prices_with_types(@available_par_groups)
        end

        def event_green_par!
          @log << "-- Event: #{self.class::EVENTS_TEXT[:green_par][0]} --"
          @available_par_groups << :par_1
          update_cache(:share_prices)
        end

        def event_brown_par!
          @log << "-- Event: #{self.class::EVENTS_TEXT[:brown_par][0]} --"
          @available_par_groups << :par_2
          update_cache(:share_prices)
        end

        # =====================================================================
        # +1 TRAIN LIMIT SYSTEM
        # =====================================================================

        def plus1_train_limit
          self.class::PLUS1_TRAIN_LIMITS.fetch(@phase.name, 1)
        end

        def plus1_trains_for(entity)
          entity.trains.reject { |t| t.obsolete || t.name != '+1' }
        end

        # Exclude +1 trains from the normal train count so each limit is checked independently.
        def num_corp_trains(entity)
          entity.trains.count { |t| !t.obsolete && t.name != '+1' }
        end

        # A corp is crowded if it exceeds either normal or +1 limits.
        def crowded_corps
          @crowded_corps ||= (minors + corporations).select do |c|
            num_corp_trains(c) > train_limit(c) ||
              plus1_trains_for(c).size > plus1_train_limit
          end
        end

        # =====================================================================
        # TRANCHE SYSTEM (SR float order for non-concession corps)
        # =====================================================================

        # Called from step/auction after all concessions are resolved.
        # Builds the tranche pool from unfloated eligible corps.
        # 3p: 7 corps unfloated → sizes [3, 2, 2]
        # 4p: 6 corps unfloated → sizes [3, 2, 1]
        def setup_tranches
          corps = self.class::TRANCHE_ELIGIBLE_CORPS
                       .map { |id| corporation_by_id(id) }
                       .compact
                       .reject(&:floated?)
                       .sort_by { rand }

          sizes = corps.size >= 7 ? [3, 2, 2] : [3, 2, 1]
          remaining = corps.dup
          @tranches = sizes.map { |n| remaining.shift(n) }
          log_tranche_assignments
        end

        def log_tranche_assignments
          @tranches.each.with_index(1) do |corps, i|
            @log << "Float tranche #{i}: #{corps.map(&:id).join(', ')}"
          end
        end

        def current_tranche
          @tranches[@current_tranche_idx] || []
        end

        def in_current_tranche?(corporation)
          current_tranche.include?(corporation)
        end

        def can_par?(corporation, parrer)
          return false if @nationalized_corps.include?(corporation)
          return super unless self.class::TRANCHE_ELIGIBLE_CORPS.include?(corporation.id)
          return false unless super
          return false unless in_current_tranche?(corporation)
          return false if @tranche_exhausted

          true
        end

        def float_corporation(corporation)
          super

          return unless self.class::TRANCHE_ELIGIBLE_CORPS.include?(corporation.id)
          return if @tranches.empty?   # concession phase — tranches not yet built
          return if @tranche_exhausted
          return unless current_tranche.all?(&:floated?)

          @tranche_exhausted = true
          @log << "Tranche #{@current_tranche_idx + 1} exhausted — " \
                  'no further corporations may be parred this Stock Round'
        end

        def stock_round
          Engine::Round::Stock.new(self, [
            Engine::Step::DiscardTrain,
            Engine::Step::Exchange,
            Engine::Step::SpecialTrack,
            Engine::Step::BuySellParShares,
          ])
        end

        def new_stock_round
          if @stock_round_count.positive?
            @current_tranche_idx = [@current_tranche_idx + 1, @tranches.size].min
            @tranche_exhausted = false
            if @current_tranche_idx < @tranches.size
              @log << "Float tranche #{@current_tranche_idx + 1} now active: " \
                      "#{current_tranche.map(&:id).join(', ')}"
            else
              @log << 'All float tranches exhausted — no new corporations may be parred'
            end
          end
          @stock_round_count += 1
          super
        end

        # =====================================================================
        # INITIAL AUCTION ROUND
        # =====================================================================
        def init_round
          @init_round ||= G1881::Round::Auction.new(self, [G1881::Step::Auction])
        end

        # Mapping of private company → minor corporation it floats.
        MINOR_PRIVATE_MAP = { 'N1' => 'SFTC', 'S3' => 'FMT' }.freeze

        # Share certificate IDs: buyer receives an IPO share of the named corp.
        CENTRAL_SHARE_CERT_IDS = %w[C1 C2 C1+ C2+].freeze
        NORTH_SHARE_CERT_IDS   = %w[N2].freeze
        SOUTH_SHARE_CERT_IDS   = %w[S1 S2].freeze

        # Corps eligible for the SR float-order tranche system.
        # All concession pair corps are included; the winner of each pair is floated during
        # the concession phase and filtered out by setup_tranches (reject(&:floated?)).
        # The loser of each pair remains unfloated and joins the tranche pool.
        # 3p: 3 corps floated (1 North + 1 South + 1 Central) → 7 unfloated → tranches 3-2-2
        # 4p: 4 corps floated (1 North + 1 South + CFCA + RCL) → 6 unfloated → tranches 3-2-1
        TRANCHE_ELIGIBLE_CORPS = %w[CFI HPR STC TMR CFCA RCL TIR TTC AT CPA].freeze

        # Concession pair corp IDs — one from each pair is randomly chosen each game.
        NORTH_CONCESSION_PAIR = %w[CFI HPR].freeze
        SOUTH_CONCESSION_PAIR = %w[STC TMR].freeze

        # Privates that reserve a share when company buys them.
        NORTH_RESERVED_PRIVATE_IDS = %w[N4].freeze
        SOUTH_RESERVED_PRIVATE_IDS = %w[S4].freeze

        # Per-phase limits for +1 trains (separate from normal train limits).
        PLUS1_TRAIN_LIMITS = {
          '+1'  => 1,
          '2'   => 1,
          '3'   => 1,
          '4'   => 2,
          '5'   => 2,
          '5+1' => 2,
          '6'   => 3,
          '8+'  => 3,
          'R2+1' => 3,
        }.freeze

        # Called when any company is purchased (auction phase or SR).
        def after_buy_company(buyer, company, price)
          super

          # Central share certificates: buyer receives a corp share, bid → corp
          if self.class::CENTRAL_SHARE_CERT_IDS.include?(company.id)
            handle_central_share_certificate(buyer, company, price)
            return
          end

          # North share certificates: buyer receives a North Concession corp share, bid → corp
          if self.class::NORTH_SHARE_CERT_IDS.include?(company.id)
            handle_concession_share_certificate(buyer, company, price, @north_concession_corp)
            return
          end

          # South share certificates: buyer receives a South Concession corp share, bid → corp
          if self.class::SOUTH_SHARE_CERT_IDS.include?(company.id)
            handle_concession_share_certificate(buyer, company, price, @south_concession_corp)
            return
          end

          # N4: corp may redeem the reserved North Concession share (corp-redeemable, not player)
          if self.class::NORTH_RESERVED_PRIVATE_IDS.include?(company.id) && buyer.is_a?(Engine::Corporation)
            handle_n4_company_purchase(buyer, company)
            return
          end

          # N3: player-redeemable reserved share; if corp buys unredeemed, share stays in North IPO
          if company.id == 'N3' && buyer.is_a?(Engine::Corporation)
            handle_reserved_private_company_purchase(buyer, company, @north_concession_corp)
            return
          end

          # S4: player-redeemable reserved share; if corp buys unredeemed, share stays in South IPO
          if self.class::SOUTH_RESERVED_PRIVATE_IDS.include?(company.id) && buyer.is_a?(Engine::Corporation)
            handle_reserved_private_company_purchase(buyer, company, @south_concession_corp)
            return
          end

          # C3: when a player buys it, immediately redeem the reserved share.
          #     When a corporation buys it unredeemed, the share returns to the IPO.
          if company.id == 'C3'
            if buyer.is_a?(Engine::Player)
              handle_c3_player_redemption(buyer, company)
            else
              handle_c3_company_purchase(buyer, company)
            end
            return
          end

          # C4: when a corporation buys it, automatically establish the Laos contract
          if company.id == 'C4' && buyer.is_a?(Engine::Corporation)
            handle_c4_company_purchase(buyer, company)
            return
          end

          # Concessions (-C suffix) float a major corp; N1/S3 float a minor corp.
          # Par = floor(bid / 2) rounded down to nearest par price.
          corp_sym = if company.id.end_with?('-C')
                       company.id.delete_suffix('-C')
                     else
                       self.class::MINOR_PRIVATE_MAP[company.id]
                     end
          return unless corp_sym

          float_via_private!(buyer, company, price, corp_sym)
        end

        def float_via_private!(player, _company, price, corp_sym)
          corporation = corporation_by_id(corp_sym)
          return unless corporation

          candidate = (price / 2).floor
          par_price = stock_market.par_prices.select { |p| p.price <= candidate }.max_by(&:price)
          par_price ||= stock_market.par_prices.min_by(&:price)

          @log << "#{player.name} receives the director's share of #{corporation.name}"
          @log << "Par price set to #{format_currency(par_price.price)} " \
                  "(half of #{format_currency(price)}, rounded down)"

          stock_market.set_par(corporation, par_price)
          share_pool.buy_shares(player, corporation.shares.first, exchange: :free, allow_president_change: true)

          seed = par_price.price * 2
          @bank.spend(seed, corporation)
          @log << "#{corporation.name} receives #{format_currency(seed)}"
        end

        # Central share certificate purchased: look up the mapped corp and delegate.
        def handle_central_share_certificate(buyer, company, price)
          corp_sym = @central_share_assignments[company.id]
          unless corp_sym
            @log << "#{company.name}: no central corp assignment found"
            return
          end
          handle_concession_share_certificate(buyer, company, price, corp_sym)
        end

        # Common handler for all share certificates (C1/C2, N2, S1/S2/S5):
        # buyer receives one IPO share of corp_sym for free; bid price → corp.
        def handle_concession_share_certificate(buyer, company, price, corp_sym)
          corp = corporation_by_id(corp_sym)
          unless corp
            @log << "#{company.name}: corporation #{corp_sym} not found"
            return
          end

          share = corp.shares.find { |s| !s.president && s.owner == corp && s.buyable }
          unless share
            @log << "#{corp.name} has no IPO shares available for #{company.name}"
            return
          end

          share_pool.buy_shares(buyer, share, exchange: :free, allow_president_change: false)
          @log << "#{buyer.name} receives one share of #{corp.name} via #{company.name}"

          # player → bank already happened in assign_private!; redirect bank → corp
          @bank.spend(price, corp)
          @log << "#{corp.name} receives #{format_currency(price)} (#{company.name} proceeds)"
        end

        # N4: when a corporation purchases it, the corp (not the player) may redeem the
        # reserved CFI share. Unredeemed share stays in CFI's IPO.
        # Redemption mechanic requires a custom action step (TODO).
        # N4: corp-redeemable reserved share. Buying corp may later redeem the CFI share
        # (drops income to ₫0). If not yet redeemed, the share stays reserved until then.
        def handle_n4_company_purchase(corp, company)
          unless @reserved_redeemed[company.id]
            @log << "#{corp.name} now holds #{company.name} and may redeem the reserved CFI share"
          end
          @log << "#{corp.name} owns #{company.name}"
        end

        # S4: player-redeemable reserved share. When a corporation buys it unredeemed,
        # the reserved STC share is released back to the normal IPO.
        def handle_reserved_private_company_purchase(corp, company, corp_sym)
          unless @reserved_redeemed[company.id]
            reserved_corp = corporation_by_id(corp_sym)
            release_reserved_share(company.id)
            @log << "#{company.name} sold unredeemed — reserved #{reserved_corp&.name} share returns to IPO"
          end
          @log << "#{corp.name} owns #{company.name}"
        end

        # C3: when a player wins it in the private auction, immediately transfer
        # the reserved central corp share to them. C3 revenue drops to ₫0 but
        # the private is kept (still blocks K18 upgrades while a player holds it).
        def handle_c3_player_redemption(player, company)
          reserved_corp = corporation_by_id(@c3_reserved_corp_sym)
          share = @reserved_shares['C3']
          unless share
            @log << "#{company.name}: no reserved share found for #{reserved_corp&.name}"
            return
          end

          @reserved_redeemed['C3'] = true
          share.buyable = true
          @reserved_shares.delete('C3')
          share_pool.buy_shares(player, share, exchange: :free, allow_president_change: false)
          company.revenue = 0
          @log << "#{player.name} redeems #{company.name} for one share of #{reserved_corp&.name}"
          @log << "#{company.name} revenue drops to #{format_currency(0)}"
        end

        # C3: player-redeemable reserved share. When a corporation buys it unredeemed,
        # the reserved central corp share is released back to the normal IPO.
        # The corporation may close C3 for a free tile upgrade on K18 (token costs normal).
        def handle_c3_company_purchase(corp, company)
          unless @reserved_redeemed['C3']
            reserved_corp = corporation_by_id(@c3_reserved_corp_sym)
            release_reserved_share('C3')
            @log << "#{company.name} sold unredeemed — reserved #{reserved_corp&.name} share returns to IPO"
          end
          @log << "#{corp.name} owns #{company.name} and may close it for a free tile upgrade on K18"
        end

        # When a corporation purchases C4 during the SR, it is immediately
        # converted to the Laos Export Contract (grants +₫10/Laos hex per route).
        def handle_c4_company_purchase(corp, company)
          company.close!
          @laos_contract_owner = corp
          @log << "#{corp.name} trades #{company.name} for the Laos Export Contract"
          @log << "#{corp.name} receives +#{format_currency(10)} per Laos hex on each route"
        end

        # Add Laos Export Contract bonus: +10 per Laos hex visited on the route.
        def revenue_for(route, stops)
          base = super
          return base unless @laos_contract_owner && route.train.owner == @laos_contract_owner

          laos_count = stops.count { |s| self.class::LAOS_HEXES.include?(s.hex.id) }
          base += laos_count * 10 if laos_count.positive?
          base
        end

        # Block K18 upgrades while C3 is held by a player (not a corporation).
        def upgrades_to?(from, to, special = false, selected_company: nil)
          if from.hex&.id == 'K18'
            c3 = company_by_id('C3')
            return false if c3 && !c3.closed? && c3.owner.is_a?(Engine::Player)
          end
          super
        end

        # =====================================================================
        # DOUMER FUND
        # =====================================================================
        def doumer
          @doumer ||= corporation_by_id(self.class::DOUMER_ID)
        end

        # Pars and floats the Doumer fund immediately at game start, seeded with
        # a fixed treasury rather than the usual per-share float proceeds.
        def setup_doumer_fund
          d = doumer
          return unless d

          par_price = stock_market.par_prices.find { |p| p.price == self.class::DOUMER_PAR_PRICE }
          stock_market.set_par(d, par_price)
          d.ipoed = true
          d.floated = true
          @bank.spend(self.class::DOUMER_STARTING_CASH, d)
          @log << "#{d.name} pars at #{format_currency(self.class::DOUMER_PAR_PRICE)} and floats " \
                  "automatically with #{format_currency(self.class::DOUMER_STARTING_CASH)} in capital"
        end

        # The Doumer fund never operates -- it only lends money and collects interest.
        def operating_order
          super.reject { |c| c == doumer }
        end

        # The Doumer fund's treasury is represented as 20 ₫100 loan cards.
        def init_loans
          Array.new(self.class::NUM_DOUMER_LOANS) { |id| Loan.new(id, self.class::LOAN_VALUE) }
        end

        def maximum_loans(_entity)
          self.class::NUM_DOUMER_LOANS
        end

        def loan_value(_entity = nil)
          self.class::LOAN_VALUE
        end

        def interest_rate
          self.class::LOAN_INTEREST
        end

        def interest_owed(entity)
          entity.loans.size * self.class::LOAN_INTEREST
        end

        def can_pay_interest?(entity, extra_cash = 0)
          owed = interest_owed(entity)
          return true unless owed.positive?

          president_cash = entity.player&.cash || 0
          entity.cash + extra_cash + president_cash >= owed
        end

        # Interest is always settled (or forgiven) automatically by PayInterest
        # before BuyTrain runs, so trains are never gated on it.
        def interest_paid?(_entity)
          true
        end

        def cannot_pay_interest_str
          '(may not be able to pay Doumer fund interest)'
        end

        # Hide the Loans/Interest rows on the Doumer fund's own corporation card;
        # it is a lender, not a borrower.
        def corporation_show_loans?(corporation)
          corporation != doumer
        end

        def take_doumer_loan(entity)
          loan = @loans.shift
          raise GameError, 'No loans available from the Doumer fund' unless loan

          entity.loans << loan
          doumer.spend(self.class::LOAN_VALUE, entity)
          @doumer_loan_taken_this_or = true
          @log << "#{entity.name} takes a #{format_currency(self.class::LOAN_VALUE)} loan from #{doumer.name}"
        end

        def payoff_doumer_loan(entity)
          loan = entity.loans.pop
          raise GameError, "#{entity.name} has no loans to pay off" unless loan

          entity.spend(self.class::LOAN_VALUE, doumer)
          @loans << loan
          @log << "#{entity.name} pays off a #{format_currency(self.class::LOAN_VALUE)} loan to #{doumer.name}"
        end

        # Interest owed = ₫10 per outstanding loan. Paid from the corporation's
        # cash first (this covers revenue withheld this turn as much as older
        # treasury cash), then the president's personal cash, then -- exactly
        # like an emergency train purchase -- the president is forced to sell
        # every sellable share they hold. Whatever is collected this way is
        # still set aside for Doumer shareholders even if it isn't enough; any
        # remaining shortfall triggers nationalize_corporation! instead of
        # being forgiven. See distribute_doumer_interest! for the payout.
        def collect_doumer_interest!(entity)
          return unless entity.corporation?

          owed = interest_owed(entity)
          return unless owed.positive?

          collected = 0
          president = entity.player

          collected += spend_toward_doumer_interest!(entity, owed - collected)
          collected += spend_toward_doumer_interest!(president, owed - collected) if president

          if president && (owed - collected).positive?
            force_sell_all_shares!(president)
            collected += spend_toward_doumer_interest!(president, owed - collected)
          end

          if collected.positive?
            @doumer_interest_pool += collected
            @log << "#{entity.name} pays #{format_currency(collected)} interest on #{entity.loans.size} " \
                    "loan(s), set aside for #{doumer.name} shareholders"
          end

          return unless (owed - collected).positive?

          @log << "#{entity.name} cannot pay #{format_currency(owed - collected)} interest even after " \
                  "#{president&.name || 'its'} forced share sale -- #{entity.name} is nationalized"
          @pending_nationalization = entity
        end

        # Pays up to `remaining` toward the interest bill out of payer's cash.
        def spend_toward_doumer_interest!(payer, remaining)
          return 0 unless payer && remaining.positive?

          amount = [remaining, payer.cash].min
          return 0 unless amount.positive?

          payer.spend(amount, @bank)
          amount
        end

        # Mirrors the emergency-train-purchase liquidation (Step::Bankrupt#sell_bankrupt_shares):
        # sell every sellable bundle the player holds, across all corporations,
        # largest bundle first, bypassing the normal once-per-turn sell limits.
        def force_sell_all_shares!(player)
          @log << "#{player.name} is forced to sell shares to cover #{doumer.name} interest"

          player.shares_by_corporation(sorted: true).each do |corporation, _|
            next unless corporation.share_price

            while (bundle = bundles_for_corporation(player, corporation).max_by(&:price))
              sell_shares_and_change_price(bundle)
            end
          end
        end

        # Distributes the accumulated interest pool to Doumer fund shareholders
        # (proportional to shares held), with any rounding remainder going to
        # the fund's own treasury.
        def distribute_doumer_interest!
          pool = @doumer_interest_pool
          return unless pool.positive?

          @doumer_interest_pool = 0
          d = doumer
          return unless d

          per_share = pool / d.total_shares.to_f
          total_paid = 0

          (@players + @corporations).each do |holder|
            next if holder == d

            shares = holder.num_shares_of(d)
            next unless shares.positive?

            amount = (shares * per_share).ceil
            next unless amount.positive?

            @bank.spend(amount, holder, check_positive: false)
            total_paid += amount
            @log << "#{holder.name} receives #{format_currency(amount)} interest from #{d.name}"
          end

          remainder = [pool - total_paid, 0].max
          return unless remainder.positive?

          @bank.spend(remainder, d)
          @log << "#{d.name} retains #{format_currency(remainder)} interest"
        end

        # Moves the Doumer fund's own share price: right if any corporation took
        # a loan this OR, left if none did.
        def move_doumer_price!
          d = doumer
          return unless d&.share_price

          old_price = d.share_price
          @doumer_loan_taken_this_or ? stock_market.move_right(d) : stock_market.move_left(d)
          log_share_price(d, old_price)
        end

        def or_round_finished
          super
          distribute_doumer_interest!
          move_doumer_price!
        end

        # The corporation currently awaiting its ex-president's token choice
        # (see G1881::Step::Nationalization), or nil.
        def pending_nationalization
          @pending_nationalization
        end

        # Nationalizes a corporation that could not pay its Doumer fund
        # interest even after its president was forced to sell every
        # sellable share. hex_id (chosen by the ex-president, may be nil/blank
        # if the corporation had no placed tokens) names the one token that
        # becomes a Doumer token; every other token comes off the board.
        # Remaining cash, trains, and companies transfer to the Doumer fund;
        # the corporation closes permanently and can never be parred again.
        def nationalize_corporation!(entity, hex_id)
          @pending_nationalization = nil
          d = doumer

          if hex_id && !hex_id.empty?
            hex = hex_by_id(hex_id)
            token = hex&.tile&.cities&.flat_map(&:tokens)&.compact&.find { |t| t.corporation == entity }
            doumer_token = token && d.next_token
            if doumer_token
              token.swap!(doumer_token, check_tokenable: false)
              @log << "#{d.name} places a token on #{hex.name} (#{hex.location_name}), replacing #{entity.name}'s"
            elsif token
              token.remove!
              @log << "#{d.name} has no tokens left -- #{entity.name}'s token on #{hex.name} is simply removed"
            end
          end

          hexes.each do |hex|
            hex.tile.cities.each do |city|
              city.tokens.select { |t| t&.corporation == entity }.each(&:remove!)
              city.reservations.delete(entity) if city.reserved_by?(entity)
            end
            hex.tile.reservations.delete(entity) if hex.tile.reserved_by?(entity)
          end

          entity.spend(entity.cash, d) if entity.cash.positive?

          unless entity.trains.empty?
            entity.trains.each { |t| t.owner = d }
            d.trains.concat(entity.trains)
            entity.trains.clear
          end

          unless entity.companies.empty?
            entity.companies.each { |c| c.owner = d }
            d.companies.concat(entity.companies)
            entity.companies.clear
          end

          entity.close!
          entity.floatable = false
          @nationalized_corps << entity

          @log << "#{entity.name} is closed permanently -- its remaining cash, trains, and companies " \
                  "transfer to #{d.name}"
        end

        # =====================================================================
        # OPERATING ROUND
        # =====================================================================
        def operating_round(round_num)
          @doumer_loan_taken_this_or = false

          Engine::Round::Operating.new(self, [
            Engine::Step::Bankrupt,
            G1881::Step::RedeemShares,    # 1. Redeem share (beginning of OR)
            G1881::Step::Loan,            # 1b. Take/repay a Doumer fund loan
            Engine::Step::SpecialTrack,
            Engine::Step::SpecialToken,
            Engine::Step::HomeToken,
            Engine::Step::Track,          # 2. Lay/upgrade tiles (phase-based)
            Engine::Step::Token,          # 3. Place station token
            Engine::Step::Route,          # 4. Run trains (TODO: custom route logic)
            G1881::Step::Dividend,        # 5. Pay dividend
            G1881::Step::PayInterest,     # 5b. Deduct Doumer fund loan interest
            G1881::Step::Nationalization, # 5c. Choose Doumer token if nationalized this turn
            Engine::Step::DiscardTrain,
            G1881::Step::BuyTrain,        # 6. Buy trains (separate limits for +1 vs normal)
            G1881::Step::IssueShares,     # 7. Issue shares (end of OR)
            G1881::Step::Merge,           # 8. Merge (phases 2 & 3 only)
          ], round_num: round_num)
        end
      end
    end
  end
end
