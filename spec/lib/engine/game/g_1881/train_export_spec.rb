# frozen_string_literal: true

require 'spec_helper'

describe Engine::Game::G1881::Game do
  let(:players) { %w[a b c] }
  let(:game) { Engine::Game::G1881::Game.new(players) }

  def force_phase!(name)
    phase = game.phase
    idx = phase.instance_variable_get(:@phases).find_index { |p| p[:name] == name }
    phase.instance_variable_set(:@index, idx)
    phase.send(:setup_phase!)
  end

  describe 'export_train!' do
    it 'does nothing outside phases 2 and 3' do
      expect(game.phase.name).to eq('+1')
      expect { game.export_train! }.not_to(change { game.depot.upcoming.size })
    end

    it 'exports one train of the current type during phase 2' do
      force_phase!('2')
      expect { game.export_train! }.to change { game.depot.upcoming.size }.by(-1)
      expect(game.log.last.message).to match(/A 2 train exports/)
    end

    it 'exports one train of the current type during phase 3' do
      force_phase!('3')
      expect { game.export_train! }.to change { game.depot.upcoming.size }.by(-1)
      expect(game.log.last.message).to match(/A 2 train exports/)
    end

    it 'does nothing once past phase 3' do
      force_phase!('4')
      expect { game.export_train! }.not_to(change { game.depot.upcoming.size })
    end

    it 'runs automatically at the end of every operating round in phase 2/3' do
      force_phase!('2')
      expect { game.or_round_finished }.to change { game.depot.upcoming.size }.by(-1)
    end

    it 'stops safely once repeated exports carry the phase past 3' do
      force_phase!('2')
      # Exporting trains advances the phase like a real purchase would; once
      # it passes phase 3, export_train! should just stop, not raise.
      30.times { game.export_train! }
      expect(%w[2 3]).not_to include(game.phase.name)
      expect { game.export_train! }.not_to raise_error
    end
  end
end
