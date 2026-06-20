# frozen_string_literal: true

require_relative '../../../step/buy_train'

module Engine
  module Game
    module G1881
      module Step
        class BuyTrain < Engine::Step::BuyTrain
          # A corp has room if it can accept at least one more train of either type.
          def room?(entity, _shell = nil)
            normal_room = @game.num_corp_trains(entity) < @game.train_limit(entity)
            plus1_room  = @game.plus1_trains_for(entity).size < @game.plus1_train_limit
            normal_room || plus1_room
          end

          def process_buy_train(action)
            if action.train.name == '+1' &&
               @game.plus1_trains_for(action.entity).size >= @game.plus1_train_limit
              raise GameError, "#{action.entity.name} is at the +1 train limit " \
                               "(#{@game.plus1_train_limit}) for this phase"
            end

            if action.train.name != '+1' &&
               @game.num_corp_trains(action.entity) >= @game.train_limit(action.entity)
              raise GameError, "#{action.entity.name} is at the train limit " \
                               "(#{@game.train_limit(action.entity)}) for this phase"
            end

            super
          end
        end
      end
    end
  end
end
