# frozen_string_literal: true

require 'spec_helper'

describe Engine::Game::G1881::Game do
  let(:players) { %w[a b c] }
  let(:game) { Engine::Game::G1881::Game.new(players) }
  let(:cfi) { game.corporation_by_id('CFI') }
  let(:player_a) { game.players.find { |p| p.id == 'a' } }
  let(:s4) { game.company_by_id('S4') }

  def float_cfi!
    par = game.stock_market.par_prices.find { |p| p.price == 65 }
    game.stock_market.set_par(cfi, par)
    game.share_pool.buy_shares(player_a, cfi.shares.first, exchange: :free, allow_president_change: true)
    game.bank.spend(500, cfi)
  end

  describe 'G26 (Cambodia hub)' do
    it 'acts as a normal offboard -- every edge is a dead-end stub, none connect to each other' do
      hex = game.hex_by_id('G26')
      exits = hex.tile.paths.map(&:exits)

      expect(exits).to contain_exactly([0], [2], [5])
      expect(hex.tile.paths).to all(satisfy { |p| p.nodes.any? })
    end
  end

  describe 'S4 (Indochine Express – Cambodia) free token ability' do
    def special_token_step
      step = Engine::Step::SpecialToken.new(game, game.round)
      game.round.instance_variable_set(:@teleported, nil)
      game.round.define_singleton_method(:teleported) { @teleported }
      game.round.define_singleton_method(:teleported=) { |v| @teleported = v }
      step
    end

    before do
      float_cfi!
      s4.owner = cfi
      cfi.companies << s4
      game.after_buy_company(cfi, s4, s4.value)
    end

    it 'is offered as a token-placement ability once a corporation owns it' do
      step = special_token_step
      expect(step.ability(s4)&.type).to eq(:token)
      expect(step.actions(s4)).to include('place_token')
    end

    it 'places a free token on C30, closes S4, and unlocks the Phnom Penh gate check' do
      c30 = game.hex_by_id('C30')
      city = c30.tile.cities.first
      step = special_token_step

      cash_before = cfi.cash
      step.process_place_token(Engine::Action::PlaceToken.new(s4, city: city))

      expect(city.tokens.compact.map(&:corporation)).to include(cfi)
      expect(s4.closed?).to eq(true)
      expect(cfi.cash).to eq(cash_before) # free
      expect(c30.tile.cities.any? { |c| c.tokened_by?(cfi) }).to eq(true)
    end
  end
end
