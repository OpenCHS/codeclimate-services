class CC::PullRequests < CC::Service
  VALID_TOKEN_MESSAGE = "Access token is valid.".freeze
  CANT_POST_COMMENTS_MESSAGE = "Access token is invalid - can't post comments".freeze
  CANT_UPDATE_STATUS_MESSAGE = "Access token is invalid - can't update status.".freeze
  INVALID_TOKEN_MESSAGE = "Access token is invalid.".freeze

  MESSAGES = {
    [true, true] => VALID_TOKEN_MESSAGE,
    [true, nil] => VALID_TOKEN_MESSAGE,
    [false, nil] => CANT_UPDATE_STATUS_MESSAGE,
    [true, false] => CANT_POST_COMMENTS_MESSAGE,
    [false, true] => CANT_UPDATE_STATUS_MESSAGE,
    [false, false] => INVALID_TOKEN_MESSAGE,
  }.freeze

  def receive_test
    setup_http

    tests = [able_to_update_status?, able_to_post_comments?]

    {
      ok: tests.compact.all?,
      message: MESSAGES.fetch(tests),
    }
  end

  def receive_pull_request
    setup_http
    state = @payload["state"]

    if %w[pending success failure skipped error].include?(state)
      send("update_status_#{state}")
    else
      @response = simple_failure("Unknown state")
    end

    response
  end

  def receive_pull_request_coverage
    setup_http
    state = @payload["state"]

    if state == "success"
      update_coverage_status_success
    else
      @response = simple_failure("Unknown state")
    end

    response
  end

  private

  def simple_failure(message)
    { ok: false, message: message }
  end

  def response
    @response || simple_failure("Nothing happened")
  end

  def update_status_skipped
    raise NotImplementedError
  end

  def update_status_success
    raise NotImplementedError
  end

  def update_coverage_status_success
    raise NotImplementedError
  end

  def update_status_failure
    raise NotImplementedError
  end

  def update_status_error
    raise NotImplementedError
  end

  def update_status_pending
    raise NotImplementedError
  end

  def test_status_code
    raise NotImplementedError
  end

  def able_to_update_status?
    raw_post(base_status_url("0" * 40), { state: "success" }.to_json)
  rescue CC::Service::HTTPError => e
    if e.status == test_status_code
      true
    elsif (400..499).cover?(e.status)
      false
    else
      raise
    end
  end

  def presenter
    CC::Service::PullRequestsPresenter.new(@payload)
  end

  def update_status(state, description, context = config.context)
    params = {
      context: context,
      description: description,
      state: state,
      target_url: @payload["details_url"],
    }
    @response = service_post(status_url, params.to_json)
  end

  def status_url
    base_status_url(commit_sha)
  end

  def base_status_url(_commit_sha)
    raise NotImplementedError
  end

  def setup_http
    raise NotImplementedError
  end

  def commit_sha
    @payload.fetch("commit_sha")
  end

  def number
    @payload.fetch("number")
  end

  def git_url
    @git_url ||= URI.parse(@payload.fetch("git_url"))
  end

  def welcome_comment_implemented?
    respond_to?(:receive_pull_request_welcome_comment)
  end

  def able_to_post_comments?
    @able_to_post_comments ||=
      if welcome_comment_implemented? && config.welcome_comment_enabled
        able_to_comment?
      end
  end
end
