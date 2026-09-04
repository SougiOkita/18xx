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

  # Redemption is offered via G1881::Step::Exchange (already in stock_round)
  # against the exchange ability reserve_one_ipo_share grants the private --
  # this is exactly what the frontend's Exchange button drives.
  def exchange_step(company)
    game.instance_variable_set(:@round, game.stock_round)
    game.round.setup
    game.round.active_step(company)
  end

  def redeem!(company, share)
    game.process_action(Engine::Action::BuyShares.new(company, shares: share)).maybe_raise!
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
      expect(game.corporation_by_id('CFCA').reserved_shares).not_to be_empty
    end

    it 'grants the exchange ability once reserved, offered via the standard Exchange step' do
      setup_concessions!
      c3 = game.company_by_id('C3')
      give_private!(player_a, c3)

      step = exchange_step(c3)
      expect(step).to be_a(Engine::Game::G1881::Step::Exchange)
      expect(step.can_exchange?(c3)).to eq(true)
      expect(step.actions(c3)).to include('buy_shares')
    end

    it 'lets the owning player redeem C3 for the reserved share, without closing it, and drops its income to 0' do
      setup_concessions!
      c3 = game.company_by_id('C3')
      give_private!(player_a, c3)
      cfca = game.corporation_by_id('CFCA')

      step = exchange_step(c3)
      redeem!(c3, cfca.reserved_shares.first)

      expect(player_a.num_shares_of(cfca)).to eq(1)
      expect(c3.closed?).to eq(false)
      expect(c3.owner).to eq(player_a)
      expect(c3.revenue).to eq(0)
      expect(step.can_exchange?(c3)).to eq(false)
      expect(game.abilities(c3, :exchange)).to be_nil
    end

    it 'lets the owning player redeem N4 for the reserved North Concession share, without closing it' do
      setup_concessions!
      n4 = game.company_by_id('N4')
      give_private!(player_a, n4)
      cfi = game.corporation_by_id('CFI')

      exchange_step(n4)
      redeem!(n4, cfi.reserved_shares.first)

      expect(player_a.num_shares_of(cfi)).to eq(1)
      expect(n4.closed?).to eq(false)
      expect(n4.revenue).to eq(0)
    end

    it 'lets the owning player redeem S4 for the reserved South Concession share, without closing it' do
      setup_concessions!
      s4 = game.company_by_id('S4')
      give_private!(player_b, s4)
      stc = game.corporation_by_id('STC')

      exchange_step(s4)
      redeem!(s4, stc.reserved_shares.first)

      expect(player_b.num_shares_of(stc)).to eq(1)
      expect(s4.closed?).to eq(false)
      expect(s4.revenue).to eq(0)
    end

    it 'lets a redeemed private (still owned by the player) later be sold to a corporation' do
      setup_concessions!
      c3 = game.company_by_id('C3')
      give_private!(player_a, c3)
      cfca = game.corporation_by_id('CFCA')

      exchange_step(c3)
      redeem!(c3, cfca.reserved_shares.first)

      # Selling the already-redeemed private to a corporation must not try to
      # release a reserved share a second time (there is none left).
      c3.owner = cfca
      cfca.companies << c3
      expect { game.after_buy_company(cfca, c3, c3.value) }.not_to raise_error

      expect(c3.owner).to eq(cfca)
      expect(c3.revenue).to eq(0)
    end

    it 'releases the reserved share and strips the exchange ability when sold unredeemed' do
      setup_concessions!
      c3 = game.company_by_id('C3')
      cfca = game.corporation_by_id('CFCA')
      give_private!(player_a, c3)

      c3.owner = cfca
      cfca.companies << c3
      game.after_buy_company(cfca, c3, c3.value)

      expect(cfca.reserved_shares).to be_empty
      reserved_share = cfca.shares.find { |s| !s.president }
      expect(reserved_share.buyable).to eq(true)
      expect(game.abilities(c3, :exchange)).to be_nil
    end
  end

  describe 'income of the ₫60 share-certificate privates' do
    it 'pays ₫5 instead of ₫0' do
      %w[C1 C2 C1+ C2+ N2 S1 S2].each do |id|
        company = game.company_by_id(id)
        expect(company.value).to eq(60)
        expect(company.revenue).to eq(5)
      end
    end
  end

  describe 'share-certificate privates (N2/S1/S2/C1/C2) force-assigned at price 0' do
    # Reported bug: Step::Auction#force_private! knocks the price down to 0
    # (existing privates pay out, price -= revenue, floored at 0) when nobody
    # can afford it. assign_private! already skips the player->bank spend for
    # a 0 price, but handle_concession_share_certificate still tried an
    # unconditional bank->corp spend of that same 0, raising
    # "Cannot spend zero or negative money in Spender.spend(0)".
    it 'does not raise when the bank has nothing to redirect to the corp' do
      setup_concessions!
      n2 = game.company_by_id('N2')
      cfi = game.corporation_by_id('CFI')

      expect { game.after_buy_company(player_a, n2, 0) }.not_to raise_error
      expect(player_a.num_shares_of(cfi)).to eq(1)
    end

    it 'still redirects a positive price from the bank to the corp' do
      setup_concessions!
      s1 = game.company_by_id('S1')
      stc = game.corporation_by_id('STC')
      corp_cash = stc.cash

      game.after_buy_company(player_a, s1, 20)

      expect(player_a.num_shares_of(stc)).to eq(1)
      expect(stc.cash).to eq(corp_cash + 20)
    end
  end
end
