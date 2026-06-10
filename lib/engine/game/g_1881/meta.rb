# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module G1881
      module Meta
        include Game::Meta

        DEV_STAGE = :prealpha
        PROTOTYPE = true

        GAME_TITLE = '1881'
        GAME_SUBTITLE = 'On the Rail to Stability'
        GAME_DESIGNER = 'Le Bao'
        GAME_LOCATION = 'Vietnam / Indochina'

        PLAYER_RANGE = [3, 4].freeze
      end
    end
  end
end
