# frozen_string_literal: true

require_relative 'entities'
require_relative 'map'
require_relative 'meta'
require_relative 'round/auction'
require_relative 'step/auction'
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

        CAPITALIZATION = :full

        MUST_SELL_IN_BLOCKS = false

        # STOCK MARKET
        MARKET = [
          # Row 0 (highest)
          %w[70 76 82 90 100 112 126 142 160 180 200 225 250 275 300 325 360 400 450],
          # Row 1 – brown multiple-buy zone begins at col 13
          %w[65 71 77 85 93 104 116 128 143 160 180 200 220 247b 260 290 320 355 395],
          # Row 2 – green ignore-sale zone at col 10
          %w[59 64 70 76 82 90 100 111 125 140 155i 170 185 204 230 253],
          # Row 3 – par zone cols 2-7 (p = par; no_cert_limit added via game override)
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

        # Map legend-0 (yellow/no-cert-limit) and par zones to yellow colour;
        # close stays black; ignore_one_sale stays green; multiple_buy stays brown.
        STOCKMARKET_COLORS = Base::STOCKMARKET_COLORS.merge(par: :yellow).freeze

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
          # +1 bonus train (starter): counts as 1-city distance for now
          { name: '+1', distance: 1, price: 30, num: 12 },

          # Standard trains
          { name: '2', distance: 2, price: 80, rusts_on: '4', num: 6 },

          # 120 base; 40 discount when trading a 2-train (saves 80)
          {
            name: '3',
            distance: 3,
            price: 120,
            discount: { '2' => 80 },
            rusts_on: '5',
            num: 5,
          },

          # 300 base; 60 discount when trading a 3-train (saves 60 → pays 240)
          {
            name: '4',
            distance: 4,
            price: 300,
            discount: { '3' => 60 },
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
            events: [{ 'type' => 'close_companies' }],
          },

          # 5+1: runs 5 cities + 1 bonus stop; 520 base (420 with trade-in)
          {
            name: '5+1',
            distance: [{ 'nodes' => %w[city offboard town], 'pay' => 5, 'visit' => 6 }],
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

          # 8+ ultra train (like D): unlimited city reach, 12 available
          {
            name: '8+',
            distance: [{ 'nodes' => %w[city offboard town], 'pay' => 8, 'visit' => 99 }],
            price: 1100,
            discount: { '5' => 300, '5+1' => 300, '6' => 300 },
            num: 12,
          },

          # R2+1: Rapid 2+1 regional train (like a 3E/diesel variant)
          {
            name: 'R2+1',
            distance: [{ 'nodes' => %w[city offboard town], 'pay' => 2, 'visit' => 3 }],
            price: 300,
            num: 6,
          },
        ].freeze

        # =====================================================================
        # INITIAL AUCTION ROUND
        # =====================================================================
        def init_round
          @init_round ||= G1881::Round::Auction.new(self, [G1881::Step::Auction])
        end

        # Called when any company is purchased (concession or private).
        # For concessions: calculate par from half the bid and float the corp.
        def after_buy_company(player, company, price)
          super

          return unless company.id.end_with?('-C')

          corp_sym = company.id.delete_suffix('-C')
          corporation = corporation_by_id(corp_sym)
          return unless corporation

          # Par price = floor(price / 2), rounded down to nearest valid par
          candidate = (price / 2).floor
          par_price = stock_market.par_prices.select { |p| p.price <= candidate }.max_by(&:price)
          par_price ||= stock_market.par_prices.min_by(&:price)

          @log << "#{player.name} receives the president's share of #{corporation.name}"
          @log << "Par price set to #{format_currency(par_price.price)} (half of #{format_currency(price)}, rounded down)"

          stock_market.set_par(corporation, par_price)
          share_pool.buy_shares(player, corporation.shares.first, exchange: :free, allow_president_change: true)
          float_corporation(corporation)
        end

        # =====================================================================
        # OPERATING ROUND (1830 placeholder steps)
        # =====================================================================
        def operating_round(round_num)
          Round::Operating.new(self, [
            Engine::Step::Bankrupt,
            Engine::Step::Exchange,
            Engine::Step::SpecialTrack,
            Engine::Step::SpecialToken,
            Engine::Step::BuyCompany,
            Engine::Step::HomeToken,
            Engine::Step::Track,
            Engine::Step::Token,
            Engine::Step::Route,
            Engine::Step::Dividend,
            Engine::Step::DiscardTrain,
            Engine::Step::BuyTrain,
            [Engine::Step::BuyCompany, { blocks: true }],
          ], round_num: round_num)
        end
      end
    end
  end
end
