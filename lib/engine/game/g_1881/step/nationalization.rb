# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G1881
      module Step
        # Fires only for a corporation PayInterest just marked pending
        # (Game#pending_nationalization): its ex-president must choose which
        # placed token becomes a Doumer fund token before the corporation is
        # closed. If it has no placed tokens, this resolves automatically.
        class Nationalization < Engine::Step::Base
          ACTIONS = %w[choose].freeze

          def description
            'Choose Doumer Fund Token'
          end

          def choice_name
            entity = @game.pending_nationalization
            "#{entity.name}: choose which token becomes a #{@game.doumer.name} token"
          end

          def choices
            entity = @game.pending_nationalization
            return {} unless entity

            entity.tokens.select { |t| t.used && t.city }.each_with_object({}) do |token, h|
              hex = token.city.hex
              h[hex.id] = "#{hex.location_name} (#{hex.id})"
            end
          end

          def actions(entity)
            return [] unless pending?(entity)

            ACTIONS
          end

          def auto_actions(entity)
            return [] unless pending?(entity) && choices.empty?

            [Engine::Action::Choose.new(entity, choice: '')]
          end

          def pending?(entity)
            entity.corporation? && entity == current_entity && @game.pending_nationalization == entity
          end

          def blocks?
            true
          end

          # blocks? is unconditionally true (it must halt the round while a
          # choice is pending), so the default Step::Base#skip! would log a
          # "skips Choose Doumer Fund Token" line on every turn where nothing
          # is pending. Silence that; there's nothing worth logging.
          def log_skip(_entity); end

          def process_choose(action)
            @game.nationalize_corporation!(action.entity, action.choice)
          end
        end
      end
    end
  end
end
