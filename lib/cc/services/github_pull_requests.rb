require "cc/presenters/pull_requests_presenter"
require "cc/presenters/github_pull_requests_welcome_comment_presenter"

class CC::Service::GitHubPullRequests < CC::PullRequests
  class Config < CC::Service::Config
    attribute :oauth_token, Axiom::Types::String,
      label: "OAuth Token",
      description: "A personal OAuth token with permissions for the repo."
    attribute :base_url, Axiom::Types::String,
      label: "Github API Base URL",
      description: "Base URL for the Github API",
      default: "https://api.github.com"
    attribute :context, Axiom::Types::String,
      label: "Github Context",
      description: "The integration name next to the pull request status",
      default: "codeclimate"
    attribute :welcome_comment_enabled, Axiom::Types::Boolean,
      label: "Welcome comment enabled?",
      description: "Should Code Climate post a welcome comment on pull requests?",
      default: false
    attribute :welcome_comment_markdown, Axiom::Types::String,
      label: "Welcome comment markdown",
      description: "The body of the welcome comment for first-time contributors to this repo.",
      default: CC::Service::GithubPullRequestsWelcomeCommentPresenter::DEFAULT_BODY

    validates :oauth_token, presence: true
  end

  self.title = "GitHub Pull Requests"
  self.description = "Update pull requests on GitHub"

  def receive_pull_request_welcome_comment
    return unless config.welcome_comment_enabled

    setup_http

    @response = service_post(comments_url, { body: welcome_comment_markdown }.to_json)
  end

  private

  def update_status_skipped
    update_status("success", presenter.skipped_message)
  end

  def update_status_success
    update_status("success", presenter.success_message)
  end

  def update_coverage_status_success
    update_status("success", presenter.coverage_message, "#{config.context}/coverage")
  end

  def update_status_failure
    update_status("failure", presenter.success_message)
  end

  def update_status_error
    update_status(
      "error",
      @payload["message"] || presenter.error_message,
    )
  end

  def update_status_pending
    update_status(
      "pending",
      @payload["message"] || presenter.pending_message,
    )
  end

  def setup_http
    http.headers["Content-Type"] = "application/json"
    http.headers["Authorization"] = "token #{config.oauth_token}"
    http.headers["User-Agent"] = "Code Climate"
  end

  def base_status_url(commit_sha)
    "#{config.base_url}/repos/#{github_slug}/statuses/#{commit_sha}"
  end

  def github_slug
    @payload.fetch("github_slug")
  end

  def response_includes_repo_scope?(response)
    response.headers["x-oauth-scopes"] && response.headers["x-oauth-scopes"].split(/\s*,\s*/).include?("repo")
  end

  def test_status_code
    422
  end

  def welcome_comment_implemented?
    true
  end

  def user_url
    "#{config.base_url}/user"
  end

  def comments_url
    "#{config.base_url}/repos/#{github_slug}/issues/#{number}/comments"
  end

  def able_to_comment?
    response_includes_repo_scope?(service_get(user_url))
  end

  def welcome_comment_markdown
    GithubPullRequestsWelcomeCommentPresenter.new(@payload, config).welcome_message
  end
end
