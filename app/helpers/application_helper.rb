module ApplicationHelper
  def title
    if content_for? :title
      content_for(:title)
    else
      "Testributor: Parallel Testing for Ruby on Rails, Python, Javascript and more."
    end
  end

  def meta_description
    if content_for? :meta_description
      content_for(:meta_description)
    else
      "Testributor will help you slice up your test suite efficiently and run all "\
      "its “pieces” in parallel, on your computers or ours."
    end
  end

  def controller_and_action
    "#{controller_path.split("/").join(' ')} #{action_name.gsub('_','-')}"
  end

  def page_data_attrs
    {
      "js-class" => controller_path.camelize.gsub("::", "."),
      "js-method" => action_name.camelize(:lower),
      "admin-user" => current_user.try(:admin?).try(:to_json)
    }
  end

  def github_private_repo_oauth_authorize_url
    Octokit.authorize_url(Octokit.client_id,
      scope: User::GITHUB_PRIVATE_REPO_SCOPES.join(","),
      redirect_uri: github_callback_url)
  end

  def github_public_repo_oauth_authorize_url
    Octokit.authorize_url(Octokit.client_id,
      scope: User::GITHUB_PUBLIC_REPO_SCOPES.join(","),
      redirect_uri: github_callback_url)
  end

  # The Ruby library we use for accessing the BitBucket API does not support
  # any of the OAuth1/OAuth2 authorisation flows. For this reason we do this
  # semi-manually, using the OAuth gem. We are using OAuth v1.
  # NOTE: Avoid calling this method on the view to generate the
  # authorize link when the user might not click on it.
  # This methods make external requests which we can avoided by showing to the
  # user a link to OauthController#authorize_bitbucket action.
  def bitbucket_oauth_authorize_url
    consumer = OAuth::Consumer.new(ENV['BITBUCKET_CLIENT_ID'],
      ENV['BITBUCKET_CLIENT_SECRET'], site: 'https://bitbucket.org',
      request_token_path: '/api/1.0/oauth/request_token',
      authorize_path: '/api/1.0/oauth/authenticate',
      access_token_path: '/api/1.0/oauth/access_token')

    # triggers external POST
    request_token = consumer.get_request_token(oauth_callback: bitbucket_callback_url)
    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret

    request_token.authorize_url
  end

  def wizard_step_class(step)
    class_str = "active" if current_step?(step)
    class_str = "" if future_step?(step)
    class_str = "done" if past_step?(step)

    class_str
  end

  def grouped_languages_options
    DockerImage.languages.group_by(&:standardized_name).
      map do |group, languages|
      [
        group, languages.map do |language|
          [language.public_name, language.id]
        end
      ]
    end
  end

  def conditions_for_active_project(project)
    [
      current_page?(project_path(project)),
      controller_name == 'test_runs'
    ]
  end

  def technologies_options
    DockerImage.technologies.map do |technology|
      [technology.public_name, technology.id]
    end
  end

  def flash_messages
    if flash[:notice]
      html = <<-HTML
        <div class='alert alert-info'>
          #{flash[:notice]}
        </div>
        </br>
      HTML
      flash_message = html.html_safe
    end

    if flash[:alert]
      html = <<-HTML
        <div class='alert alert-danger'>
          #{flash[:alert]}
        </div>
        </br>
      HTML
      flash_message = html.html_safe
    end

    flash_message
  end

  def with_dots(text)
    "#{text}<span class='dot'></span><span class='dot'></span><span class='dot'></span>".html_safe
  end

  def gitter_share_link
    "https://gitter.im/testributor/testributor?utm_source=help-section-link&utm_medium=link&utm_campaign=share-link"
  end

  def documentation_url
    'http://documentation.testributor.com'
  end
end
