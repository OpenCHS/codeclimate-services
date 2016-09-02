require "cc/presenters/pull_requests_presenter"

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
      default: <<-COMMENT
* This repository is using Code Climate to automatically check for code quality issues.
* You can see results for this analysis in the PR status below.
* You can install [the Code Climate browser extension](https://codeclimate.com/browser) to see analysis without leaving GitHub.

Thanks for your contribution!
    COMMENT

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

  def author_username
    @payload.fetch("author_username")
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

  INTRODUCTION_TEMPLATE = <<-HEADER.freeze
Hey, @%s-- Since this is the first PR we've seen from you, here's some things you should know about contributing to %s:
  HEADER

  def welcome_comment_introduction
    format INTRODUCTION_TEMPLATE, author_username, github_slug
  end

  def welcome_comment_body
    config.welcome_comment_markdown
  end

  ADMIN_ONLY_FOOTER_TEMPLATE = <<-FOOTER.freeze
* * *
Quick note: By default, Code Climate will post the above comment on the *first* PR it sees from each contributor. If you'd like to customize this message or disable this, go [here](%s).
  FOOTER

  def welcome_comment_footer
    format ADMIN_ONLY_FOOTER_TEMPLATE, @payload.fetch("pull_request_integration_edit_url")
  end

  def author_is_site_admin?
    @payload.fetch("author_is_site_admin")
  end

  def welcome_comment_markdown
    if author_is_site_admin?
      welcome_comment_introduction + welcome_comment_body + welcome_comment_footer
    else
      welcome_comment_introduction + welcome_comment_body
    end
  end
end
