FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    sequence(:email) { Faker::Internet.unique.email }
    password { "password" }
    confirmed_at { Time.current }
  end
end
