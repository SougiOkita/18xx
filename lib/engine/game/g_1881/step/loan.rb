# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G1881
      module Step
        # Placed right after Redeem Shares: a corporation may take one loan from
        # the Doumer fund, or repay one of its outstanding loans -- but not both
        # in the same turn (acting here passes the step for the rest of the turn).
        class Loan < Engine::Step::Base
          def actions(entity)
            return [] unless entity.corporation? && entity == current_entity

            actions = []
            actions << 'take_loan' if can_take_loan?(entity)
            actions << 'payoff_loan' if can_payoff_loan?(entity)
            return [] if actions.empty?

            actions << 'pass'
            actions
          end

          def description
            'Doumer Fund Loan'
          end

          def pass_description
            'Skip (Loan)'
          end

          def blocks?
            false
          end

          def can_take_loan?(entity)
            @game.loans.any? && entity.loans.size < @game.maximum_loans(entity)
          end

          def can_payoff_loan?(entity)
            entity.loans.any? && entity.cash >= @game.class::LOAN_VALUE
          end

          def process_take_loan(action)
            @game.take_doumer_loan(action.entity)
            pass!
          end

          def process_payoff_loan(action)
            @game.payoff_doumer_loan(action.entity)
            pass!
          end
        end
      end
    end
  end
end
