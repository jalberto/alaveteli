# == Schema Information
#
# Table name: outgoing_messages
#
#  id                           :integer          not null, primary key
#  info_request_id              :integer          not null
#  body                         :text             not null
#  status                       :string(255)      not null
#  message_type                 :string(255)      not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  last_sent_at                 :datetime
#  incoming_message_followup_id :integer
#  what_doing                   :string(255)      not null
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe OutgoingMessage, " when making an outgoing message" do

    before do
        @om = outgoing_messages(:useless_outgoing_message)
        @outgoing_message = OutgoingMessage.new({
            :status => 'ready',
            :message_type => 'initial_request',
            :body => 'This request contains a foo@bar.com email address',
            :last_sent_at => Time.now(),
            :what_doing => 'normal_sort'
        })
    end

    it "should not index the email addresses" do
        # also used for track emails
        @outgoing_message.get_text_for_indexing.should_not include("foo@bar.com")
    end

    it "should not display email addresses on page" do
        @outgoing_message.get_body_for_html_display.should_not include("foo@bar.com")
    end

    it "should link to help page where email address was" do
        @outgoing_message.get_body_for_html_display.should include('<a href="/help/officers#mobiles">')
    end

    it "should include email addresses in outgoing messages" do
        @outgoing_message.body.should include("foo@bar.com")
    end

    it "should work out a salutation" do
        @om.get_salutation.should == "Dear Geraldine Quango,"
    end

    it 'should produce the expected text for an internal review request' do
        public_body = mock_model(PublicBody, :name => 'A test public body')
        info_request = mock_model(InfoRequest, :public_body => public_body,
                                               :url_title => 'a_test_title',
                                               :title => 'A test title',
                                               :apply_censor_rules_to_text! => nil)
        outgoing_message = OutgoingMessage.new({
            :status => 'ready',
            :message_type => 'followup',
            :what_doing => 'internal_review',
            :info_request => info_request
        })
        expected_text = "I am writing to request an internal review of A test public body's handling of my FOI request 'A test title'."
        outgoing_message.body.should include(expected_text)
    end

    describe 'when asked if a user can view it' do

        before do
            @info_request = FactoryGirl.create(:info_request)
            @outgoing_message = @info_request.outgoing_messages.first
        end

        context 'if the prominence is hidden' do

            before do
                @outgoing_message.prominence = 'hidden'
            end

            it 'should return true for an admin user' do
                @outgoing_message.user_can_view?(FactoryGirl.create(:admin_user)).should be_true
            end

            it 'should return false for a non-admin user' do
                @outgoing_message.user_can_view?(FactoryGirl.create(:user)).should be_false
            end

        end

        context 'if the prominence is requester_only' do

            before do
                @outgoing_message.prominence = 'requester_only'
            end

            it 'should return true if the user owns the associated request' do
                @outgoing_message.user_can_view?(@info_request.user).should be_true
            end

            it 'should return false if the user does not own the associated request' do
                @outgoing_message.user_can_view?(FactoryGirl.create(:user)).should be_false
            end
        end

        context 'if the prominence is normal' do

            before do
                @outgoing_message.prominence = 'normal'
            end

            it 'should return true for a non-admin user' do
                @outgoing_message.user_can_view?(FactoryGirl.create(:user)).should be_true
            end

        end

    end

    describe 'when asked if it is indexed by search' do

        before do
            @info_request = FactoryGirl.create(:info_request)
            @outgoing_message = @info_request.outgoing_messages.first
        end

        it 'should return false if it has prominence "hidden"' do
            @outgoing_message.prominence = 'hidden'
            @outgoing_message.indexed_by_search?.should be_false
        end

        it 'should return false if it has prominence "requester_only"' do
            @outgoing_message.prominence = 'requester_only'
            @outgoing_message.indexed_by_search?.should be_false
        end

        it 'should return true if it has prominence "normal"' do
            @outgoing_message.prominence = 'normal'
            @outgoing_message.indexed_by_search?.should be_true
        end

    end
end


describe OutgoingMessage, " when censoring data" do

    before do
        @om = outgoing_messages(:useless_outgoing_message)

        @censor_rule = CensorRule.new()
        @censor_rule.text = "dog"
        @censor_rule.replacement = "cat"
        @censor_rule.last_edit_editor = "unknown"
        @censor_rule.last_edit_comment = "none"

        @om.info_request.censor_rules << @censor_rule
    end

    it "should apply censor rules to outgoing messages" do
        @om.read_attribute(:body).should match(/fancy dog/)
        @om.body.should match(/fancy cat/)
    end
end

describe OutgoingMessage, "when validating the format of the message body", :focus => true do

    it 'should handle a salutation with a bracket in it' do
        outgoing_message = FactoryGirl.build(:initial_request)
        outgoing_message.stub!(:get_salutation).and_return("Dear Bob (Robert,")
        lambda{ outgoing_message.valid? }.should_not raise_error(RegexpError)
    end

end
