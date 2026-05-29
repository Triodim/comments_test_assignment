FactoryBot.define do
  factory :comment do
    body { "MyText" }
    user { nil }
    ancestry { "MyString" }
  end
end
