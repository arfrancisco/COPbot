FactoryBot.define do
  factory :message do
    channel_id { Faker::Number.number(digits: 10) }
    text { Faker::Lorem.paragraph }
    message_timestamp { Faker::Time.between(from: 30.days.ago, to: Time.current) }
    embedding { Array.new(1536) { rand } }  # Random embedding vector

    trait :old do
      message_timestamp { 100.days.ago }
    end

    trait :recent do
      message_timestamp { 1.day.ago }
    end
  end
end

