# frozen_string_literal: true

require 'spec_helper'

describe Engine::Game::G1881::Game do
  let(:players) { %w[a b c] }
  let(:game) { Engine::Game::G1881::Game.new(players) }
  let(:doumer) { game.doumer }
  let(:vnr) { game.vnr }
  let(:cfi) { game.corporation_by_id('CFI') }
  let(:player_a) { game.players.find { |p| p.id == 'a' } }
  let(:player_b) { game.players.find { |p| p.id == 'b' } }
  let(:player_c) { game.players.find { |p| p.id == 'c' } }

  # Buys `n` 10% Doumer shares for `player` from the fund's own IPO.
  def buy_doumer_shares!(player, n)
    n.times do
      share = doumer.shares.find { |s| !s.president && s.owner == doumer && s.buyable }
      game.share_pool.buy_shares(player, share, exchange: :free, allow_president_change: true)
    end
  end

  # Pars and floats CFI with player_a as president, seeded with `seed` cash
  # in the corp treasury (mirrors float_via_private! without needing the
  # auction round).
  def float_cfi!(par_price: 65, seed: 130, president: player_a)
    par = game.stock_market.par_prices.find { |p| p.price == par_price }
    game.stock_market.set_par(cfi, par)
    game.share_pool.buy_shares(president, cfi.shares.first, exchange: :free, allow_president_change: true)
    game.bank.spend(seed, cfi)
  end

  def float_corp!(corp, par_price: 65, seed: 130, president: player_a)
    par = game.stock_market.par_prices.find { |p| p.price == par_price }
    game.stock_market.set_par(corp, par)
    game.share_pool.buy_shares(president, corp.shares.first, exchange: :free, allow_president_change: true)
    game.bank.spend(seed, corp)
  end

  # Any market cell at this price, not just par-eligible ones.
  def market_cell_at(price)
    cell = nil
    game.stock_market.instance_variable_get(:@market).each { |row| row.each { |c| cell ||= c if c&.price == price } }
    cell
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
    end

    it 'caps minors at MINOR_LOAN_LIMIT and majors at MAJOR_LOAN_LIMIT loans' do
      sftc = game.corporation_by_id('SFTC')
      expect(game.minor_corp?(cfi)).to eq(false)
      expect(game.minor_corp?(sftc)).to eq(true)
      expect(game.maximum_loans(cfi)).to eq(Engine::Game::G1881::Game::MAJOR_LOAN_LIMIT)
      expect(game.maximum_loans(sftc)).to eq(Engine::Game::G1881::Game::MINOR_LOAN_LIMIT)
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

    it 'take_doumer_loan raises once a corporation reaches its own loan cap' do
      float_cfi!
      Engine::Game::G1881::Game::MAJOR_LOAN_LIMIT.times { game.take_doumer_loan(cfi) }
      expect { game.take_doumer_loan(cfi) }
        .to raise_error(Engine::GameError, /already holds the maximum of 5 loans/)
    end

    it 'take_doumer_loan raises once the shared loan pool is exhausted' do
      majors = %w[CFI STC CFCA TMR HPR].map { |id| game.corporation_by_id(id) }
      majors.each { |corp| float_corp!(corp) }
      # NUM_DOUMER_LOANS (20) / MAJOR_LOAN_LIMIT (5) == 4 corps to fully drain the pool
      majors.first(4).each do |corp|
        Engine::Game::G1881::Game::MAJOR_LOAN_LIMIT.times { game.take_doumer_loan(corp) }
      end
      expect(game.loans).to be_empty

      expect { game.take_doumer_loan(majors.last) }.to raise_error(Engine::GameError, /No loans available/)
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
      Engine::Game::G1881::Game::MAJOR_LOAN_LIMIT.times { game.take_doumer_loan(cfi) } # owed = 50
      cfi.spend(cfi.cash, game.bank)
      player_a.spend(player_a.cash, game.bank)
      # Crash CFI's share price first so the forced sale of its president's
      # certificate can't raise enough to cover even this reduced debt.
      cheap = market_cell_at(24)
      cfi.share_price.corporations.delete(cfi)
      cfi.share_price = cheap
      cheap.corporations << cfi

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

    it 'moves the active fund\'s share price right by one step' do
      float_cfi!
      old_price = doumer.share_price.price
      game.nationalize_corporation!(cfi, nil)
      expect(doumer.share_price.price).to be > old_price
    end

    it 'moves VNR\'s price instead once the Doumer fund has closed' do
      old_doumer_price = doumer.share_price.price
      game.event_doumer_fund_closes!
      float_cfi!
      cfi.loans << Engine::Loan.new(0, Engine::Game::G1881::Game::LOAN_VALUE) # give it something to "owe"
      old_vnr_price = vnr.share_price.price

      game.nationalize_corporation!(cfi, nil)

      expect(vnr.share_price.price).to be > old_vnr_price
      expect(doumer.share_price).to be_nil # closed fund has no share price left to move
      expect(old_doumer_price).to be_a(Integer) # (sanity check the pre-closure price was captured)
    end
  end

  describe 'carry_over_doumer_shares_to_vnr!' do
    it 'gives each Doumer shareholder the same percentage of VNR' do
      buy_doumer_shares!(player_a, 3) # 30%
      buy_doumer_shares!(player_b, 2) # 20%
      buy_doumer_shares!(player_c, 1) # 10%

      game.event_doumer_fund_closes!

      expect(player_a.percent_of(vnr)).to eq(30)
      expect(player_b.percent_of(vnr)).to eq(20)
      expect(player_c.percent_of(vnr)).to eq(10)
      expect(vnr.percent_of(vnr)).to eq(40) # the 40% Doumer never sold stays unsold in VNR too
    end

    it 'makes the largest Doumer holder VNR\'s founding president when they reach the threshold' do
      buy_doumer_shares!(player_a, 3) # 30% -- above presidents_percent (20%)
      buy_doumer_shares!(player_b, 1) # 10%

      game.event_doumer_fund_closes!

      expect(vnr.owner).to eq(player_a)
    end

    it 'floats VNR immediately at closure if the carried-over percentage already clears float_percent' do
      buy_doumer_shares!(player_a, 3)
      buy_doumer_shares!(player_b, 2) # 50% combined -- VNR's float_percent

      game.event_doumer_fund_closes!

      expect(vnr.floated?).to eq(true)
    end

    it 'leaves VNR unowned when no single holder reaches the presidents_percent threshold' do
      buy_doumer_shares!(player_a, 1) # 10%
      buy_doumer_shares!(player_b, 1) # 10%
      buy_doumer_shares!(player_c, 1) # 10%

      game.event_doumer_fund_closes!

      expect(vnr.owner).to be_nil
      expect(player_a.percent_of(vnr)).to eq(10)
    end

    it 'does nothing when nobody held any Doumer shares' do
      expect { game.event_doumer_fund_closes! }.not_to raise_error
      expect(vnr.percent_of(vnr)).to eq(100)
      expect(vnr.floated?).to eq(false)
    end
  end

  describe 'VNR founder\'s tile/token ability' do
    def float_vnr_via_carry_over!(pct_for_a: 5)
      buy_doumer_shares!(player_a, pct_for_a)
      game.event_doumer_fund_closes!
    end

    it 'is not pending until VNR actually floats' do
      expect(game.vnr_founders_pending?).to eq(false)
    end

    it 'becomes pending the moment VNR floats' do
      float_vnr_via_carry_over!
      expect(game.vnr_founders_pending?).to eq(true)
      expect(game.vnr_founders_tile_pending?).to eq(true)
    end

    # define_singleton_method's block runs with self rebound to the step, so
    # it needs a real local variable (not an rspec `let`) in its closure.
    def tile_step_for(v)
      step = Engine::Game::G1881::Step::VnrFoundersTile.new(game, game.round)
      step.define_singleton_method(:current_entity) { v }
      step
    end

    def token_step_for(v)
      step = Engine::Game::G1881::Step::VnrFoundersToken.new(game, game.round)
      step.define_singleton_method(:current_entity) { v }
      step
    end

    it 'stays reserved (not usable) if VNR floats with no single holder at the presidents_percent' do
      stc = game.corporation_by_id('STC')
      float_cfi! # gives CFI treasury cash to spend
      float_corp!(stc, president: player_b)
      # Five 10% holders (players + the two just-floated corps) = 50%, none >= 20%.
      buy_doumer_shares!(player_a, 1)
      buy_doumer_shares!(player_b, 1)
      buy_doumer_shares!(player_c, 1)
      [cfi, stc].each do |corp|
        share = doumer.shares.find { |s| !s.president && s.owner == doumer && s.buyable }
        game.share_pool.buy_shares(corp, share, exchange: :free, allow_president_change: true)
      end

      game.event_doumer_fund_closes!

      expect(vnr.floated?).to eq(true)
      expect(vnr.owner).to be_nil
      expect(tile_step_for(vnr).eligible?(vnr)).to be_falsey
    end

    it 'lets the president lay a founding tile on any unclaimed city hex, charging full terrain cost' do
      float_vnr_via_carry_over!
      hex = game.hex_by_id('I28') # mountain 40
      cash_before = vnr.cash

      step = tile_step_for(vnr)
      tile = Engine::Tile.for('5')
      rotation = (0..5).find do |r|
        tile.rotate!(r)
        step.legal_tile_rotation?(vnr, hex, tile)
      end

      step.process_lay_tile(Engine::Action::LayTile.new(vnr, tile: tile, hex: hex, rotation: rotation))

      expect(hex.tile.name).to eq('5')
      expect(vnr.cash).to eq(cash_before - 40)
      expect(game.vnr_founders_token_pending?).to eq(hex)
    end

    it 'rejects a founding tile with no city' do
      float_vnr_via_carry_over!
      step = tile_step_for(vnr)
      plain_tile = Engine::Tile.for('8')

      action = Engine::Action::LayTile.new(vnr, tile: plain_tile, hex: game.hex_by_id('D7'), rotation: 0)
      expect { step.process_lay_tile(action) }.to raise_error(Engine::GameError, /has no city/)
    end

    it 'then lets the president place the founding token on that same city, and marks the ability used' do
      float_vnr_via_carry_over!
      hex = game.hex_by_id('C8')
      tile_step = tile_step_for(vnr)
      tile = Engine::Tile.for('5')
      rotation = (0..5).find do |r|
        tile.rotate!(r)
        tile_step.legal_tile_rotation?(vnr, hex, tile)
      end
      tile_step.process_lay_tile(Engine::Action::LayTile.new(vnr, tile: tile, hex: hex, rotation: rotation))

      token_step = token_step_for(vnr)
      city = hex.tile.cities.first

      token_step.process_place_token(Engine::Action::PlaceToken.new(vnr, city: city))

      expect(city.tokens.compact.map(&:corporation)).to include(vnr)
      expect(game.vnr_founders_pending?).to eq(false)
    end

    it 'rejects placing the founding token on a hex other than the one just laid' do
      float_vnr_via_carry_over!
      hex = game.hex_by_id('C8')
      tile_step = tile_step_for(vnr)
      tile = Engine::Tile.for('5')
      rotation = (0..5).find do |r|
        tile.rotate!(r)
        tile_step.legal_tile_rotation?(vnr, hex, tile)
      end
      tile_step.process_lay_tile(Engine::Action::LayTile.new(vnr, tile: tile, hex: hex, rotation: rotation))

      token_step = token_step_for(vnr)
      other_city = game.hex_by_id('G4').tile.cities.first

      action = Engine::Action::PlaceToken.new(vnr, city: other_city)
      expect { token_step.process_place_token(action) }.to raise_error(Engine::GameError, /founding hex/)
    end
  end
end
