class Project < ActiveRecord::Base
  # We want this for github_webhook_url
  include Rails.application.routes.url_helpers
  # https://github.com/scambra/devise_invitable/issues/84
  include DeviseInvitable::Inviter

  devise :database_authenticatable
  belongs_to :user # this is the owner of the project
  has_many :tracked_branches, dependent: :destroy
  has_many :test_runs, through: :tracked_branches
  has_many :test_jobs, through: :test_runs
  has_and_belongs_to_many :members, class_name: "User"
  has_many :invited_users, class_name: 'User', foreign_key: :invited_by_id
  has_many :project_files, dependent: :destroy
  has_one :oauth_application, class_name: 'Doorkeeper::Application', as: :owner, dependent: :destroy

  validates :name, :user, presence: true
  validates :name, uniqueness: { scope: :user }
  validate :check_user_limit, if: :user_id_changed?

  before_create :set_secure_random
  # TODO: Run cron job to ensure all owners are also participants
  after_create :add_owner_to_participants

  attr_accessor :fork

  def to_param
    "#{id}-#{name}"
  end

  def owner_and_name
    "#{repository_owner}/#{repository_name}"
  end

  def create_webhooks!
    begin
      hook = user.github_client.create_hook(repository_id, 'web',
        {
          secret: ENV['GITHUB_WEBHOOK_SECRET'],
          url: webhook_url, content_type: 'json'
        }, events: %w(push delete))
    rescue Octokit::UnprocessableEntity => e
      if e.message =~ /hook already exists/i
        hooks = user.github_client.hooks(repository_id)
        hook = hooks.select do |h|
          h.config.url == webhook_url && h.events == %w(push delete)
        end.first
      else
        raise e
      end
    end
  end

  def create_oauth_application!
    app = Doorkeeper::Application.new(
      name: repository_id,
      redirect_uri: Katana::Application::HEROKU_URL)
    app.owner_id = id
    app.owner_type = 'Project'
    app.save

    app
  end

  private

  # Don't let a project be assigned to a user if projects limit
  # has been reached
  def check_user_limit
    if user && !user.can_create_new_project?
      errors.add(:base, :project_limit_reached)
    end
  end

  def webhook_url
    ENV['GITHUB_WEBHOOK_URL'] ||
      github_webhook_url(host: "www.testributor.com")
  end

  # TODO: Add tests for this
  def add_owner_to_participants
    self.members << self.user
  end

  def set_secure_random
    self.secure_random = SecureRandom.hex

    #in case a secure random exists
    while Project.find_by_secure_random(self.secure_random)
      self.secure_random = SecureRandom.hex
    end
  end
end