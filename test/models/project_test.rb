require 'test_helper'

class ProjectTest < ActiveSupport::TestCase
  let(:project) { FactoryGirl.build(:project) }
  let(:owner) { project.user }
  let(:new_owner) { FactoryGirl.create(:user) }

  describe "technologies validations" do
    subject { FactoryGirl.create(:project) }

    let(:postgres_9_3) do
      FactoryGirl.create(:docker_image,
                         standardized_name: "postgres", version: "9.3")
    end

    let(:postgres_9_4) do
      FactoryGirl.create(:docker_image,
                         standardized_name: "postgres", version: "9.4")
    end

    it "validates uniqueness of technology standardized names" do
      ->{ subject.technologies = [postgres_9_3, postgres_9_4] }.
        must_raise(ActiveRecord::RecordInvalid)
    end
  end

  describe "project limit on user validation" do
    it "doesn't get called when user id hasn't changed" do
      owner.update_column(:projects_limit, 2)
      owner.reload
      project.save!
      project.expects(:check_user_limit).never
      project.save!
    end

    it "gets called when user id has changed" do
      owner.update_column(:projects_limit, 2)
      owner.reload
      project.user = new_owner
      project.expects(:check_user_limit).once
      project.save!
    end

    it "gets called when project is created" do
      project = Project.new(name: "Test", user: owner)
      project.expects(:check_user_limit).once
      project.save!
    end

    it "is valid if projects limit is greater than user's projects" do
      owner.update_column(:projects_limit, 2)
      owner.reload

      project.valid?.must_equal true
    end

    it "is valid if projects limit is equal to user's projects" do
      owner.update_column(:projects_limit, 1)
      owner.reload

      project.valid?.must_equal true
    end

    it "is invalid if projects limit is less than user's projects" do
      owner.update_column(:projects_limit, 0)
      owner.reload

      project.valid?.must_equal false
      project.errors.keys.must_include :base
    end
  end

  describe "invited_users association" do
    let(:invited_user) do
      FactoryGirl.create(:user_invitation, project: project).user
    end

    before { invited_user }

    it "returns users with invitations" do
      project.invited_users.must_equal [invited_user]
    end

    describe "after user accepting the invitation" do
      before do
        invited_user.user_invitations.first.accept!(invited_user)
      end

      it "still returns the invited user" do
        project.reload.invited_users.must_equal [invited_user]
      end
    end
  end

  describe "active_workers" do
    let(:doorkeeper_application) do
      FactoryGirl.create(:doorkeeper_application, owner: project)
    end

    let(:non_active_token) do
      FactoryGirl.create(:doorkeeper_access_token,
        application: doorkeeper_application,
        last_used_at: (Project::ACTIVE_WORKER_THRESHOLD_SECONDS + 20).seconds.ago)
    end

    let(:active_token) do
      FactoryGirl.create(:doorkeeper_access_token,
        application: doorkeeper_application,
        last_used_at: (Project::ACTIVE_WORKER_THRESHOLD_SECONDS - 10).seconds.ago)
    end

    before do
      Timecop.freeze
      non_active_token
      active_token
    end

    after do
      Timecop.return
    end

    it "returns only then number of tokens access earlier than ACTIVE_WORKER_THRESHOLD_SECONDS" do
      project.active_workers.must_equal 1
    end

    it "doesn't return never-accessed workers as active" do
      non_active_token.update_column(:last_used_at, nil)
      project.active_workers.must_equal 1
    end
  end
end
