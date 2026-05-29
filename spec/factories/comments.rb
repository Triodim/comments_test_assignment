# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    sequence(:body) { |n| "Comment body number #{n}" }
    association :user

    trait :reply do
      association :parent, factory: :comment
    end
  end
end
