# frozen_string_literal: true

require 'spec_helper'

# C3, N3, and N4 each grant a one-time, corporation-only bonus once a corp
# ends up owning them (regardless of whether the player redeemed the
# reserved share first -- see reserved_private_spec.rb for that mechanic):
#   - C3: a free tile upgrade on K18 (Ability::TileLay, via G1881::Step::SpecialTrack)
#   - N3: a permanent +₫30 revenue marker on one of 5 fixed port hexes
#     (Ability::AssignHexes, via G1881::Step::Assign)
#   - N4: a free tile lay/upgrade on any reachable city/town, which also drops
#     the same +₫30 marker on whichever hex was improved (Ability::TileLay,
#     via G1881::Step::SpecialTrack)
# The +₫30 marker is scoped to the corporation that placed it: Game#revenue_for
# checks hex.assigned?(route.corporation.id), not a shared/global bonus.
describe Engine::Game::G1881::Game do
  let(:players) { %w[a b c] }
  let(:game) { Engine::Game::G1881::Game.new(players) }
  let(:player_a) { game.players.find { |p| p.id == 'a' } }

  def setup_concessions!
    game.setup_central_share_data(share_assignments: { 'C1' => 'CFCA', 'C2' => 'CFCA' }, c3_reserved_corp: 'CFCA')
    game.setup_north_share_data('CFI')
    game.setup_south_share_data('STC')
  end

  def give_to_corp!(company, corp)
    company.owner = corp
    corp.companies << company
  end

  describe 'ownership gating (owner_type: corporation)' do
    it 'keeps the bonus abilities inert while held by a player, active once a corporation owns them' do
      setup_concessions!
      c3 = game.company_by_id('C3')
      n3 = game.company_by_id('N3')
      n4 = game.company_by_id('N4')
      cfca = game.corporation_by_id('CFCA')
      cfi = game.corporation_by_id('CFI')

      c3.owner = player_a
      n3.owner = player_a
      n4.owner = player_a
      expect(game.abilities(c3, :tile_lay)).to be_nil
      expect(game.abilities(n3, :assign_hexes)).to be_nil
      expect(game.abilities(n4, :tile_lay)).to be_nil

      give_to_corp!(c3, cfca)
      give_to_corp!(n3, cfi)
      give_to_corp!(n4, cfi)
      expect(game.abilities(c3, :tile_lay)).not_to be_nil
      expect(game.abilities(n3, :assign_hexes)).not_to be_nil
      expect(game.abilities(n4, :tile_lay)).not_to be_nil
    end
  end

  describe 'N3 port bonus (Ability::AssignHexes via G1881::Step::Assign)' do
    def assign_step(company)
      game.instance_variable_set(:@round, game.stock_round)
      game.round.setup
      game.round.active_step(company)
    end

    it 'lets the owning corporation discard it to mark one of the 5 port hexes, closing it' do
      setup_concessions!
      n3 = game.company_by_id('N3')
      cfi = game.corporation_by_id('CFI')
      # Sell N3 unredeemed to CFI via the real purchase flow, exactly as a
      # player would: this strips the exchange (redeem) ability per
      # release_reserved_share, leaving only the corp-only assign_hexes ability.
      n3.owner = player_a
      player_a.companies << n3
      n3.owner = cfi
      cfi.companies << n3
      game.after_buy_company(cfi, n3, n3.value)
      hex = game.hex_by_id('J9')

      step = assign_step(n3)
      expect(step).to be_a(Engine::Game::G1881::Step::Assign)

      step.process_assign(Engine::Action::Assign.new(n3, target: hex))

      expect(hex.assigned?(cfi.id)).to eq(true)
      expect(n3.closed?).to eq(true)
    end

    it 'only credits the corporation that placed it, in Game#revenue_for' do
      cfi = game.corporation_by_id('CFI')
      stc = game.corporation_by_id('STC')
      hex = game.hex_by_id('J9')

      game.assign_bonus_hex!(cfi, hex)

      stop = double('stop', route_revenue: 100, hex: hex)
      cfi_route = double('route', phase: game.phase, train: double('train'), corporation: cfi)
      stc_route = double('route', phase: game.phase, train: double('train'), corporation: stc)

      expect(game.revenue_for(cfi_route, [stop])).to eq(130)
      expect(game.revenue_for(stc_route, [stop])).to eq(100)
    end
  end

  describe 'C3 and N4 free tile-lay abilities (Ability::TileLay via G1881::Step::SpecialTrack)' do
    def special_track_step
      Engine::Game::G1881::Step::SpecialTrack.new(game, game.stock_round)
    end

    it "only assigns the bonus hex for N4's tile lay, not C3's" do
      setup_concessions!
      c3 = game.company_by_id('C3')
      n4 = game.company_by_id('N4')
      cfca = game.corporation_by_id('CFCA')
      cfi = game.corporation_by_id('CFI')
      give_to_corp!(c3, cfca)
      give_to_corp!(n4, cfi)
      hex = game.hex_by_id('K18')

      step = special_track_step
      step.maybe_assign_bonus_hex(c3, cfca, hex)
      expect(hex.assigned?(cfca.id)).to eq(false)

      step.maybe_assign_bonus_hex(n4, cfi, hex)
      expect(hex.assigned?(cfi.id)).to eq(true)
    end
  end
end
