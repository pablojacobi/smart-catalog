# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_inclusion_of(:role).in_array(described_class::ROLES) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:conversation) }
  end

  describe 'scopes' do
    let(:conversation) { create(:conversation) }

    describe '.by_role' do
      it 'filters by role' do
        user_msg = create(:message, :user, conversation: conversation)
        assistant_msg = create(:message, :assistant, conversation: conversation)

        expect(described_class.by_role('user')).to include(user_msg)
        expect(described_class.by_role('user')).not_to include(assistant_msg)
      end
    end

    describe '.ordered' do
      it 'orders by created_at ascending' do
        old_msg = create(:message, conversation: conversation, created_at: 1.hour.ago)
        new_msg = create(:message, conversation: conversation, created_at: Time.current)

        expect(described_class.ordered).to eq([old_msg, new_msg])
      end
    end

    describe '.recent' do
      it 'returns most recent messages' do
        messages = Array.new(15) { |i| create(:message, conversation: conversation, created_at: i.minutes.ago) }

        expect(described_class.recent(5).count).to eq(5)
        expect(described_class.recent(5).first).to eq(messages.first)
      end
    end
  end

  describe 'role predicates' do
    it '#user? returns true for user role' do
      expect(build(:message, :user).user?).to be true
      expect(build(:message, :assistant).user?).to be false
    end

    it '#assistant? returns true for assistant role' do
      expect(build(:message, :assistant).assistant?).to be true
      expect(build(:message, :user).assistant?).to be false
    end

    it '#system? returns true for system role' do
      expect(build(:message, :system).system?).to be true
      expect(build(:message, :user).system?).to be false
    end
  end
end
