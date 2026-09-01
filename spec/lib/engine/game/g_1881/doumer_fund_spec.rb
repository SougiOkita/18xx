# frozen_string_literal: true

require 'spec_helper'

describe Engine::Game::G1881::Game do
  let(:players) { %w[a b c] }
  let(:game) { Engine::Game::G1881::Game.new(players) }
  let(:doumer) { game.doumer }
  let(:cfi) { game.corporation_by_id('CFI') }
  let(:player_a) { game.players.find { |p| p.id == 'a' } }
  let(:player_b) { game.players.find { |p| p.id == 'b' } }

  # Pars and floats CFI with player_a as president, seeded with `seed` cash
  # in the corp treasury (mirrors float_via_private! without needing the
  # auction round).
  def float_cfi!(par_price: 65, seed: 130, president: player_a)
    par = game.stock_market.par_prices.find { |p| p.price == par_price }
    game.stock_market.set_par(cfi, par)
    game.share_pool.buy_shares(president, cfi.shares.first, exchange: :free, allow_president_change: true)
    game.bank.spend(seed, cfi)
  end

  describe 'setup_doumer_fund' do
    it 'pars and floats the Doumer fund automatically at game start' do
      expect(doumer.ipoed).to eq(true)
      expect(doumer.floated?).to eq(true)
      expect(doumer.share_price.price).to eq(Engine::Game::G1881::Game::DOUMER_PAR_PRICE)
      expect(doumer.cash).to eq(Engine::Game::G1881::Game::DOUMER_STARTING_CASH)
    end

    it 'never appears in the operating order' do
      float_cfi!
      expect(game.operating_order).not_to include(doumer)
    end

    it 'hides the loans/interest display on its own corporation card' do
      expect(game.corporation_show_loans?(doumer)).to eq(false)
      float_cfi!
      expect(game.corporation_show_loans?(cfi)).to eq(true)
    end
  end

  describe 'loans' do
    it 'creates NUM_DOUMER_LOANS loans worth LOAN_VALUE each' do
      expect(game.loans.size).to eq(Engine::Game::G1881::Game::NUM_DOUMER_LOANS)
      expect(game.loans).to all(have_attributes(amount: Engine::Game::G1881::Game::LOAN_VALUE))
      expect(game.maximum_loans(cfi)).to eq(Engine::Game::G1881::Game::NUM_DOUMER_LOANS)
    end

    it 'take_doumer_loan moves cash from Doumer to the corp and records the loan' do
      float_cfi!
      expect { game.take_doumer_loan(cfi) }
        .to change { cfi.cash }.by(100)
        .and change { doumer.cash }.by(-100)
        .and change { cfi.loans.size }.by(1)
        .and change { game.loans.size }.by(-1)
    end

    it 'payoff_doumer_loan reverses take_doumer_loan' do
      float_cfi!
      game.take_doumer_loan(cfi)
      expect { game.payoff_doumer_loan(cfi) }
        .to change { cfi.cash }.by(-100)
        .and change { doumer.cash }.by(100)
        .and change { cfi.loans.size }.by(-1)
        .and change { game.loans.size }.by(1)
    end

    it 'payoff_doumer_loan raises when the corp holds no loans' do
      float_cfi!
      expect { game.payoff_doumer_loan(cfi) }.to raise_error(Engine::GameError, /no loans to pay off/)
    end

    it 'take_doumer_loan raises when the fund has no loans left' do
      float_cfi!
      Engine::Game::G1881::Game::NUM_DOUMER_LOANS.times { game.take_doumer_loan(cfi) }
      expect { game.take_doumer_loan(cfi) }.to raise_error(Engine::GameError, /No loans available/)
    end
  end

  describe 'interest' do
    it 'interest_owed is LOAN_INTEREST per outstanding loan' do
      float_cfi!
      expect(game.interest_owed(cfi)).to eq(0)
      2.times { game.take_doumer_loan(cfi) }
      expect(game.interest_owed(cfi)).to eq(2 * Engine::Game::G1881::Game::LOAN_INTEREST)
    end

    it 'can_pay_interest? is true with no loans' do
      float_cfi!
      expect(game.can_pay_interest?(cfi)).to eq(true)
    end

    it 'can_pay_interest? checks corp cash plus president cash against interest owed' do
      float_cfi!
      game.take_doumer_loan(cfi)
      cfi.spend(cfi.cash, game.bank)
      expect(game.can_pay_interest?(cfi)).to eq(true) # president still has starting cash
      player_a.spend(player_a.cash, game.bank)
      expect(game.can_pay_interest?(cfi)).to eq(false)
    end

    it 'interest_paid? is always true (settled automatically by PayInterest)' do
      expect(game.interest_paid?(cfi)).to eq(true)
    end
  end

  describe 'collect_doumer_interest!' do
    it 'does nothing when the corp has no loans' do
      float_cfi!
      expect { game.collect_doumer_interest!(cfi) }.not_to(change { cfi.cash })
    end

    it 'pays interest out of the corp treasury first' do
      float_cfi!
      game.take_doumer_loan(cfi)
      expect { game.collect_doumer_interest!(cfi) }.to change { cfi.cash }.by(-10)
      expect(game.pending_nationalization).to be_nil
    end

    it 'falls back to the president when the treasury is short' do
      float_cfi!
      game.take_doumer_loan(cfi)
      cfi.spend(cfi.cash - 4, game.bank) # leave 4, owed is 10
      expect { game.collect_doumer_interest!(cfi) }
        .to change { cfi.cash }.by(-4)
        .and change { player_a.cash }.by(-6)
      expect(game.pending_nationalization).to be_nil
    end

    it 'force-sells every sellable share of the president when cash still falls short' do
      float_cfi!
      5.times { game.take_doumer_loan(cfi) } # owed = 50
      cfi.spend(cfi.cash, game.bank)
      player_a.spend(player_a.cash - 5, game.bank) # leave a token amount
      expect(player_a.num_shares_of(cfi)).to eq(2) # 20% president's certificate

      game.collect_doumer_interest!(cfi)

      expect(player_a.num_shares_of(cfi)).to eq(0)
      expect(game.pending_nationalization).to be_nil # sale raised enough to cover the rest
    end

    it 'sets pending_nationalization when even the forced sale cannot cover the debt' do
      float_cfi!
      Engine::Game::G1881::Game::NUM_DOUMER_LOANS.times { game.take_doumer_loan(cfi) } # owed = 200
      cfi.spend(cfi.cash, game.bank)
      player_a.spend(player_a.cash, game.bank)

      game.collect_doumer_interest!(cfi)

      expect(game.pending_nationalization).to eq(cfi)
    end

    it 'accumulates collected interest into the Doumer interest pool' do
      float_cfi!
      game.take_doumer_loan(cfi)
      expect { game.collect_doumer_interest!(cfi) }
        .to change { game.instance_variable_get(:@doumer_interest_pool) }.by(10)
    end
  end

  describe 'distribute_doumer_interest!' do
    it 'does nothing when the pool is empty' do
      expect { game.distribute_doumer_interest! }.not_to(change { doumer.cash })
    end

    it 'sends the whole pool to Doumer treasury when nobody else holds shares' do
      float_cfi!
      game.take_doumer_loan(cfi)
      game.collect_doumer_interest!(cfi)
      expect { game.distribute_doumer_interest! }.to change { doumer.cash }.by(10)
    end

    it 'pays shareholders proportionally to their Doumer holdings, remainder to Doumer' do
      float_cfi!
      doumer_share = doumer.shares.find { |s| !s.president && s.owner == doumer }
      game.share_pool.buy_shares(player_b, doumer_share, exchange: :free) # player_b holds 10%

      5.times { game.take_doumer_loan(cfi) } # owed = 50, fully payable from treasury
      game.bank.spend(1000, cfi)
      game.collect_doumer_interest!(cfi)
      expect(game.instance_variable_get(:@doumer_interest_pool)).to eq(50)

      expect { game.distribute_doumer_interest! }
        .to change { player_b.cash }.by(5) # 10% of 50
      expect(game.instance_variable_get(:@doumer_interest_pool)).to eq(0)
    end

    it 'resets the pool to zero after distributing' do
      float_cfi!
      game.take_doumer_loan(cfi)
      game.collect_doumer_interest!(cfi)
      game.distribute_doumer_interest!
      expect(game.instance_variable_get(:@doumer_interest_pool)).to eq(0)
    end
  end

  describe 'move_doumer_price!' do
    it 'moves the Doumer share price right when a loan was taken this OR' do
      float_cfi!
      game.instance_variable_set(:@doumer_loan_taken_this_or, true)
      expect { game.move_doumer_price! }.to(change { doumer.share_price.price })
      expect(doumer.share_price.price).to be > Engine::Game::G1881::Game::DOUMER_PAR_PRICE
    end

    it 'moves the Doumer share price left when no loan was taken this OR' do
      game.instance_variable_set(:@doumer_loan_taken_this_or, false)
      expect { game.move_doumer_price! }.to(change { doumer.share_price.price })
      expect(doumer.share_price.price).to be < Engine::Game::G1881::Game::DOUMER_PAR_PRICE
    end

    it 'is reset to false at the start of every operating round' do
      game.instance_variable_set(:@doumer_loan_taken_this_or, true)
      game.operating_round(1)
      expect(game.instance_variable_get(:@doumer_loan_taken_this_or)).to eq(false)
    end
  end

  describe 'nationalize_corporation!' do
    it 'closes the corp permanently and blocks it from ever being parred again' do
      float_cfi!
      game.nationalize_corporation!(cfi, nil)
      expect(cfi.closed?).to eq(true)
      expect(cfi.floatable).to eq(false)
      expect(game.can_par?(cfi, player_a)).to eq(false)
    end

    it 'transfers remaining cash, trains, and companies to the Doumer fund' do
      float_cfi!
      train = game.trains.find { |t| t.name == '2' }
      train.owner = cfi
      cfi.trains << train
      company = game.companies.find { |c| !c.closed? }
      company.owner = cfi
      cfi.companies << company

      corp_cash_before = cfi.cash
      doumer_cash_before = doumer.cash

      game.nationalize_corporation!(cfi, nil)

      expect(cfi.cash).to eq(0)
      expect(doumer.cash).to eq(doumer_cash_before + corp_cash_before)
      expect(doumer.trains).to include(train)
      expect(train.owner).to eq(doumer)
      expect(doumer.companies).to include(company)
      expect(company.owner).to eq(doumer)
    end

    it 'is excluded from mergeable? once nationalized' do
      float_cfi!
      expect(game.mergeable?(cfi)).to eq(true)
      game.nationalize_corporation!(cfi, nil)
      expect(game.mergeable?(cfi)).to eq(false)
    end
  end
end
