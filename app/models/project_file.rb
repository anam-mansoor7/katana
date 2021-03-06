class ProjectFile < ActiveRecord::Base
  BUILD_COMMANDS_PATH = 'testributor_build_commands.sh'
  JOBS_YML_PATH = "testributor.yml"

  belongs_to :project

  # Let build_commands be empty
  validates :contents, :path, presence: true,
    unless: ->{ path == BUILD_COMMANDS_PATH }
  validates :path, uniqueness: { scope: :project_id }
  validate :valid_testributor_yml_contents,
    if: ->{ testributor_yml? && contents.present? }
  validate :prevent_path_change,
    if: ->{ path_changed? && (path_was == JOBS_YML_PATH || path_was == BUILD_COMMANDS_PATH) }

  # Build_commands and testributor.yml should not be deleted unless
  # Project is destroyed. We set about_to_be_destroyed in Project in a
  # before_destroy callback.
  before_destroy -> { return false unless project.about_to_be_destroyed },
    if: :build_commands?
  before_destroy -> { return false unless project.about_to_be_destroyed },
    if: :testributor_yml?
  # Bash script don't play well with carriage returns so we stip them out
  # http://stackoverflow.com/questions/22140338/carriage-return-r-on-bash-script
  before_validation :remove_carriege_returns_from_file, if: :build_commands?

  def testributor_yml?
    path == JOBS_YML_PATH
  end

  def build_commands?
    path == BUILD_COMMANDS_PATH
  end

  private
  def valid_testributor_yml_contents
    begin
      contents_as_hash = testributor_yml_as_hash

      unless contents_as_hash
        errors.add(:contents, :not_compatible_format)
        return
      end
    rescue Psych::SyntaxError
      errors.add(:contents, :syntax_error)
      return
    end

    if contents_as_hash.has_key?("each")
      each_description = contents_as_hash.delete("each")

      unless each_description
        errors.add(:contents, :each_without_pattern)
        errors.add(:contents, :each_without_command)
        return
      end

      unless each_description["pattern"]
        errors.add(:contents, :each_without_pattern)
        return
      end

      unless each_description["command"]
        errors.add(:contents, :each_without_command)
        return
      end
    end

    contents_as_hash.each do |job_name, description|
      unless description.try(:[],"command")
        errors.add(:contents, "#{job_name} is missing \"command\" key")
        return
      end
    end
  end

  def prevent_path_change
    errors.add(:path, "Cannot change path for this file")
  end

  def remove_carriege_returns_from_file
    contents.gsub!(/\r/,'')
  end

  def testributor_yml_as_hash
    result = SafeYAML.load(contents.to_s)

    result.is_a?(Hash) ? result : false
  end
end
