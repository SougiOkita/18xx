# frozen_string_literal: true

require_relative 'entities'
require_relative 'map'
require_relative 'meta'
require_relative 'round/auction'
require_relative 'step/auction'
require_relative 'step/redeem_shares'
require_relative 'step/issue_shares'
require_relative 'step/merge'
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

        CERT_LIMIT = { 3 => 20, 4 => 16 }.freeze

        STARTING_CASH = { 3 => 700, 4 => 525 }.freeze

        CAPITALIZATION = :incremental

        MUST_SELL_IN_BLOCKS = false

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
          # Row 5 (cols 14-18 are reserved mainline slots — blank)
          ['45', '50', '56', '62', '68', '75', '83', '91', '100', '110', '122', '134', '146', '158',
           '', '', '', '', ''],
          # Row 6 (cols 14-18 are reserved shortline slots — blank)
          ['40', '45', '50', '55', '62', '69', '77', '84', '92', '100', '108', '117', '128', '142',
           '', '', '', '', ''],
          # Row 7
          ['30', '34', '38', '42', '47', '53', '59', '66', '73', '81', '90', '99',
           '', '', '', '', '', '', ''],
          # Row 8 (bottom) – close cell at col 0
          ['0c', '24', '28', '31', '35', '40', '44', '52', '60',
           '', '', '', '', '', '', '', ''],
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
          eight_plus_purchased: ['First 8+ train sold', 'End game triggered — complete this OR set then play one more'],
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
          { name: '2', distance: 2, price: 80, rusts_on: '4', num: 6 },

          # 120 base; 40 discount when trading a 2-train (saves 80)
          {
            name: '3',
            distance: 3,
            price: 120,
            discount: { '2' => 80 },
            rusts_on: '5',
            num: 5,
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
            price: 1100,
            discount: { '5' => 300, '5+1' => 300, '6' => 300 },
            num: 12,
            events: [{ 'type' => 'eight_plus_purchased' }],
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
          corp.floated? && !corp.closed?
        end

        # =====================================================================
        # GAME END
        # =====================================================================
        def game_end_check_stock_market?
          @stock_market.max_reached? || @eight_plus_purchased
        end

        def event_eight_plus_purchased!
          @log << '-- Event: First 8+ train purchased — end game triggered --'
          @eight_plus_purchased = true
        end

        # =====================================================================
        # PAR ZONE MANAGEMENT
        # =====================================================================
        def setup
          @available_par_groups = %i[par]
          @eight_plus_purchased = false
          @central_share_assignments = {}
          @c3_reserved_corp_sym = nil
          @c3_redeemed = false
          @laos_contract_owner = nil
        end

        # Called from step/auction.rb after distribute_privates! to record
        # which central corp each share certificate maps to.
        def setup_central_share_data(share_assignments:, c3_reserved_corp:)
          @central_share_assignments = share_assignments
          @c3_reserved_corp_sym = c3_reserved_corp
          @log << "Central share certificate assignments: " \
                  "#{share_assignments.map { |id, sym| "#{id}→#{sym}" }.join(', ')}"
          @log << "C3 reserved share: #{c3_reserved_corp}"
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
        # INITIAL AUCTION ROUND
        # =====================================================================
        def init_round
          @init_round ||= G1881::Round::Auction.new(self, [G1881::Step::Auction])
        end

        # Mapping of private company → minor corporation it floats.
        MINOR_PRIVATE_MAP = { 'N1' => 'SFTC', 'S3' => 'FMT' }.freeze

        # Central share certificate IDs (C1/C2 in 3p, C1/C2/C1+/C2+ in 4p).
        CENTRAL_SHARE_CERT_IDS = %w[C1 C2 C1+ C2+].freeze

        # Called when any company is purchased (auction phase or SR).
        def after_buy_company(buyer, company, price)
          super

          # Central share certificates: buyer receives a corp share, bid → corp
          if self.class::CENTRAL_SHARE_CERT_IDS.include?(company.id)
            handle_central_share_certificate(buyer, company, price)
            return
          end

          # C3: when a corporation buys it, the reserved share transfers to them
          if company.id == 'C3' && buyer.is_a?(Engine::Corporation)
            handle_c3_company_purchase(buyer, company)
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

        # Central share certificate purchased: buyer gets one IPO share of the
        # mapped corp, and the bid price is redirected from the bank to that corp.
        def handle_central_share_certificate(buyer, company, price)
          corp_sym = @central_share_assignments[company.id]
          unless corp_sym
            @log << "#{company.name}: no central corp assignment found"
            return
          end

          corp = corporation_by_id(corp_sym)
          unless corp
            @log << "#{company.name}: corporation #{corp_sym} not found"
            return
          end

          share = corp.shares.find { |s| !s.president && s.owner == corp }
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

        # When a corporation purchases C3 during the SR, the reserved central
        # concession share transfers to that corporation (if not already redeemed).
        def handle_c3_company_purchase(corp, company)
          unless @c3_redeemed
            reserved_corp = corporation_by_id(@c3_reserved_corp_sym)
            if reserved_corp
              share = reserved_corp.shares.find { |s| !s.president && s.owner == reserved_corp }
              if share
                share_pool.buy_shares(corp, share, exchange: :free, allow_president_change: false)
                @log << "#{corp.name} receives the C3 reserved share of #{reserved_corp.name}"
                @c3_redeemed = true
              else
                @log << "#{reserved_corp.name} has no IPO shares remaining for C3 reserved share"
              end
            end
          end
          @log << "#{corp.name} owns #{company.name} and may close it for a free tile+token on K18"
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
        # OPERATING ROUND
        # =====================================================================
        def operating_round(round_num)
          Engine::Round::Operating.new(self, [
            Engine::Step::Bankrupt,
            G1881::Step::RedeemShares,    # 1. Redeem share (beginning of OR)
            Engine::Step::SpecialTrack,
            Engine::Step::SpecialToken,
            Engine::Step::HomeToken,
            Engine::Step::Track,          # 2. Lay/upgrade tiles (phase-based)
            Engine::Step::Token,          # 3. Place station token
            Engine::Step::Route,          # 4. Run trains (TODO: custom route logic)
            Engine::Step::Dividend,       # 5. Pay dividend (TODO: custom dividend)
            Engine::Step::DiscardTrain,
            Engine::Step::BuyTrain,       # 6. Buy trains (+1 always available via depot)
            G1881::Step::IssueShares,     # 7. Issue shares (end of OR)
            G1881::Step::Merge,           # 8. Merge (phases 2 & 3 only)
          ], round_num: round_num)
        end
      end
    end
  end
end
