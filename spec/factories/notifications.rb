FactoryBot.define do
  factory :notification do
    user { nil }
    actor_id { "" }
    comment { nil }
    read { false }
  end
end
