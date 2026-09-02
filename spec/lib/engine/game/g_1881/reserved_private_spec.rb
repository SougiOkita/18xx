# frozen_string_literal: true

require 'spec_helper'

describe Engine::Game::G1881::Game do
  let(:players) { %w[a b c] }
  let(:game) { Engine::Game::G1881::Game.new(players) }
  let(:player_a) { game.players.find { |p| p.id == 'a' } }
  let(:player_b) { game.players.find { |p| p.id == 'b' } }

  def setup_concessions!
    game.setup_central_share_data(share_assignments: { 'C1' => 'CFCA', 'C2' => 'CFCA' }, c3_reserved_corp: 'CFCA')
    game.setup_north_share_data('CFI')
    game.setup_south_share_data('STC')
  end

  def give_private!(player, company)
    company.owner = player
    player.companies << company
    game.after_buy_company(player, company, company.value)
  end

  describe 'max_price (face-value-only resale)' do
    it 'caps C3, N3, N4, and S4 at their face value instead of the usual 2x' do
      %w[C3 N3 N4 S4].each do |id|
        company = game.company_by_id(id)
        expect(company.max_price).to eq(company.value)
      end
    end

    it 'leaves other privates at the normal 2x cap' do
      c4 = game.company_by_id('C4')
      expect(c4.max_price).to eq(c4.value * 2)
    end
  end

  describe 'redemption' do
    it 'does not auto-redeem C3 the moment a player buys it' do
      setup_concessions!
      c3 = game.company_by_id('C3')
      give_private!(player_a, c3)

      expect(c3.revenue).to eq(10)
      expect(c3.closed?).to eq(false)
      expect(game.reserved_share_for('C3')).not_to be_nil
    end

    it 'lets the owning player redeem C3 for the reserved share at any point' do
      setup_concessions!
      c3 = game.company_by_id('C3')
      give_private!(player_a, c3)
      cfca = game.corporation_by_id('CFCA')

      step = Engine::Game::G1881::Step::RedeemPrivateShare.new(game, game.round)
      expect(step.redeemable?(c3)).to eq(true)

      share = game.reserved_share_for('C3')
      step.process_buy_shares(Engine::Action::BuyShares.new(c3, shares: share))

      expect(player_a.num_shares_of(cfca)).to eq(1)
      expect(c3.closed?).to eq(true)
      expect(game.reserved_share_for('C3')).to be_nil
    end

    it 'lets the owning player redeem N4 for the reserved North Concession share' do
      setup_concessions!
      n4 = game.company_by_id('N4')
      give_private!(player_a, n4)
      cfi = game.corporation_by_id('CFI')

      step = Engine::Game::G1881::Step::RedeemPrivateShare.new(game, game.round)
      share = game.reserved_share_for('N4')
      step.process_buy_shares(Engine::Action::BuyShares.new(n4, shares: share))

      expect(player_a.num_shares_of(cfi)).to eq(1)
      expect(n4.closed?).to eq(true)
    end

    it 'lets the owning player redeem S4 for the reserved South Concession share' do
      setup_concessions!
      s4 = game.company_by_id('S4')
      give_private!(player_b, s4)
      stc = game.corporation_by_id('STC')

      step = Engine::Game::G1881::Step::RedeemPrivateShare.new(game, game.round)
      share = game.reserved_share_for('S4')
      step.process_buy_shares(Engine::Action::BuyShares.new(s4, shares: share))

      expect(player_b.num_shares_of(stc)).to eq(1)
      expect(s4.closed?).to eq(true)
    end

    it 'is not redeemable once the private has no reserved share left' do
      setup_concessions!
      c3 = game.company_by_id('C3')
      give_private!(player_a, c3)

      step = Engine::Game::G1881::Step::RedeemPrivateShare.new(game, game.round)
      step.process_buy_shares(Engine::Action::BuyShares.new(c3, shares: game.reserved_share_for('C3')))

      expect(step.redeemable?(c3)).to eq(false)
      expect(step.actions(c3)).to eq([])
    end

    it 'still releases the reserved share to the IPO when sold unredeemed to a corporation' do
      setup_concessions!
      c3 = game.company_by_id('C3')
      cfca = game.corporation_by_id('CFCA')
      give_private!(player_a, c3)

      c3.owner = cfca
      cfca.companies << c3
      game.after_buy_company(cfca, c3, c3.value)

      expect(game.reserved_share_for('C3')).to be_nil
      reserved_share = cfca.shares.find { |s| !s.president }
      expect(reserved_share.buyable).to eq(true)
    end
  end
end
