require File.expand_path("../helper", __FILE__)

class TestGitHubPullRequests < CC::Service::TestCase
  def test_pull_request_status_pending
    expect_status_update("pbrisbin/foo", "abc123", "state" => "pending",
      "description" => /is analyzing/)

    receive_pull_request({}, github_slug: "pbrisbin/foo",
      commit_sha:  "abc123",
      state:       "pending")
  end

  def test_pull_request_status_success_detailed
    expect_status_update("pbrisbin/foo", "abc123", "state" => "success",
      "description" => "Code Climate found 2 new issues and 1 fixed issue.")

    receive_pull_request(
      {},
      github_slug: "pbrisbin/foo",
      commit_sha:  "abc123",
      state:       "success",
    )
  end

  def test_pull_request_status_failure
    expect_status_update("pbrisbin/foo", "abc123", "state" => "failure",
      "description" => "Code Climate found 2 new issues and 1 fixed issue.")

    receive_pull_request(
      {},
      github_slug: "pbrisbin/foo",
      commit_sha:  "abc123",
      state:       "failure",
    )
  end

  def test_pull_request_status_success_generic
    expect_status_update("pbrisbin/foo", "abc123", "state" => "success",
      "description" => /found 2 new issues and 1 fixed issue/)

    receive_pull_request({}, github_slug: "pbrisbin/foo",
                             commit_sha:  "abc123",
                             state:       "success")
  end

  def test_pull_request_status_error
    expect_status_update("pbrisbin/foo", "abc123", "state" => "error",
      "description" => "Code Climate encountered an error attempting to analyze this pull request.")

    receive_pull_request({}, github_slug: "pbrisbin/foo",
                             commit_sha:  "abc123",
                             state:       "error",
                             message:     nil)
  end

  def test_pull_request_status_error_message_provided
    expect_status_update("pbrisbin/foo", "abc123", "state" => "error",
      "description" => "descriptive message")

    receive_pull_request({}, github_slug: "pbrisbin/foo",
      commit_sha:  "abc123",
      state:       "error",
      message:     "descriptive message")
  end

  def test_pull_request_status_skipped
    expect_status_update("pbrisbin/foo", "abc123", "state" => "success",
      "description" => /skipped analysis/)

    receive_pull_request({}, github_slug: "pbrisbin/foo",
      commit_sha:  "abc123",
      state:       "skipped")
  end

  def test_pull_request_coverage_status
    expect_status_update("pbrisbin/foo", "abc123", "state" => "success",
      "description" => "87% test coverage (+2%)")

    receive_pull_request_coverage({},
      github_slug:     "pbrisbin/foo",
      commit_sha:      "abc123",
      state:           "success",
      covered_percent: 87,
      covered_percent_delta: 2.0)
  end

  def test_pull_request_status_test_success
    @stubs.post("/repos/pbrisbin/foo/statuses/#{"0" * 40}") { |_env| [422, {}, ""] }

    assert receive_test({}, github_slug: "pbrisbin/foo")[:ok], "Expected test of pull request to be true"
  end

  def test_pull_request_status_test_success_and_comment_success
    @stubs.post("/repos/pbrisbin/foo/statuses/#{"0" * 40}") { |_env| [422, {}, ""] }
    @stubs.get("/user") { |env| [200, {'x-oauth-scopes' => "foo,repo,bar" }, ""] }

    response = receive_test({ welcome_comment_enabled: true }, github_slug: "pbrisbin/foo")
    assert response[:ok], "Expected test of pull request to be true"
    assert_equal response[:message], CC::PullRequests::VALID_TOKEN_MESSAGE
  end

  def test_pull_request_status_success_but_not_correct_permissions_to_comment
    @stubs.post("/repos/pbrisbin/foo/statuses/#{"0" * 40}") { |_env| [422, {}, ""] }
    @stubs.get("/user") { |env| [200, {'x-oauth-scopes' => "foo,zepo,bar" }, ""] }

    response = receive_test({ welcome_comment_enabled: true }, github_slug: "pbrisbin/foo")
    assert_equal false, response[:ok]
    assert_equal response[:message], CC::Service::GitHubPullRequests::CANT_POST_COMMENTS_MESSAGE
  end

  def test_pull_request_status_test_doesnt_blow_up_when_unused_keys_present_in_config
    @stubs.post("/repos/pbrisbin/foo/statuses/#{"0" * 40}") { |_env| [422, {}, ""] }

    assert receive_test({ wild_flamingo: true }, github_slug: "pbrisbin/foo")[:ok], "Expected test of pull request to be true"
  end

  def test_pull_request_status_test_failure
    @stubs.post("/repos/pbrisbin/foo/statuses/#{"0" * 40}") { |_env| [401, {}, ""] }

    response = receive_test({}, github_slug: "pbrisbin/foo")
    assert_equal response[:ok], false
    assert_equal response[:message], CC::PullRequests::CANT_UPDATE_STATUS_MESSAGE
  end

  def test_pull_request_status_test_failure_and_not_correct_permissions_to_comment
    @stubs.post("/repos/pbrisbin/foo/statuses/#{"0" * 40}") { |_env| [401, {}, ""] }
    @stubs.get("/user") { |env| [200, {'x-oauth-scopes' => "foo,zepo,bar" }, ""] }

    response = receive_test({ welcome_comment_enabled: true }, github_slug: "pbrisbin/foo")
    assert_equal response[:ok], false

    assert_equal response[:message], CC::Service::GitHubPullRequests::INVALID_TOKEN_MESSAGE
  end

  def test_updating_status_for_pull_request_unknown_state
    response = receive_pull_request({}, state: "unknown")

    assert_equal({ ok: false, message: "Unknown state" }, response)
  end

  def test_updating_status_for_different_base_url
    @stubs.post("/repos/pbrisbin/foo/statuses/#{"0" * 40}") do |env|
      assert env[:url].to_s == "http://example.com/repos/pbrisbin/foo/statuses/#{"0" * 40}"
      [422, { "x-oauth-scopes" => "gist, user, repo" }, ""]
    end

    assert receive_test({ base_url: "http://example.com" }, github_slug: "pbrisbin/foo")[:ok], "Expected test of pull request to be true"
  end

  def test_updating_status_for_default_context
    expect_status_update("gordondiggs/ellis", "abc123", "context" => "codeclimate",
                                                        "state" => "pending")

    receive_pull_request({}, github_slug: "gordondiggs/ellis",
      commit_sha:  "abc123",
      state:       "pending")
  end

  def test_updating_status_for_different_context
    expect_status_update("gordondiggs/ellis", "abc123", "context" => "sup",
      "state" => "pending")

    receive_pull_request({ context: "sup" }, github_slug: "gordondiggs/ellis",
      commit_sha:  "abc123",
      state:       "pending")
  end

  def test_posting_welcome_comment_to_non_admin
    expect_welcome_comment(
      "gordondiggs/ellis",
      "45",
      does_not_contain: [/customize this message or disable/],
    )

    receive_welcome_comment(
      { welcome_comment_enabled: true },
      {
        author_can_administrate_repo: false,
      }
    )
  end

  def test_posting_welcome_comment_to_admin
    expect_welcome_comment(
      "gordondiggs/ellis",
      "45",
      contains: [/is using Code Climate/, /customize this message or disable/, /example.com/]
    )

    receive_welcome_comment(
      { welcome_comment_enabled: true },
      {
        author_can_administrate_repo: true,
      }
    )
  end

  def test_posting_welcome_comment_with_custom_body
    expect_welcome_comment(
      "gordondiggs/ellis",
      "45",
      contains: [/Can't wait to review this/],
      does_not_contain: [/is using Code Climate/],
    )

    receive_welcome_comment(
      {
        welcome_comment_enabled: true,
        welcome_comment_markdown: "Can't wait to review this!",
      },
      {
        author_can_administrate_repo: true,
      }
    )
  end

  def test_no_comment_when_not_opted_in
    receive_welcome_comment(
      { welcome_comment_enabled: false },
      {
        author_can_administrate_repo: true,
      }
    )
  end

  private

  def expect_welcome_comment(repo, number, contains: [], does_not_contain: [])
    @stubs.post "repos/#{repo}/issues/#{number}/comments" do |env|
      assert_equal "token 123", env[:request_headers]["Authorization"]

      body = JSON.parse(env[:body])
      assert_equal body.keys, %w[body]

      comment_body = body["body"]
      contains.each do |pattern|
        assert_match pattern, comment_body
      end

      does_not_contain.each do |pattern|
        assert_not_match pattern, comment_body
      end

      [201, {}, {}]
    end
  end

  def expect_status_update(repo, commit_sha, params)
    @stubs.post "repos/#{repo}/statuses/#{commit_sha}" do |env|
      assert_equal "token 123", env[:request_headers]["Authorization"]

      body = JSON.parse(env[:body])

      params.each do |k, v|
        assert v === body[k],
          "Unexpected value for #{k}. #{v.inspect} !== #{body[k].inspect}"
      end

      [201, {}, {}]
    end
  end

  def receive_pull_request(config, event_data)
    receive(
      CC::Service::GitHubPullRequests,
      { oauth_token: "123" }.merge(config),
      { name: "pull_request", issue_comparison_counts: { "fixed" => 1, "new" => 2 } }.merge(event_data),
    )
  end

  def receive_pull_request_coverage(config, event_data)
    receive(
      CC::Service::GitHubPullRequests,
      { oauth_token: "123" }.merge(config),
      { name: "pull_request_coverage", issue_comparison_counts: { "fixed" => 1, "new" => 2 } }.merge(event_data),
    )
  end

  def receive_welcome_comment(config, event_data)
    receive(
      CC::Service::GitHubPullRequests,
      { oauth_token: "123" }.merge(config),
      {
        name: "pull_request_welcome_comment",
        github_slug: "gordondiggs/ellis",
        number: "45",
        author_username: "mrb",
        pull_request_integration_edit_url: "http://example.com/edit",
      }.merge(event_data),
    )
  end

  def receive_test(config, event_data = {})
    receive(
      CC::Service::GitHubPullRequests,
      { oauth_token: "123" }.merge(config),
      { name: "test", issue_comparison_counts: { "fixed" => 1, "new" => 2 } }.merge(event_data),
    )
  end
end
