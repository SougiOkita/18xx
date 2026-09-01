# frozen_string_literal: true

require 'spec_helper'

describe Engine::Game::G1881::Step::Merge do
  let(:players) { %w[a b c] }
  let(:game) { Engine::Game::G1881::Game.new(players) }
  let(:player_a) { game.players.find { |p| p.id == 'a' } }
  let(:cfi) { game.corporation_by_id('CFI') }
  let(:sftc) { game.corporation_by_id('SFTC') }

  # A Merge step whose connectivity check always succeeds, so `candidates`
  # exercises only the minor/major direction rule -- not real board topology.
  let(:step) do
    s = Engine::Game::G1881::Step::Merge.new(game, game.round)
    s.define_singleton_method(:connected?) { |_entity, _other| true }
    s
  end

  def float_corp!(corp, par_price: 65, seed: 500, president: player_a)
    par = game.stock_market.par_prices.find { |p| p.price == par_price }
    game.stock_market.set_par(corp, par)
    game.share_pool.buy_shares(president, corp.shares.first, exchange: :free, allow_president_change: true)
    game.bank.spend(seed, corp)
  end

  before do
    float_corp!(cfi)
    float_corp!(sftc)
  end

  it 'never offers a minor corporation any merge candidates, even when connected' do
    expect(game.minor_corp?(sftc)).to eq(true)
    expect(step.candidates(sftc)).to eq([])
  end

  it 'still offers a major corporation the (connected) minor as a candidate' do
    expect(game.minor_corp?(cfi)).to eq(false)
    expect(step.candidates(cfi)).to include(sftc)
  end

  it 'still offers a major corporation another (connected) major as a candidate' do
    stc = game.corporation_by_id('STC')
    float_corp!(stc)
    expect(step.candidates(cfi)).to include(stc)
  end

  it 'rejects a merge action where a minor would be the survivor' do
    action = Engine::Action::Merge.new(sftc, corporation: cfi)
    expect { step.process_merge(action) }.to raise_error(Engine::GameError, /not a valid merge target/)
  end
end
