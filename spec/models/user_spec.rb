# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:comments).dependent(:destroy) }
    it { is_expected.to have_many(:notifications).dependent(:destroy) }
    it { is_expected.to have_many(:sent_notifications).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username).case_insensitive }
    it { is_expected.to validate_length_of(:username).is_at_least(2).is_at_most(30) }

    it 'rejects usernames with special characters' do
      user = build(:user, username: 'bad user!')
      expect(user).not_to be_valid
      expect(user.errors[:username]).to be_present
    end

    it 'accepts usernames with letters, numbers and underscores' do
      expect(build(:user, username: 'valid_user_99')).to be_valid
    end
  end
end
