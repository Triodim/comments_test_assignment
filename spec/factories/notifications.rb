# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    association :user
    association :actor, factory: :user
    association :comment
    read { false }

    trait :read do
      read { true }
    end
  end
end
