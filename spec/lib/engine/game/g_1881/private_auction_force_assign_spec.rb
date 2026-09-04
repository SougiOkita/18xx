# frozen_string_literal: true

require 'spec_helper'

describe Engine::Game::G1881::Step::Auction do
  let(:players) { %w[p1 p2 p3 p4] }
  let(:game) { Engine::Game::G1881::Game.new(players) }
  let(:p1) { game.players[0] }
  let(:p2) { game.players[1] }
  let(:p3) { game.players[2] }
  let(:p4) { game.players[3] }
  let(:step) { game.round.active_step }

  # nearest_affordable_player is private; exercise it directly rather than
  # driving the whole auction, since the bug is specifically in its priority
  # order, independent of how the state around it was reached.
  def forced_buyer(auctioneer, price)
    step.instance_variable_set(:@auctioneer, auctioneer)
    step.send(:nearest_affordable_player, price)
  end

  describe 'nearest_affordable_player' do
    it 'picks the auctioneer first when they can still afford it, even if someone else already passed' do
      # Reported bug: p2 offers a private, p3 and p1 both pass (p1 can't
      # afford it), and p2 -- who put it up and can afford it -- should win
      # it, not p3 who already passed.
      p1.spend(p1.cash - 100, game.bank) # can't afford 150
      p2.spend(p2.cash - 330, game.bank) # affords it easily
      p3.spend(p3.cash - 200, game.bank) # also affords it, but has passed
      p1.pass!
      p3.pass!

      expect(forced_buyer(p2, 150)).to eq(p2)
    end

    it 'falls back to the nearest non-passed affordable player if the auctioneer cannot afford it' do
      p1.spend(p1.cash - 50, game.bank)   # auctioneer, can't afford
      p2.spend(p2.cash - 300, game.bank)  # not passed, affords it
      p3.pass!
      p3.spend(p3.cash - 300, game.bank)  # passed, also affords it -- should lose to p2

      expect(forced_buyer(p1, 150)).to eq(p2)
    end

    it 'falls back further to a passed-but-affordable player if nobody else qualifies' do
      p1.spend(p1.cash - 50, game.bank)  # auctioneer, can't afford
      p2.spend(p2.cash, game.bank)       # broke
      p3.pass!
      p3.spend(p3.cash - 300, game.bank) # passed, but only one who can afford it
      p4.pass!
      p4.spend(p4.cash, game.bank)       # passed and broke

      expect(forced_buyer(p1, 150)).to eq(p3)
    end
  end
end
